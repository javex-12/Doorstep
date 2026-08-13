import 'dart:async';

import 'package:doorstep_app/config/doorstep_theme.dart';
import 'package:doorstep_app/model/persistence/paired_device.dart';
import 'package:doorstep_app/provider/device_info_provider.dart';
import 'package:doorstep_app/provider/doorstep_pairing_provider.dart';
import 'package:doorstep_app/util/doorstep_pairing_helper.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:refena_flutter/refena_flutter.dart';

/// Phone-side pairing screen.
///
/// The laptop shows a QR code on its Doorstep tab; this page scans it with the
/// camera and stores the laptop as a paired device.
class DoorstepPairScanPage extends StatefulWidget {
  const DoorstepPairScanPage({super.key});

  @override
  State<DoorstepPairScanPage> createState() => _DoorstepPairScanPageState();
}

class _DoorstepPairScanPageState extends State<DoorstepPairScanPage> with Refena {
  final MobileScannerController _controller = MobileScannerController(
    facing: CameraFacing.back,
    detectionSpeed: DetectionSpeed.noDuplicates,
  );

  bool _processing = false;
  String? _hint;
  Timer? _hintTimer;
  _PairedInfo? _paired;
  bool _handshakeOk = false;

  @override
  void dispose() {
    _hintTimer?.cancel();
    unawaited(_controller.dispose());
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_processing || _paired != null) return;

