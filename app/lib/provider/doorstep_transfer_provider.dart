import 'dart:async';

import 'package:collection/collection.dart';
import 'package:doorstep_app/model/cross_file.dart';
import 'package:doorstep_app/model/persistence/paired_device.dart';
import 'package:doorstep_app/model/state/doorstep_transfer_state.dart';
import 'package:doorstep_app/model/state/send/send_session_state.dart';
import 'package:doorstep_app/provider/doorstep_pairing_provider.dart';
import 'package:doorstep_app/provider/network/send_provider.dart';
import 'package:doorstep_app/provider/progress_provider.dart';
import 'package:localsend_isolates/model/file_status.dart';
import 'package:localsend_isolates/model/session_status.dart';
import 'package:localsend_isolates/util/rust.dart';
import 'package:logging/logging.dart';
import 'package:refena_flutter/refena_flutter.dart';

final _logger = Logger('DoorstepTransfer');

/// How often the in-flight transfer progress is polled for the activity view.
const _progressPollInterval = Duration(milliseconds: 300);

/// How long incoming files are held back before being flushed into a send
/// batch. Files that arrive together (a folder drop, a quick-send) are sent in
/// ONE session, so the receiver's per-session overhead — checksumming, TLS
/// handshake, session teardown — is paid once instead of per file.
const _batchWindow = Duration(milliseconds: 250);

/// How long to wait after one batch finishes before starting the next one in
/// the queue. The receiver's server only allows a single session at a time and
/// needs a moment to fully tear the previous one down — without this gap,
/// back-to-back sends can hit a transient 409 (busy).
const _interTransferGap = Duration(milliseconds: 800);

final doorstepTransferProvider = NotifierProvider<DoorstepTransferNotifier, List<DoorstepTransferState>>((ref) {
  return DoorstepTransferNotifier();
});

/// One file waiting to be flushed into a batch, with its activity row and
/// the completer the caller awaits.
class _PendingFile {
  final CrossFile crossFile;
  final String transferId;
  final Completer<String?> completer;

  const _PendingFile({required this.crossFile, required this.transferId, required this.completer});
}

/// Files to one device that were collected within the batch window.
class _PendingGroup {
  final String sourceLabel;
  final List<_PendingFile> files;

  _PendingGroup({required this.sourceLabel}) : files = [];
}

/// A flushed [_PendingGroup], queued for its turn.
class _QueuedBatch {
  final PairedDevice paired;
  final String sourceLabel;
  final List<_PendingFile> files;

  const _QueuedBatch({required this.paired, required this.sourceLabel, required this.files});
}

class DoorstepTransferNotifier extends Notifier<List<DoorstepTransferState>> {
  /// Live polling of in-flight transfers: transfer id -> poller.
  final Map<String, Timer> _transferPolls = {};

  /// FIFO queue of send batches awaiting their turn. The receiver (Rust core)
  /// accepts only **one upload session at a time**, so we serialize batches;
  /// within a batch, all files share one session.
  final List<_QueuedBatch> _queue = [];
  bool _processing = false;

  /// Files collected since the last flush, per target device fingerprint.
  final Map<String, _PendingGroup> _pending = {};
  Timer? _batchTimer;

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

  /// Enqueues a background send of [crossFile] to [paired] and mirrors its
  /// status into the activity log until it finishes.
  ///
  /// Files sent close together are batched into one multi-file session (the
  /// receiver supports many files per session), so dropping a whole folder
  /// does not pay per-file session overhead. Batches themselves run strictly
  /// one at a time (FIFO), because the receiver's server only supports a
  /// single session.
  ///
  /// [sourceLabel] names the origin in the activity view, e.g.
  /// `Doorstep [Doorstep Drop Zone]` for folder auto-transfer or
  /// `Doorstep [quick send]` for a right-click send.
  ///
  /// Returns the send session id, or `null` when the transfer could not be
  /// started (unreachable target, declined, busy, aborted before start).
  Future<String?> startTrackedTransfer({
    required CrossFile crossFile,
    required PairedDevice paired,
    required String sourceLabel,
  }) {
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
    _pending
        .putIfAbsent(paired.fingerprint, () => _PendingGroup(sourceLabel: sourceLabel))
        .files
        .add(
          _PendingFile(crossFile: crossFile, transferId: transferId, completer: completer),
        );

    // Flush shortly after the last file arrives, so a burst of files lands in
    // one batch. Re-scheduled on every call.
    _batchTimer?.cancel();
    _batchTimer = Timer(_batchWindow, _flushPendingBatches);

    return completer.future;
  }

