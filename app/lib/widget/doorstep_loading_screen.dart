import 'dart:async';

import 'package:doorstep_app/config/doorstep_theme.dart';
import 'package:doorstep_app/model/state/doorstep_transfer_state.dart';
import 'package:doorstep_app/provider/doorstep_transfer_provider.dart';
import 'package:doorstep_app/provider/network/send_provider.dart';
import 'package:doorstep_app/provider/network/server/server_provider.dart';
import 'package:doorstep_app/widget/doorstep_logo.dart';
import 'package:flutter/material.dart';
import 'package:localsend_isolates/model/session_status.dart';
import 'package:refena_flutter/refena_flutter.dart';

/// Full-screen loading screen shown while files are transferring.
///
/// Mounted via `MaterialApp.builder` so it covers every route. It appears once
/// per transfer batch and stays up until the whole batch is done — dismissing
/// it hides it for the remainder of the batch (never once per file). Renders
/// nothing when no transfer is active.
class DoorstepTransferOverlay extends StatefulWidget {
  const DoorstepTransferOverlay({super.key});

  @override
  State<DoorstepTransferOverlay> createState() => _DoorstepTransferOverlayState();
}

/// The batch is considered finished (and the dismiss state resets) only after
/// transfers have been idle for this long — long enough to smooth over the
/// small gaps between sequential files in one batch.
const _idleResetAfter = Duration(seconds: 4);

class _DoorstepTransferOverlayState extends State<DoorstepTransferOverlay> with Refena {
  /// True while the user dismissed the overlay for the current batch.
  bool _dismissed = false;
  Timer? _idleTimer;

  @override
  void dispose() {
    _idleTimer?.cancel();
    super.dispose();
  }

  /// Active Doorstep transfers (pending or in flight) — drives the file name,
  /// count and progress ring.
  List<DoorstepTransferState> get _activeDoorstep {
    return ref.watch(
      doorstepTransferProvider.select(
        (list) => list.where((t) => t.status == DoorstepTransferStatus.pending || t.status == DoorstepTransferStatus.transferring).toList(),
      ),
    );
  }

  /// Whether any non-Doorstep send/receive session is in flight.
  bool get _hasLegacyTransfer {
    final sending = ref.watch(sendProvider.select((sessions) => sessions.values.any((s) => s.status == SessionStatus.sending)));
    final receiving = ref.watch(serverProvider.select((s) => s?.session?.status)) == SessionStatus.sending;
    return sending || receiving;
  }

  @override
  Widget build(BuildContext context) {
    final doorstep = _activeDoorstep;
    final active = doorstep.isNotEmpty || _hasLegacyTransfer;

    if (!active) {
      // Idle — after a grace period, allow the next batch to show the screen
      // again. This keeps sequential files in one batch from re-showing it.
      _idleTimer ??= Timer(_idleResetAfter, () {
        if (mounted) setState(() => _dismissed = false);
      });
      return const SizedBox.shrink();
    }

    _idleTimer?.cancel();
    _idleTimer = null;

    if (_dismissed) {
      return const SizedBox.shrink();
    }

    return Material(
      type: MaterialType.transparency,
      child: Container(
        color: DoorstepTheme.background,
        child: Stack(
          fit: StackFit.expand,
          children: [
            SafeArea(
              child: Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: IconButton(
                    tooltip: 'Hide for this batch',
                    onPressed: () => setState(() => _dismissed = true),
                    icon: const Icon(Icons.close_rounded, color: DoorstepTheme.textMuted),
                  ),
                ),
              ),
            ),
            Center(
              child: _LoadingContent(doorstep: doorstep),
            ),
          ],
        ),
      ),
    );
  }
}

/// The animated centerpiece: logo, progress ring and current file.
class _LoadingContent extends StatelessWidget {
  final List<DoorstepTransferState> doorstep;

  const _LoadingContent({required this.doorstep});

  @override
  Widget build(BuildContext context) {
    final hasDoorstep = doorstep.isNotEmpty;
    final progress = hasDoorstep
        ? (doorstep.map((t) => t.progress).reduce((a, b) => a + b) / doorstep.length).clamp(0.0, 1.0)
        : 0.0;
    final current = hasDoorstep ? doorstep.first : null;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Logo inside a smooth progress ring.
        SizedBox(
          width: 132,
          height: 132,
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: progress),
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeOutCubic,
            builder: (context, value, child) => CustomPaint(
              painter: _ProgressRingPainter(progress: value),
              child: Center(child: child),
            ),
            child: const _PulsingLogo(),
          ),
        ),
        const SizedBox(height: 34),
        Text(
          hasDoorstep ? 'Sending to ${current!.targetDevice}' : 'Transferring…',
          style: const TextStyle(
            color: DoorstepTheme.textMain,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        if (hasDoorstep) ...[
          Text(
            current!.fileName,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: DoorstepTheme.primary, fontSize: 14.5),
          ),
          const SizedBox(height: 6),
          Text(
            doorstep.length > 1 ? '${doorstep.length} file${doorstep.length == 1 ? '' : 's'} left' : 'Hang tight — almost there',
            style: const TextStyle(color: DoorstepTheme.textMuted, fontSize: 12.5),
          ),
        ] else ...[
          const Text(
            'Files are moving between your devices',
            style: TextStyle(color: DoorstepTheme.textMuted, fontSize: 13),
          ),
        ],
      ],
    );
  }
}

/// Gently pulsing Doorstep logo so the screen feels alive without noise.
class _PulsingLogo extends StatefulWidget {
  const _PulsingLogo();

  @override
  State<_PulsingLogo> createState() => _PulsingLogoState();
}

class _PulsingLogoState extends State<_PulsingLogo> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600));
    unawaited(_controller.repeat(reverse: true));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: Tween(begin: 0.94, end: 1.0).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut)),
      child: const DoorstepLogo(withText: false, size: 76),
    );
  }
}

/// Thin circular progress ring around the logo.
class _ProgressRingPainter extends CustomPainter {
  final double progress;

  _ProgressRingPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 7;

    final track = Paint()
      ..color = DoorstepTheme.surfaceBorder
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, track);

    if (progress <= 0) return;
    final arc = Paint()
      ..color = DoorstepTheme.primary
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -1.5708, // start at top
      6.2832 * progress.clamp(0.0, 1.0),
      false,
      arc,
    );
  }

  @override
  bool shouldRepaint(covariant _ProgressRingPainter oldDelegate) => oldDelegate.progress != progress;
}
