import 'dart:async';

import 'package:doorstep_app/model/persistence/paired_device.dart';
import 'package:doorstep_app/provider/doorstep_pairing_provider.dart';
import 'package:doorstep_app/provider/doorstep_quick_send_provider.dart';
import 'package:doorstep_app/provider/network/nearby_devices_provider.dart';
import 'package:doorstep_app/provider/network/send_provider.dart';
import 'package:doorstep_app/provider/persistence_provider.dart';
import 'package:doorstep_app/provider/selection/selected_sending_files_provider.dart';
import 'package:flutter/services.dart';
import 'package:logging/logging.dart';
import 'package:refena_flutter/refena_flutter.dart';

final _logger = Logger('DoorstepClipboard');

class DoorstepClipboardState {
  final bool enabled;
  final DateTime? lastSyncAt;

  const DoorstepClipboardState({this.enabled = false, this.lastSyncAt});
}

final doorstepClipboardProvider = NotifierProvider<DoorstepClipboardNotifier, DoorstepClipboardState>((ref) {
  return DoorstepClipboardNotifier();
});

/// Keeps the clipboard in step across this user's own devices.
///
/// The transport is deliberately the ordinary Doorstep transfer — a clipboard
/// entry is just a tiny `text/plain` note — so nothing new has to be reachable
/// through firewalls, and it works on every platform Doorstep already supports.
///
/// What differs per platform is *watching* the clipboard:
///
///  - **Desktop**: readable at any time, so clipboard → your devices runs
///    continuously in the background.
///  - **Android / iOS**: the OS blocks reading the clipboard from the
///    background, so this direction only runs while Doorstep is in the
///    foreground. *Writing* a received entry is always allowed, so
///    your devices → phone works even when Doorstep is closed.
class DoorstepClipboardNotifier extends Notifier<DoorstepClipboardState> {
  Timer? _timer;

  /// The last text this device sent or applied. Compared against to decide
  /// whether the clipboard actually changed — and, together with
  /// [_lastReceived], to break the echo loop (A sends → B sets clipboard → B
  /// would otherwise send it right back).
  String? _lastSeen;
  String? _lastReceived;

  @override
  DoorstepClipboardState init() {
    final enabled = ref.read(persistenceProvider).getDoorstepClipboardSync();
    if (enabled) {
      unawaited(Future.microtask(_start));
    }
    return DoorstepClipboardState(enabled: enabled);
  }

  Future<void> setEnabled(bool value) async {
    state = DoorstepClipboardState(enabled: value, lastSyncAt: state.lastSyncAt);
    await ref.read(persistenceProvider).setDoorstepClipboardSync(value);
    if (value) {
      _start();
    } else {
      _timer?.cancel();
      _timer = null;
    }
  }

  /// Remembers text Doorstep just wrote to the clipboard itself, so the watcher
  /// does not treat its own write as a change and send it back.
  void noteReceived(String text) {
    _lastReceived = text;
    _lastSeen = text;
  }

  void _start() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(milliseconds: 1500), (_) => unawaited(_tick()));
  }

  Future<void> _tick() async {
    if (!state.enabled) return;

    final targets = _onlineTrustedDevices();
    if (targets.isEmpty) return;

    final String? text;
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      text = data?.text;
    } catch (_) {
      // Reading is refused while the app is backgrounded on mobile. Not an
      // error worth surfacing — the next tick simply tries again.
      return;
    }

    if (text == null || text.trim().isEmpty) return;
    if (text == _lastSeen || text == _lastReceived) return;
    _lastSeen = text;

    for (final device in targets) {
      try {
        await ref.notifier(sendProvider).startSession(
          target: ref.notifier(doorstepPairingProvider).resolveTarget(device),
          files: [buildNoteFile(text)],
          background: true,
        );
      } catch (e) {
        _logger.info('Clipboard sync to ${device.alias} did not start: $e');
      }
    }

    state = DoorstepClipboardState(enabled: true, lastSyncAt: DateTime.now());
  }

  /// Every remembered, currently reachable device — clipboard sync only ever
  /// touches devices the user deliberately made permanent.
  List<PairedDevice> _onlineTrustedDevices() {
    return onlineTrustedDevicesOf(ref.read(doorstepPairingProvider), ref.read(nearbyDevicesProvider));
  }

  /// Whether any device is reachable right now, so the UI can say why nothing
  /// is syncing instead of looking broken.
  bool get hasReachableDevice => _onlineTrustedDevices().isNotEmpty;

  /// Exposed for the settings subtitle.
  List<String> get reachableAliases => _onlineTrustedDevices().map((d) => d.alias).toList();

  @override
  void dispose() {
    _timer?.cancel();
    _timer = null;
    super.dispose();
  }
}