  /// Turns every pending file group into a queued batch and starts draining.
  void _flushPendingBatches() {
    _batchTimer = null;
    if (_pending.isEmpty) return;

    for (final entry in _pending.entries) {
      final group = entry.value;
      if (group.files.isEmpty) continue;
      final paired = ref.read(doorstepPairingProvider).where((d) => d.fingerprint == entry.key).firstOrNull;
      if (paired == null) {
        for (final file in group.files) {
          _transferPolls.remove(file.transferId)?.cancel();
          updateStatus(file.transferId, DoorstepTransferStatus.failed, errorMessage: 'Paired device is no longer in the list');
          if (!file.completer.isCompleted) file.completer.complete(null);
        }
        continue;
      }
      _queue.add(_QueuedBatch(paired: paired, sourceLabel: group.sourceLabel, files: group.files));
    }
    _pending.clear();
    unawaited(_processQueue());
  }

  /// Drains the queue one batch at a time. Re-entrant safe: if a new batch is
  /// enqueued while this is running, the while-loop picks it up.
  Future<void> _processQueue() async {
    if (_processing) return;
    _processing = true;
    try {
      while (_queue.isNotEmpty) {
        final batch = _queue.removeAt(0);
        try {
          final sessionId = await _startBatchNow(batch);
          for (final file in batch.files) {
            if (!file.completer.isCompleted) {
              file.completer.complete(sessionId);
            }
          }
        } catch (e, st) {
          _logger.warning('Batch transfer to ${batch.paired.alias} failed', e, st);
          for (final file in batch.files) {
            _transferPolls.remove(file.transferId)?.cancel();
            updateStatus(file.transferId, DoorstepTransferStatus.failed, errorMessage: e.humanErrorMessage);
            if (!file.completer.isCompleted) {
              file.completer.complete(null);
            }
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

  /// Sends all files of [batch] as ONE session and mirrors the session's
  /// status into each file's activity row. Returns the send session id.
  Future<String?> _startBatchNow(_QueuedBatch batch) async {
    final target = ref.notifier(doorstepPairingProvider).resolveTarget(batch.paired);
    final ip = target.ip;
    if (ip == null || ip.isEmpty || ip == '0.0.0.0' || ip == '-') {
      for (final file in batch.files) {
        _transferPolls.remove(file.transferId)?.cancel();
        updateStatus(file.transferId, DoorstepTransferStatus.failed, errorMessage: '${batch.paired.alias} is not reachable right now');
      }
      return null;
    }

    // Follow the session live (it is created inside [startSession]) until it
    // is closed — background sessions close themselves on success — and mirror
    // its status into the activity rows as it goes. The session is located by
    // the target fingerprint, because [startSession] only returns its id at
    // the very end of the transfer.
    String? liveSessionId;
    final poller = Timer.periodic(_progressPollInterval, (_) {
      final sessions = ref.read(sendProvider);
      final session = liveSessionId != null
          ? sessions[liveSessionId]
          : sessions.values.firstWhereOrNull(
              (s) =>
                  s.target.fingerprint == target.fingerprint &&
                  (s.status == SessionStatus.waiting || s.status == SessionStatus.sending) &&
                  _sessionMatchesBatch(s, batch.files),
            );
      if (session == null) {
        if (liveSessionId != null) {
          // The tracked session disappeared — the background session closes
          // itself on success, so this means the transfer finished.
          for (final file in batch.files) {
            _transferPolls.remove(file.transferId)?.cancel();
            updateStatus(file.transferId, DoorstepTransferStatus.completed, progress: 1);
          }
          _logger.info('Batch transfer to ${batch.paired.alias} (${batch.files.length} file(s)) completed');
        }
        return;
      }
      liveSessionId = session.sessionId;

      switch (session.status) {
        case SessionStatus.sending:
          _mirrorBatchProgress(session, batch.files);
        case SessionStatus.finishedWithErrors:
        case SessionStatus.finished:
        case SessionStatus.canceledBySender:
        case SessionStatus.canceledByReceiver:
        case SessionStatus.declined:
        case SessionStatus.recipientBusy:
        case SessionStatus.tooManyAttempts:
          for (final file in batch.files) {
            _transferPolls.remove(file.transferId)?.cancel();
          }
          _applySessionOutcomeToRows(session, batch.files);
        case SessionStatus.waiting:
          break;
      }
    });
    for (final file in batch.files) {
      _transferPolls[file.transferId] = poller;
    }

    String? sessionId;
    try {
      sessionId = await ref
          .notifier(sendProvider)
          .startSession(target: target, files: batch.files.map((f) => f.crossFile).toList(), background: true);
    } catch (e) {
      _logger.warning('Batch transfer to ${batch.paired.alias} failed to start', e);
      for (final file in batch.files) {
        _transferPolls.remove(file.transferId)?.cancel();
        updateStatus(file.transferId, DoorstepTransferStatus.failed, errorMessage: e.humanErrorMessage);
      }
      return null;
    }

    if (sessionId == null) {
      // Declined, busy, or aborted before the session materialized.
      for (final file in batch.files) {
        _transferPolls.remove(file.transferId)?.cancel();
        updateStatus(file.transferId, DoorstepTransferStatus.failed, errorMessage: 'Transfer was not accepted by ${target.alias}');
      }
    } else if (liveSessionId == null) {
      // The transfer was faster than the poller — inspect the leftover session
      // to tell success from failure.
      final remaining = ref.read(sendProvider)[sessionId];
      for (final file in batch.files) {
        _transferPolls.remove(file.transferId)?.cancel();
      }
      if (remaining == null) {
        for (final file in batch.files) {
          updateStatus(file.transferId, DoorstepTransferStatus.completed, progress: 1);
        }
      } else {
        _applySessionOutcomeToRows(remaining, batch.files);
      }
    }

    return sessionId;
  }

  /// The fingerprint alone is not unique — several batches can run to the
  /// same phone over time. Disambiguate by the file set so each batch's
  /// poller tracks its own session.
  bool _sessionMatchesBatch(SendSessionState session, List<_PendingFile> files) {
    if (session.files.length != files.length) return false;
    final names = files.map((f) => (f.crossFile.name, f.crossFile.size)).toSet();
    return session.files.values.every((sf) => names.contains((sf.file.fileName, sf.file.size)));
  }

  /// Mirrors the sending session's per-file progress into the activity rows.
  void _mirrorBatchProgress(SendSessionState session, List<_PendingFile> files) {
    final progress = ref.read(progressProvider);
    for (final file in files) {
      final sessionFile = session.files.values.firstWhereOrNull(
        (sf) => sf.file.fileName == file.crossFile.name && sf.file.size == file.crossFile.size,
      );
      if (sessionFile == null || sessionFile.token == null) continue; // not accepted by the receiver
      final fileProgress = progress.getProgress(sessionId: session.sessionId, fileId: sessionFile.file.id);
      updateStatus(file.transferId, DoorstepTransferStatus.transferring, progress: fileProgress.clamp(0.0, 1.0));
    }
  }

  /// Applies the final outcome of [session] to each activity row.
  void _applySessionOutcomeToRows(SendSessionState session, List<_PendingFile> files) {
    for (final file in files) {
      final sessionFile = session.files.values.firstWhereOrNull(
        (sf) => sf.file.fileName == file.crossFile.name && sf.file.size == file.crossFile.size,
      );
      final failed = sessionFile?.status == FileStatus.failed;
      updateStatus(
        file.transferId,
        failed ? DoorstepTransferStatus.failed : DoorstepTransferStatus.completed,
        progress: failed ? null : 1,
        errorMessage: failed ? session.errorMessage : null,
      );
    }
  }
}
