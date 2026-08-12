import 'package:localsend_app/provider/persistence_provider.dart';
import 'package:refena_flutter/refena_flutter.dart';

/// User-facing Doorstep behavior switches, persisted separately from the
/// upstream LocalSend settings so the fork stays self-contained.
class DoorstepSettings {
  /// Whether transfers from paired devices are accepted silently (no prompt,
  /// no progress page). Defaults to true — that is the whole Doorstep promise.
  final bool autoAcceptFromPaired;

  /// Battery saver (phone side): while active, the phone stops announcing
  /// itself to laptops, so auto-transfer does not work until it is turned off.
  final bool sleepMode;

  const DoorstepSettings({
    this.autoAcceptFromPaired = true,
    this.sleepMode = false,
  });

  DoorstepSettings copyWith({bool? autoAcceptFromPaired, bool? sleepMode}) {
    return DoorstepSettings(
      autoAcceptFromPaired: autoAcceptFromPaired ?? this.autoAcceptFromPaired,
      sleepMode: sleepMode ?? this.sleepMode,
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
}
