/// The translated strings that this package needs but cannot produce on its own: the app owns the
/// translations, and the dependency only points from the app to this package.
///
/// Inject an instance via `TransferNotification.init`. The signatures mirror the ones slang
/// generates, so the app can hand over its translation members directly.
class NotificationStrings {
  /// Title while files are being received, e.g. "Receiving files".
  final String titleReceiving;

  /// Title while files are being sent, e.g. "Sending files".
  final String titleSending;

  /// Remaining time below a minute, e.g. "0:45". [ss] is zero padded.
  final String Function({required Object n, required Object ss}) remainingTimeSeconds;

  /// Remaining time below an hour, e.g. "1:30". [ss] is zero padded.
  final String Function({required Object n, required Object ss}) remainingTimeMinutes;

  /// Remaining time below a day, e.g. "2h 5m".
  final String Function({required Object h, required Object m}) remainingTimeHours;

  /// Remaining time of a day or more, e.g. "3d 4h 5m".
  final String Function({required Object d, required Object h, required Object m}) remainingTimeDays;

  /// Title of the persistent notification while Doorstep is idle but staying
  /// on, e.g. "Doorstep is on".
  final String idleTitle;

  /// Text of the persistent notification while Doorstep is idle, e.g.
  /// "Ready to receive files".
  final String idleText;

  const NotificationStrings({
    required this.titleReceiving,
    required this.titleSending,
    required this.remainingTimeSeconds,
    required this.remainingTimeMinutes,
    required this.remainingTimeHours,
    required this.remainingTimeDays,
    this.idleTitle = 'Doorstep is on',
    this.idleText = 'Ready to receive files',
  });
}
