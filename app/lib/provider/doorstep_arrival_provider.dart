import 'package:refena_flutter/refena_flutter.dart';

/// Tracks which receive-history entry the arrival animation has already been
/// played for, so switching tabs does not replay it.
final doorstepArrivalProvider = NotifierProvider<DoorstepArrivalNotifier, String?>((ref) {
  return DoorstepArrivalNotifier();
});

class DoorstepArrivalNotifier extends Notifier<String?> {
  @override
  String? init() => null;

  void markAnimated(String entryId) {
    state = entryId;
  }
}
