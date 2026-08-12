import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:localsend_app/config/doorstep_theme.dart';
import 'package:localsend_app/model/persistence/receive_history_entry.dart';
import 'package:localsend_isolates/util/file_size_helper.dart';

/// One-shot "a file just walked in" hero animation.
///
/// Two doors swing open, a paper file flies into the glowing doorway with a
/// sparkle burst, and the whole card settles with a bounce. Used in the
/// Activity tab whenever a new file is received.
class DoorEntryAnimation extends StatefulWidget {
  final ReceiveHistoryEntry entry;
  final VoidCallback onDone;

  const DoorEntryAnimation({required this.entry, required this.onDone, super.key});

  @override
  State<DoorEntryAnimation> createState() => _DoorEntryAnimationState();
}

class _DoorEntryAnimationState extends State<DoorEntryAnimation> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _flash;
  late final Animation<double> _doors;
  late final Animation<double> _fileIn;
  late final Animation<double> _sparkle;
  late final Animation<double> _caption;
  late final Animation<double> _settle;
  late final List<_Sparkle> _sparkles;
  Timer? _doneTimer;

  static const _doorwayWidth = 160.0;
  static const _doorwayHeight = 178.0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 2600));
    unawaited(_controller.forward());

    _flash = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.3, curve: Curves.easeOutCubic),
    );
    _doors = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.1, 0.48, curve: Curves.easeOutBack),
    );
    _fileIn = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.32, 0.7, curve: Curves.elasticOut),
    );
    _sparkle = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.55, 0.9, curve: Curves.easeOut),
    );
    _caption = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.55, 1.0, curve: Curves.easeOut),
    );
    _settle = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.72, 1.0, curve: Curves.elasticOut),
    );

    _sparkles = List.generate(16, (_) => _Sparkle.random());

    // Hold the finished frame for a beat, then hand control back to the tab.
    _doneTimer = Timer(const Duration(milliseconds: 3400), widget.onDone);
  }

  @override
  void dispose() {
    _doneTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        // The whole card bounces as it settles.
        final scale = 1 + 0.06 * (1 - _settle.value);
        return Transform.scale(
          scale: scale,
          child: child,
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF131720), DoorstepTheme.background],
          ),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: DoorstepTheme.primary.withValues(alpha: 0.25), width: 0.8),
          boxShadow: [
            BoxShadow(
              color: DoorstepTheme.primary.withValues(alpha: 0.12),
              blurRadius: 28,
              spreadRadius: 2,
            ),
          ],
        ),
        padding: const EdgeInsets.fromLTRB(20, 26, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: _doorwayHeight + 34,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Portal flash ring
                  _FlashRing(progress: _flash.value),
                  // The doorway the file walks into
                  _buildDoorway(),
                  // Sparkle burst as the file lands
                  Positioned.fill(
                    child: IgnorePointer(
                      child: CustomPaint(
                        painter: _SparklePainter(progress: _sparkle.value, center: const Offset(0, -6), particles: _sparkles),
                      ),
                    ),
                  ),
                  // The file itself
                  _buildFlyingFile(),
                ],
              ),
            ),
            const SizedBox(height: 10),
            // Caption
            Opacity(
              opacity: _caption.value,
              child: Transform.translate(
                offset: Offset(0, 10 * (1 - _caption.value)),
                child: Column(
                  children: [
                    Text(
                      widget.entry.fileName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Just arrived from ${widget.entry.senderAlias} · ${widget.entry.fileSize.asReadableFileSize}',
                      style: const TextStyle(color: DoorstepTheme.textMuted, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDoorway() {
    return SizedBox(
      width: _doorwayWidth,
      height: _doorwayHeight,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Portal glow inside the doorway
          Container(
            width: _doorwayWidth,
            height: _doorwayHeight,
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(0, -0.15),
                radius: 1.1,
                colors: [
                  Color.lerp(DoorstepTheme.accent, DoorstepTheme.primary, _flash.value)!,
                  const Color(0xFF0B0D11),
                ],
                stops: const [0.15, 0.85],
              ),
              borderRadius: BorderRadius.vertical(top: Radius.circular(_doorwayWidth / 2)),
              boxShadow: [
                BoxShadow(
                  color: DoorstepTheme.primary.withValues(alpha: 0.25 + 0.3 * (1 - _flash.value)),
                  blurRadius: 26,
                  spreadRadius: 2,
                ),
              ],
            ),
          ),
          // Doorframe
          Container(
            width: _doorwayWidth + 12,
            height: _doorwayHeight + 12,
            decoration: BoxDecoration(
              border: Border.all(color: DoorstepTheme.surfaceBorder, width: 3),
              borderRadius: BorderRadius.vertical(top: Radius.circular((_doorwayWidth + 12) / 2)),
            ),
          ),
          // Left door (hinged on its left edge)
          Align(
            alignment: Alignment.centerLeft,
            child: Transform(
              alignment: Alignment.centerLeft,
              transform: Matrix4.identity()
                ..setEntry(3, 2, 0.0016)
                ..rotateY(-math.pi / 2 * 0.97 * _doors.value),
              child: _DoorPanel(isLeft: true, width: _doorwayWidth / 2, height: _doorwayHeight),
            ),
          ),
          // Right door (hinged on its right edge)
          Align(
            alignment: Alignment.centerRight,
            child: Transform(
              alignment: Alignment.centerRight,
              transform: Matrix4.identity()
                ..setEntry(3, 2, 0.0016)
                ..rotateY(math.pi / 2 * 0.97 * _doors.value),
              child: _DoorPanel(isLeft: false, width: _doorwayWidth / 2, height: _doorwayHeight),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFlyingFile() {
    return Transform.translate(
      offset: Offset(0, -42 * (1 - _fileIn.value)),
      child: Opacity(
        opacity: _fileIn.value.clamp(0.0, 1.0),
        child: Transform.scale(
          scale: 0.15 + 0.85 * _fileIn.value,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Glow behind the paper
              Container(
                width: 110,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFF818CF8).withValues(alpha: 0.55 * _fileIn.value.clamp(0.0, 1.0)),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
              const _PaperFile(),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Door panel ───────────────────────────────────────────────────────────────

class _DoorPanel extends StatelessWidget {
  final bool isLeft;
  final double width;
  final double height;

  const _DoorPanel({required this.isLeft, required this.width, required this.height});

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.horizontal(
      left: Radius.circular(isLeft ? 20 : 4),
      right: Radius.circular(isLeft ? 4 : 20),
    );

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: 0.16),
            Colors.white.withValues(alpha: 0.03),
          ],
        ),
        borderRadius: borderRadius,
        border: Border.all(color: DoorstepTheme.primary.withValues(alpha: 0.35), width: 1.5),
      ),
      child: Stack(
        children: [
          // Glass panel vector patterns
          Positioned.fill(
            child: CustomPaint(painter: _GlassPanelPainter(isLeft: isLeft)),
          ),
          // Glowing modern handle on the inner edge
          Align(
            alignment: isLeft ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(
              margin: EdgeInsets.only(right: isLeft ? 10 : 0, left: isLeft ? 0 : 10),
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: DoorstepTheme.accent,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: DoorstepTheme.accent.withValues(alpha: 0.6),
                    blurRadius: 8,
                    spreadRadius: 2,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GlassPanelPainter extends CustomPainter {
  final bool isLeft;

  const _GlassPanelPainter({required this.isLeft});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = DoorstepTheme.primary.withValues(alpha: 0.18)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;

    // Draw an elegant geometric pattern on the glass panel:
    // A vertical line down the middle of the panel, and some diagonal accent lines at the top/bottom
    final x = size.width * 0.5;
    canvas.drawLine(Offset(x, 4), Offset(x, size.height - 4), paint);

    // Diagonal tech details
    final path = Path()
      ..moveTo(isLeft ? 6 : size.width - 6, size.height * 0.15)
      ..lineTo(x, size.height * 0.25)
      ..moveTo(isLeft ? 6 : size.width - 6, size.height * 0.85)
      ..lineTo(x, size.height * 0.75);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _GlassPanelPainter oldDelegate) => oldDelegate.isLeft != isLeft;
}

// ── The paper file ───────────────────────────────────────────────────────────

class _PaperFile extends StatelessWidget {
  const _PaperFile();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 62,
      height: 78,
      child: CustomPaint(painter: _PaperPainter()),
    );
  }
}

class _PaperPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(12),
    );

    // Glowing futuristic card body
    canvas.drawRRect(rect, Paint()..color = DoorstepTheme.surface);
    canvas.drawRRect(
      rect,
      Paint()
        ..color = DoorstepTheme.primary.withValues(alpha: 0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6,
    );

    // Document header bar
    canvas.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(8, 8, 22, 6), const Radius.circular(3)),
      Paint()..color = DoorstepTheme.primary,
    );

    // Text lines represented as modern dashes
    final linePaint = Paint()
      ..color = DoorstepTheme.textMuted.withValues(alpha: 0.7)
      ..strokeWidth = 2.8
      ..strokeCap = StrokeCap.round;

    final lineY = const [24.0, 34.0, 44.0, 54.0];
    for (final y in lineY) {
      canvas.drawLine(Offset(8, y), Offset(size.width - 10, y), linePaint);
    }

    // Bottom accent details
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(8, size.height - 12, 14, 4), const Radius.circular(2)),
      Paint()..color = DoorstepTheme.accent,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ── Flash ring ───────────────────────────────────────────────────────────────

class _FlashRing extends StatelessWidget {
  final double progress;

  const _FlashRing({required this.progress});

  @override
  Widget build(BuildContext context) {
    final size = 60 + 240 * progress;
    final opacity = (1 - progress).clamp(0.0, 1.0);
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: const Color(0xFF818CF8).withValues(alpha: 0.55 * opacity),
            width: 3,
          ),
        ),
      ),
    );
  }
}

// ── Sparkles ─────────────────────────────────────────────────────────────────

class _Sparkle {
  final double angle;
  final double distance;
  final double size;
  final Color color;
  final double delay;

  _Sparkle({
    required this.angle,
    required this.distance,
    required this.size,
    required this.color,
    required this.delay,
  });

  factory _Sparkle.random() {
    final rng = math.Random();
    return _Sparkle(
      angle: rng.nextDouble() * math.pi * 2,
      distance: 50 + rng.nextDouble() * 95,
      size: 2 + rng.nextDouble() * 4,
      color: [const Color(0xFFFFFFFF), const Color(0xFF818CF8), const Color(0xFFFBBF24)][rng.nextInt(3)],
      delay: rng.nextDouble() * 0.25,
    );
  }
}

class _SparklePainter extends CustomPainter {
  final double progress;
  final Offset center;
  final List<_Sparkle> particles;

  _SparklePainter({required this.progress, required this.center, required this.particles});

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;
    final origin = Offset(size.width / 2 + center.dx, size.height / 2 + center.dy);

    for (final sparkle in particles) {
      final p = ((progress - sparkle.delay) / (1 - sparkle.delay)).clamp(0.0, 1.0);
      if (p <= 0 || p >= 1) continue;

      final pos = Offset(
        origin.dx + math.cos(sparkle.angle) * sparkle.distance * p,
        origin.dy + math.sin(sparkle.angle) * sparkle.distance * p,
      );
      final opacity = math.pow(1 - p, 2).toDouble();
      canvas.drawCircle(
        pos,
        sparkle.size * (1 - 0.4 * p),
        Paint()..color = sparkle.color.withValues(alpha: 0.9 * opacity),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _SparklePainter oldDelegate) => oldDelegate.progress != progress;
}
