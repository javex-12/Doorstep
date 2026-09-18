import 'dart:async';

import 'package:doorstep_app/config/doorstep_theme.dart';
import 'package:flutter/material.dart';

/// Visual tone of a [DoorstepStatusChip].
enum DoorstepStatusTone { positive, neutral, warning, negative }

/// A compact, truthful state chip: a coloured dot plus a short label.
///
/// Used for connection state ("Ready to receive", "Not reachable",
/// "Sleep mode", "Online"/"Offline") so the state is never communicated by
/// decoration or colour alone — the label always carries the meaning.
class DoorstepStatusChip extends StatelessWidget {
  final String label;
  final DoorstepStatusTone tone;
  final bool pulse;
  final IconData? icon;

  const DoorstepStatusChip({
    required this.label,
    this.tone = DoorstepStatusTone.neutral,
    this.pulse = false,
    this.icon,
    super.key,
  });

  Color _color(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    switch (tone) {
      case DoorstepStatusTone.positive:
        return isDark ? DoorstepTheme.success : const Color(0xFF15803D);
      case DoorstepStatusTone.neutral:
        return isDark ? DoorstepTheme.primary : const Color(0xFF0F60FF);
      case DoorstepStatusTone.warning:
        return isDark ? DoorstepTheme.warning : const Color(0xFFA16207);
      case DoorstepStatusTone.negative:
        return isDark ? DoorstepTheme.danger : const Color(0xFFB91C1C);
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _color(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: color.withValues(alpha: 0.28), width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 6),
          ] else ...[
            _StatusDot(color: color, pulse: pulse),
            const SizedBox(width: 7),
          ],
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.1,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusDot extends StatefulWidget {
  final Color color;
  final bool pulse;

  const _StatusDot({required this.color, required this.pulse});

  @override
  State<_StatusDot> createState() => _StatusDotState();
}

class _StatusDotState extends State<_StatusDot> with SingleTickerProviderStateMixin {
  AnimationController? _controller;

  @override
  void initState() {
    super.initState();
    if (widget.pulse) {
      final controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600));
      _controller = controller;
      unawaited(controller.repeat(reverse: true));
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dot = Container(
      width: 7,
      height: 7,
      decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle),
    );

    if (_controller == null) return dot;

    return AnimatedBuilder(
      animation: _controller!,
      builder: (context, _) => Opacity(opacity: 0.45 + (_controller!.value * 0.55), child: dot),
    );
  }
}
