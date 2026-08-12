import 'dart:async';

import 'package:collection/collection.dart';
import 'package:localsend_app/model/cross_file.dart';
import 'package:localsend_app/model/persistence/paired_device.dart';
import 'package:localsend_app/model/state/doorstep_transfer_state.dart';
import 'package:localsend_app/model/state/send/send_session_state.dart';
import 'package:localsend_app/provider/doorstep_pairing_provider.dart';
import 'package:localsend_app/provider/network/send_provider.dart';
import 'package:localsend_app/provider/progress_provider.dart';
import 'package:localsend_isolates/model/file_status.dart';
import 'package:localsend_isolates/model/session_status.dart';
import 'package:localsend_isolates/util/rust.dart';
import 'package:logging/logging.dart';
import 'package:refena_flutter/refena_flutter.dart';

final _logger = Logger('DoorstepTransfer');

/// How often the in-flight transfer progress is polled for the activity view.
const _progressPollInterval = Duration(milliseconds: 300);

/// How long to wait after one transfer finishes before starting the next one
/// in the queue. The receiver's server only allows a single session at a time
/// and needs a moment to fully tear the previous one down — without this gap,
/// back-to-back sends can hit a transient 409 (busy).
const _interTransferGap = Duration(milliseconds: 800);

final doorstepTransferProvider = NotifierProvider<DoorstepTransferNotifier, List<DoorstepTransferState>>((ref) {
  return DoorstepTransferNotifier();
});

/// One queued background transfer, waiting for its turn.
class _QueuedTransfer {
  final CrossFile crossFile;
  final PairedDevice paired;
  final String sourceLabel;
  final String transferId;
  final Completer<String?> completer;

  const _QueuedTransfer({
    required this.crossFile,
    required this.paired,
    required this.sourceLabel,
    required this.transferId,
    required this.completer,
  });
}

class DoorstepTransferNotifier extends Notifier<List<DoorstepTransferState>> {
  /// Live polling of in-flight transfers: transfer id -> poller.
  final Map<String, Timer> _transferPolls = {};

  /// FIFO queue of transfers awaiting their turn. The receiver (Rust core)
  /// accepts only **one upload session at a time**, so starting every dropped
  /// file in parallel would reject all but the first with 409 busy — instead
  /// we serialize them.
  final List<_QueuedTransfer> _queue = [];
  bool _processing = false;

  @override
  List<DoorstepTransferState> init() {
    return [];
  }

  void addTransfer(DoorstepTransferState transfer) {
    // Keep the activity log bounded — it is in-memory only.
    state = [transfer, ...state].take(30).toList();
  }

  void updateStatus(String id, DoorstepTransferStatus status, {double? progress, String? errorMessage}) {
    state = state.map((t) {
      if (t.id == id) {
        return t.copyWith(
          status: status,
          progress: progress ?? t.progress,
          errorMessage: errorMessage ?? t.errorMessage,
        );
      }
      return t;
    }).toList();
  }

  void clearCompleted() {
    state = state.where((t) => t.status != DoorstepTransferStatus.completed).toList();
  }

  /// Enqueues a background send session to [paired] and mirrors its status
  /// into the activity log until it finishes.
  ///
  /// Transfers run strictly one at a time (FIFO), because the receiver's
  /// server only supports a single session — this is what makes dropping
  /// several files into a watched folder at once work.
  ///
  /// [sourceLabel] names the origin in the activity view, e.g.
  /// `Doorstep [Doorstep Drop Zone]` for folder auto-transfer or
  /// `Doorstep [browse]` for a pull from the phone-side live browser.
  ///
  /// Returns the send session id, or `null` when the transfer could not be
  /// started (unreachable target, declined, busy, aborted before start).
  Future<String?> startTrackedTransfer({
    required CrossFile crossFile,
    required PairedDevice paired,
    required String sourceLabel,
  }) {
    final target = ref.notifier(doorstepPairingProvider).resolveTarget(paired);
    final ip = target.ip;
    if (ip == null || ip.isEmpty || ip == '0.0.0.0' || ip == '-') {
      _logger.warning('Cannot transfer ${crossFile.name} to ${paired.alias}: no reachable IP');
      return Future.value(null);
    }

    final transferId = DateTime.now().microsecondsSinceEpoch.toString();
    addTransfer(
      DoorstepTransferState(
        id: transferId,
        fileName: crossFile.name,
        fileSize: crossFile.size,
        sourceDevice: sourceLabel,
        targetDevice: paired.alias,
        status: DoorstepTransferStatus.pending,
        timestamp: DateTime.now(),
      ),
    );

    final completer = Completer<String?>();
    _queue.add(
      _QueuedTransfer(
        crossFile: crossFile,
        paired: paired,
        sourceLabel: sourceLabel,
        transferId: transferId,
        completer: completer,
      ),
    );
    unawaited(_processQueue());
    return completer.future;
  }

  /// Drains the queue one transfer at a time. Re-entrant safe: if a new
  /// transfer is enqueued while this is running, the while-loop picks it up.
  Future<void> _processQueue() async {
    if (_processing) return;
    _processing = true;
    try {
      while (_queue.isNotEmpty) {
        final job = _queue.removeAt(0);
        try {
          final sessionId = await _startTrackedTransferNow(
            crossFile: job.crossFile,
            paired: job.paired,
            sourceLabel: job.sourceLabel,
            transferId: job.transferId,
          );
          if (!job.completer.isCompleted) {
            job.completer.complete(sessionId);
          }
        } catch (e, st) {
          _logger.warning('Transfer of ${job.crossFile.name} failed', e, st);
          _transferPolls.remove(job.transferId)?.cancel();
          updateStatus(job.transferId, DoorstepTransferStatus.failed, errorMessage: e.humanErrorMessage);
          if (!job.completer.isCompleted) {
            job.completer.complete(null);
          }
        }
        // Let the receiver tear down the finished session before the next
        // register request arrives.
        if (_queue.isNotEmpty) {
          await Future.delayed(_interTransferGap);
        }
      }
    } finally {
      _processing = false;
    }
  }

