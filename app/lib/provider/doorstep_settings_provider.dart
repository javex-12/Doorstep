import 'package:doorstep_app/provider/persistence_provider.dart';
import 'package:doorstep_app/util/notification_strings.dart';
import 'package:doorstep_isolates/util/foreground_service.dart';
import 'package:refena_flutter/refena_flutter.dart';

/// User-facing Doorstep behavior switches, persisted separately from the
/// upstream Doorstep settings so the fork stays self-contained.
class DoorstepSettings {
  /// Whether transfers from paired devices are accepted silently (no prompt,
  /// no progress page). Defaults to true — that is the whole Doorstep promise.
  final bool autoAcceptFromPaired;

  /// Battery saver (phone side): while active, the phone stops announcing
  /// itself to laptops, so auto-transfer does not work until it is turned off.
  final bool sleepMode;

  /// Phone side: keep a listener running (foreground service + ongoing
  /// notification on Android) so a trusted laptop can push files even when the
  /// Doorstep UI is closed. Defaults to true — that is the Doorstep promise.
  final bool backgroundService;

  const DoorstepSettings({
    this.autoAcceptFromPaired = true,
    this.sleepMode = false,
    this.backgroundService = true,
  });

  DoorstepSettings copyWith({bool? autoAcceptFromPaired, bool? sleepMode, bool? backgroundService}) {
    return DoorstepSettings(
      autoAcceptFromPaired: autoAcceptFromPaired ?? this.autoAcceptFromPaired,
      sleepMode: sleepMode ?? this.sleepMode,
      backgroundService: backgroundService ?? this.backgroundService,
    );
  }
}

final doorstepSettingsProvider = NotifierProvider<DoorstepSettingsNotifier, DoorstepSettings>((ref) {
  return DoorstepSettingsNotifier();
});

class DoorstepSettingsNotifier extends Notifier<DoorstepSettings> {
  @override
  DoorstepSettings init() {
    final persistence = ref.read(persistenceProvider);
    return DoorstepSettings(
      autoAcceptFromPaired: persistence.getDoorstepAutoAccept(),
      sleepMode: persistence.getDoorstepSleepMode(),
      backgroundService: persistence.getDoorstepBackgroundService(),
    );
  }

  Future<void> setAutoAcceptFromPaired(bool value) async {
    state = state.copyWith(autoAcceptFromPaired: value);
    await ref.read(persistenceProvider).setDoorstepAutoAccept(value);
  }

  Future<void> setSleepMode(bool value) async {
    state = state.copyWith(sleepMode: value);
    await ref.read(persistenceProvider).setDoorstepSleepMode(value);
  }

  Future<void> setBackgroundService(bool value) async {
    state = state.copyWith(backgroundService: value);
    await ref.read(persistenceProvider).setDoorstepBackgroundService(value);
    // Apply immediately so the ongoing "Doorstep is on" notification appears or
    // disappears the moment the switch is flipped.
    ForegroundService.setKeepAlive(
      enabled: value,
      title: notificationStrings.idleTitle,
      text: notificationStrings.idleText,
    );
  }
}