    for (final barcode in capture.barcodes) {
      final raw = barcode.rawValue;
      if (raw == null) continue;

      final payload = DoorstepPairingPayload.decode(raw);
      if (payload == null) {
        _showHint('Not a Doorstep code — scan the QR shown in the Doorstep app on your laptop.');
        return;
      }

      setState(() => _processing = true);
      try {
        await _controller.stop();
        if (!mounted) return;

        // Ask the user how much this device is trusted before saving anything.
        final trust = await _askTrustLevel(payload.alias);
        if (trust == null) {
          // User cancelled — resume scanning.
          setState(() => _processing = false);
          await _controller.start();
          return;
        }

        final deviceInfo = ref.read(deviceFullInfoProvider);
        final paired = await ref
            .notifier(doorstepPairingProvider)
            .acceptPairing(
              payload: payload,
              localIp: deviceInfo.ip ?? '0.0.0.0',
              localPort: deviceInfo.port,
              trustLevel: trust,
            );

        final handshakeOk = await ref.notifier(doorstepPairingProvider).registerWithPairedDevice(paired);

        if (!mounted) return;
        setState(() {
          _paired = _PairedInfo(alias: payload.alias, ip: payload.ip, port: payload.port);
          _handshakeOk = handshakeOk;
        });
        unawaited(
          Future.delayed(const Duration(milliseconds: 2200), () {
            if (mounted) Navigator.of(context).pop();
          }),
        );
      } catch (e) {
        if (!mounted) return;
        setState(() => _processing = false);
        unawaited(_controller.start());
        _showHint('Could not save the paired device. Please try again.');
      }
      return;
    }
  }

  /// Shows the "how much do you trust this device?" dialog.
  /// Returns the chosen [DeviceTrustLevel], or `null` when cancelled.
  Future<DeviceTrustLevel?> _askTrustLevel(String alias) async {
    return showDialog<DeviceTrustLevel>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: DoorstepTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text(
          'Trust this device?',
          style: TextStyle(color: DoorstepTheme.textMain, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '"$alias" just asked to connect to this phone.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: DoorstepTheme.textMuted, fontSize: 14, height: 1.4),
            ),
            const SizedBox(height: 20),
            _TrustOption(
              icon: Icons.home_rounded,
              title: 'My personal device',
              subtitle: 'Remember it, reconnect automatically, files always arrive',
              onTap: () => Navigator.of(ctx).pop(DeviceTrustLevel.persistent),
            ),
            const SizedBox(height: 10),
            _TrustOption(
              icon: Icons.timer_rounded,
              title: 'Temporary — this session only',
              subtitle: 'No reconnects, forgotten when the app closes',
              onTap: () => Navigator.of(ctx).pop(DeviceTrustLevel.temporary),
            ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel', style: TextStyle(color: DoorstepTheme.textMuted)),
            ),
          ],
        ),
      ),
    );
  }

  void _showHint(String message) {
    _hintTimer?.cancel();
    setState(() => _hint = message);
    _hintTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _hint = null);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DoorstepTheme.background,
      body: _paired != null ? _buildSuccess() : _buildScanner(),
    );
  }

  Widget _buildScanner() {
    return Stack(
      fit: StackFit.expand,
      children: [
        MobileScanner(
          controller: _controller,
          onDetect: _onDetect,
          errorBuilder: (context, error) => _CameraErrorView(error: error),
        ),
        CustomPaint(
          painter: _ScanOverlayPainter(),
          child: const SizedBox.expand(),
        ),
        // Top bar
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: SafeArea(
            child: Row(
              children: [
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded, color: Colors.white),
                  tooltip: 'Close',
                ),
                const Expanded(
                  child: Text(
                    'Pair with Laptop',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 48),
              ],
            ),
          ),
        ),
        // Bottom instructions
        Positioned(
          left: 24,
          right: 24,
          bottom: 48,
          child: SafeArea(
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                  decoration: BoxDecoration(
                    color: DoorstepTheme.background.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: DoorstepTheme.surfaceBorder),
                  ),
                  child: const Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.wifi_rounded, color: DoorstepTheme.primary, size: 18),
                          SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              'Both devices must be on the same Wi-Fi network —\nor connect the phone to your laptop\u2019s hotspot.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: DoorstepTheme.primary, fontSize: 12.5, height: 1.35, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Then point your camera at the QR code shown in the Doorstep app on your laptop.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Color(0xFFE2E8F0), fontSize: 12.5, height: 1.4),
                      ),
                    ],
                  ),
                ),
                if (_hint != null) ...[
                  const SizedBox(height: 12),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: Container(
                      key: ValueKey(_hint),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: DoorstepTheme.danger.withValues(alpha: 0.85),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _hint!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSuccess() {
    final info = _paired!;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: TweenAnimationBuilder<double>(
          duration: const Duration(milliseconds: 700),
          curve: Curves.elasticOut,
          tween: Tween(begin: 0.0, end: 1.0),
          builder: (context, scale, child) {
            return Transform.scale(
              scale: scale,
              child: child,
            );
          },
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  color: DoorstepTheme.success.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_rounded, color: DoorstepTheme.success, size: 56),
              ),
              const SizedBox(height: 24),
              const Text(
                'Pairing Successful',
                style: TextStyle(color: DoorstepTheme.textMain, fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                info.alias,
                style: const TextStyle(color: DoorstepTheme.textMain, fontSize: 18, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: DoorstepTheme.surface,
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Text(
                  '${info.ip}:${info.port}',
                  style: const TextStyle(color: DoorstepTheme.primary, fontSize: 13, fontFamily: 'monospace'),
                ),
              ),
              const SizedBox(height: 24),
              if (_handshakeOk) ...[
                const Text(
                  'Files dropped into your laptop\'s drop zones will arrive here automatically.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: DoorstepTheme.textMuted, fontSize: 14, height: 1.4),
                ),
              ] else ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: DoorstepTheme.warning.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: DoorstepTheme.warning.withValues(alpha: 0.3)),
                  ),
                  child: const Text(
                    'Paired locally — could not reach the laptop right now. It will connect automatically when Doorstep is open on your laptop.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: DoorstepTheme.warning, fontSize: 13, height: 1.4),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _PairedInfo {
  final String alias;
  final String ip;
  final int port;

  const _PairedInfo({required this.alias, required this.ip, required this.port});
}

/// One selectable trust option in the "Trust this device?" dialog.
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
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: DoorstepTheme.surfaceBorder.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: DoorstepTheme.surfaceBorder, width: 0.8),
        ),
        child: Row(
          children: [
            Icon(icon, color: DoorstepTheme.primary, size: 24),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: DoorstepTheme.textMain,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(color: DoorstepTheme.textMuted, fontSize: 11.5, height: 1.3),
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

// ── Camera error / permission view ───────────────────────────────────────────

class _CameraErrorView extends StatelessWidget {
  final MobileScannerException error;

  const _CameraErrorView({required this.error});

  @override
  Widget build(BuildContext context) {
    final isPermissionError = error.errorCode == MobileScannerErrorCode.permissionDenied;

    return Container(
      color: DoorstepTheme.background,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.no_photography_outlined, color: DoorstepTheme.textMuted, size: 56),
              const SizedBox(height: 16),
              Text(
                isPermissionError ? 'Camera permission needed' : 'Camera unavailable',
                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                isPermissionError
                    ? 'Doorstep needs camera access to scan your laptop\u2019s pairing QR code.'
                    : 'Something went wrong while starting the camera. Please try again.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: DoorstepTheme.textMuted, fontSize: 13),
              ),
              const SizedBox(height: 20),
              if (isPermissionError)
                FilledButton.icon(
                  onPressed: () => openAppSettings(),
                  icon: const Icon(Icons.settings),
                  label: const Text('Open settings'),
                )
              else
                OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Go back'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Scan window overlay ───────────────────────────────────────────────────────

class _ScanOverlayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final overlay = Paint()..color = const Color(0x990A0D11);
    final windowSize = size.shortestSide * 0.62;
    final left = (size.width - windowSize) / 2;
    final top = (size.height - windowSize) / 2 - 40;
    final rect = Rect.fromLTWH(left, top, windowSize, windowSize);

    final path = Path()
      ..addRect(Offset.zero & size)
      ..addRRect(RRect.fromRectAndRadius(rect, const Radius.circular(24)))
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(path, overlay);

    final corner = Paint()
      ..color = DoorstepTheme.primary
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    const length = 26.0;
    const r = 24.0;

    // Top-left
    canvas.drawLine(Offset(rect.left, rect.top + r), Offset(rect.left, rect.top + length), corner);
    canvas.drawLine(Offset(rect.left + r, rect.top), Offset(rect.left + length, rect.top), corner);
    // Top-right
    canvas.drawLine(Offset(rect.right - r, rect.top), Offset(rect.right - length, rect.top), corner);
    canvas.drawLine(Offset(rect.right, rect.top + r), Offset(rect.right, rect.top + length), corner);
    // Bottom-left
    canvas.drawLine(Offset(rect.left, rect.bottom - r), Offset(rect.left, rect.bottom - length), corner);
    canvas.drawLine(Offset(rect.left + r, rect.bottom), Offset(rect.left + length, rect.bottom), corner);
    // Bottom-right
    canvas.drawLine(Offset(rect.right - r, rect.bottom), Offset(rect.right - length, rect.bottom), corner);
    canvas.drawLine(Offset(rect.right, rect.bottom - r), Offset(rect.right, rect.bottom - length), corner);
  }

  @override
  bool shouldRepaint(covariant _ScanOverlayPainter oldDelegate) => false;
}
