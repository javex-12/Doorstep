import 'package:doorstep_app/config/doorstep_theme.dart';
import 'package:doorstep_app/model/persistence/paired_device.dart';
import 'package:flutter/material.dart';

/// Asks how much the user trusts a device before it is remembered.
///
/// This is the single place the question is asked — used both when *we* connect
/// out to a discovered device and when *they* ask to connect to us. Returns the
/// chosen [DeviceTrustLevel], or `null` when the user backs out.
Future<DeviceTrustLevel?> showTrustDeviceDialog(
  BuildContext context, {
  required String alias,
  required bool incoming,
  String? address,
}) {
  return showDialog<DeviceTrustLevel>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) {
      final isDark = Theme.of(ctx).brightness == Brightness.dark;
      return AlertDialog(
        title: Text(
          incoming ? 'Allow “$alias”?' : 'Connect to “$alias”?',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              incoming ? '“$alias” wants to connect to this device over the Doorstep network.' : 'This device is on your Doorstep network right now.',
              style: TextStyle(color: DoorstepTheme.textMutedOf(ctx), fontSize: 13.5, height: 1.45),
            ),
            if (address != null) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: DoorstepTheme.surfaceOf(ctx),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: DoorstepTheme.borderOf(ctx)),
                ),
                child: Text(
                  address,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: DoorstepTheme.primaryOf(ctx), fontSize: 12, fontFamily: 'monospace'),
                ),
              ),
            ],
            const SizedBox(height: 18),
            _TrustOption(
              icon: Icons.home_rounded,
              title: 'My personal device',
              subtitle: 'Remember it. It reconnects by itself and files arrive without asking.',
              onTap: () => Navigator.of(ctx).pop(DeviceTrustLevel.persistent),
            ),
            const SizedBox(height: 10),
            _TrustOption(
              icon: Icons.timer_rounded,
              title: 'Just this once',
              subtitle: 'Temporary. Forgotten when Doorstep closes, and never reconnects on its own.',
              onTap: () => Navigator.of(ctx).pop(DeviceTrustLevel.temporary),
            ),
            const SizedBox(height: 6),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              style: TextButton.styleFrom(
                foregroundColor: isDark ? DoorstepTheme.textMuted : const Color(0xFF64748B),
              ),
              child: const Text('Not now'),
            ),
          ],
        ),
      );
    },
  );
}

class _TrustOption extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _TrustOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final primary = DoorstepTheme.primaryOf(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: primary.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: primary.withValues(alpha: 0.22), width: 1),
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: primary.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(icon, color: primary, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(color: DoorstepTheme.textMainOf(context), fontSize: 14, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(color: DoorstepTheme.textMutedOf(context), fontSize: 11.5, height: 1.35),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
