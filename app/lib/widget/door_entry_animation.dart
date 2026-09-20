import 'dart:async';

import 'package:doorstep_app/config/doorstep_theme.dart';
import 'package:doorstep_app/model/persistence/receive_history_entry.dart';
import 'package:doorstep_isolates/model/file_type.dart';
import 'package:doorstep_isolates/util/file_size_helper.dart';
import 'package:flutter/material.dart';

/// The "something just arrived" moment, shown once in the Activity tab.
///
/// Deliberately quiet: one card, one mark, one soft pulse, then it gets out of
/// the way. The previous version swung doors, flew paper in and burst sparkles —
/// fun once, noise on the tenth transfer. This one reads at a glance and never
/// blocks: tapping it settles it immediately, and it dismisses itself anyway.
class DoorEntryAnimation extends StatefulWidget {
  final ReceiveHistoryEntry entry;
  final VoidCallback onDone;

  const DoorEntryAnimation({required this.entry, required this.onDone, super.key});

  @override
  State<DoorEntryAnimation> createState() => _DoorEntryAnimationState();
}

class _DoorEntryAnimationState extends State<DoorEntryAnimation> with SingleTickerProviderStateMixin {
  static const _total = Duration(milliseconds: 1500);
  static const _visibleFor = Duration(milliseconds: 2200);

  late final AnimationController _controller;
  late final Animation<double> _mark;
  late final Animation<double> _pulse;
  late final Animation<double> _text;

  Timer? _doneTimer;
  bool _finished = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: _total);
    _mark = CurvedAnimation(parent: _controller, curve: const Interval(0.0, 0.45, curve: Curves.easeOutBack));
    _pulse = CurvedAnimation(parent: _controller, curve: const Interval(0.05, 0.85, curve: Curves.easeOutCubic));
    _text = CurvedAnimation(parent: _controller, curve: const Interval(0.3, 0.75, curve: Curves.easeOut));
    unawaited(_controller.forward());
    _doneTimer = Timer(_visibleFor, _finish);
  }

  @override
  void dispose() {
    _doneTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  /// One-shot: whatever triggers it first (the timer, or a tap) settles the card.
  void _finish() {
    if (_finished) return;
    _finished = true;
    _doneTimer?.cancel();
    widget.onDone();
  }

  @override
  Widget build(BuildContext context) {
    final entry = widget.entry;
    final primary = DoorstepTheme.primaryOf(context);
    final isNote = entry.isMessage;

    return Semantics(
      liveRegion: true,
      label: isNote
          ? 'Note received from ${entry.senderAlias}'
          : '${entry.fileName} received from ${entry.senderAlias}',
      child: GestureDetector(
        onTap: _finish,
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
          decoration: BoxDecoration(
            color: DoorstepTheme.surfaceOf(context),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: primary.withValues(alpha: 0.18)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _Mark(
                mark: _mark,
                pulse: _pulse,
                primary: primary,
                icon: _iconFor(entry, isNote),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: FadeTransition(
                  opacity: _text,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        isNote ? 'New note' : 'File received',
                        style: TextStyle(
                          color: primary,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.4,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        isNote ? entry.fileName : entry.fileName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: DoorstepTheme.textMainOf(context),
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.3,
                          height: 1.25,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        isNote
                            ? 'From ${entry.senderAlias}'
                            : 'From ${entry.senderAlias} · ${entry.fileSize.asReadableFileSize}',
                        style: TextStyle(color: DoorstepTheme.textMutedOf(context), fontSize: 12.5),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _iconFor(ReceiveHistoryEntry entry, bool isNote) {
    if (isNote) return Icons.sticky_note_2_rounded;
    switch (entry.fileType) {
      case FileType.text:
        return Icons.description_rounded;
      case FileType.image:
        return Icons.image_rounded;
      case FileType.video:
        return Icons.movie_rounded;
      case FileType.apk:
        return Icons.android_rounded;
      default:
        return Icons.insert_drive_file_rounded;
    }
  }
}

/// The arrival mark: a soft badge that springs in behind two expanding rings.
///
/// Two rings is the whole trick — it reads as "something landed here" without
/// anything moving across the screen, so nothing competes with the file name.
class _Mark extends StatelessWidget {
  final Animation<double> mark;
  final Animation<double> pulse;
  final Color primary;
  final IconData icon;

  const _Mark({required this.mark, required this.pulse, required this.primary, required this.icon});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 74,
      height: 74,
      child: AnimatedBuilder(
        animation: Listenable.merge([mark, pulse]),
        builder: (context, child) {
          return Stack(
            alignment: Alignment.center,
            children: [
              CustomPaint(
                size: const Size.square(74),
                painter: _PulsePainter(t: pulse.value, color: primary),
              ),
              Transform.scale(
                scale: 0.6 + 0.4 * mark.value.clamp(0.0, 1.0),
                child: Opacity(opacity: mark.value.clamp(0.0, 1.0), child: child),
              ),
            ],
          );
        },
        child: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: primary.withValues(alpha: 0.14),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: primary, size: 24),
        ),
      ),
    );
  }
}

class _PulsePainter extends CustomPainter {
  /// 0 → 1 over the life of the animation.
  final double t;
  final Color color;

  const _PulsePainter({required this.t, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (t <= 0) return;
    final center = size.center(Offset.zero);
    final maxRadius = size.shortestSide / 2;

    // Two rings, the second trailing slightly, so the pulse reads as a wave.
    for (final offset in const [0.0, 0.22]) {
      final local = (t - offset) / (1 - offset);
      if (local <= 0) continue;
      final eased = local.clamp(0.0, 1.0);
      final radius = maxRadius * (0.42 + 0.58 * eased);
      final opacity = (1 - eased) * 0.45;
      if (opacity <= 0.01) continue;
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = color.withValues(alpha: opacity),
      );
    }
  }

  @override
  bool shouldRepaint(_PulsePainter oldDelegate) => oldDelegate.t != t || oldDelegate.color != color;
}