  /// The actual work of one transfer: starts the background session, mirrors
  /// its status into the activity view, and returns the send session id.
  Future<String?> _startTrackedTransferNow({
    required CrossFile crossFile,
    required PairedDevice paired,
    required String sourceLabel,
    required String transferId,
  }) async {
    final target = ref.notifier(doorstepPairingProvider).resolveTarget(paired);
    final ip = target.ip;
    if (ip == null || ip.isEmpty || ip == '0.0.0.0' || ip == '-') {
      _logger.warning('Cannot transfer ${crossFile.name} to ${paired.alias}: no reachable IP');
      _transferPolls.remove(transferId)?.cancel();
      updateStatus(transferId, DoorstepTransferStatus.failed, errorMessage: '${paired.alias} is not reachable right now');
      return null;
    }

    // Follow the session live (it is created inside [startSession]) until it is
    // closed — background sessions close themselves on success — and mirror its
    // status into the activity view as it goes. The session is located by the
    // target fingerprint, because [startSession] only returns its id at the
    // very end of the transfer.
    String? liveSessionId;
    final poller = Timer.periodic(_progressPollInterval, (_) {
      final sessions = ref.read(sendProvider);
      final session = liveSessionId != null
          ? sessions[liveSessionId]
          : sessions.values.firstWhereOrNull(
              (s) =>
                  s.target.fingerprint == target.fingerprint &&
                  (s.status == SessionStatus.waiting || s.status == SessionStatus.sending) &&
                  _sessionMatchesFile(s, crossFile),
            );
      if (session == null) {
        if (liveSessionId != null) {
          // The tracked session disappeared — the background session closes
          // itself on success, so this means the transfer finished.
          _transferPolls.remove(transferId)?.cancel();
          updateStatus(transferId, DoorstepTransferStatus.completed, progress: 1);
          _logger.info('Transfer of ${crossFile.name} completed');
        }
        return;
      }
      liveSessionId = session.sessionId;

      switch (session.status) {
        case SessionStatus.sending:
          updateStatus(transferId, DoorstepTransferStatus.transferring, progress: _sessionProgress(session.sessionId));
        case SessionStatus.finishedWithErrors:
        case SessionStatus.finished:
        case SessionStatus.canceledBySender:
        case SessionStatus.canceledByReceiver:
        case SessionStatus.declined:
        case SessionStatus.recipientBusy:
        case SessionStatus.tooManyAttempts:
          _transferPolls.remove(transferId)?.cancel();
          final hasError = session.files.values.any((f) => f.status == FileStatus.failed);
          updateStatus(
            transferId,
            hasError ? DoorstepTransferStatus.failed : DoorstepTransferStatus.completed,
            progress: hasError ? null : 1,
            errorMessage: hasError ? session.errorMessage : null,
          );
        case SessionStatus.waiting:
          break;
      }
    });
    _transferPolls[transferId] = poller;

    String? sessionId;
    try {
      sessionId = await ref.notifier(sendProvider).startSession(target: target, files: [crossFile], background: true);
    } catch (e) {
      _logger.warning('Transfer of ${crossFile.name} failed to start', e);
      _transferPolls.remove(transferId)?.cancel();
      updateStatus(transferId, DoorstepTransferStatus.failed, errorMessage: e.humanErrorMessage);
      return null;
    }

    if (sessionId == null) {
      // Declined, busy, or aborted before the session materialized.
      _transferPolls.remove(transferId)?.cancel();
      updateStatus(transferId, DoorstepTransferStatus.failed, errorMessage: 'Transfer was not accepted by ${target.alias}');
    } else if (liveSessionId == null) {
      // The transfer was faster than the poller — inspect the leftover session
      // to tell success (session already closed) from a failure (kept open).
      final remaining = ref.read(sendProvider)[sessionId];
      _transferPolls.remove(transferId)?.cancel();
      if (remaining == null) {
        updateStatus(transferId, DoorstepTransferStatus.completed, progress: 1);
      } else {
        final hasError = remaining.files.values.any((f) => f.status == FileStatus.failed);
        updateStatus(
          transferId,
          hasError ? DoorstepTransferStatus.failed : DoorstepTransferStatus.completed,
          progress: hasError ? null : 1,
          errorMessage: hasError ? remaining.errorMessage : null,
        );
      }
    }

    return sessionId;
  }

  /// The fingerprint alone is not unique — several transfers can run to the
  /// same phone at once (auto-transfer + browse pull). Disambiguate by the
  /// file being sent so each poller tracks *its own* session.
  bool _sessionMatchesFile(SendSessionState session, CrossFile crossFile) {
    if (session.files.length != 1) return false;
    final file = session.files.values.first.file;
    return file.fileName == crossFile.name && file.size == crossFile.size;
  }

  double _sessionProgress(String sessionId) {
    final session = ref.read(sendProvider)[sessionId];
    if (session == null || session.files.isEmpty) return 0;
    final progress = ref.read(progressProvider);
    int totalBytes = 0;
    int currentBytes = 0;
    for (final file in session.files.values) {
      if (file.token == null) continue; // not accepted by the receiver
      totalBytes += file.file.size;
      currentBytes += (progress.getProgress(sessionId: sessionId, fileId: file.file.id) * file.file.size).round();
    }
    return totalBytes == 0 ? 0 : (currentBytes / totalBytes).clamp(0.0, 1.0);
  }
}
