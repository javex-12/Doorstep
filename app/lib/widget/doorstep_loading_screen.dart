import 'dart:async';
import 'dart:math' as math;

import 'package:doorstep_app/config/doorstep_theme.dart';
import 'package:doorstep_app/model/state/doorstep_transfer_state.dart';
import 'package:doorstep_app/pages/progress_page.dart';
import 'package:doorstep_app/provider/doorstep_transfer_provider.dart';
import 'package:doorstep_app/provider/network/send_provider.dart';
import 'package:doorstep_app/provider/network/server/server_provider.dart';
import 'package:doorstep_app/util/ui/progress_route.dart';
import 'package:doorstep_isolates/model/session_status.dart';
import 'package:flutter/material.dart';
import 'package:refena_flutter/refena_flutter.dart';
import 'package:routerino/routerino.dart';

/// The one and only in-app progress surface: a slim banner that rises from the
/// bottom while a transfer runs.
///
/// Design rules this follows:
///  - **Never a takeover.** A transfer must not stop you using Doorstep.
///  - **Once per session**, not once per file. The previous version refreshed on
///    every file and read as a flashing overlay.
///  - **Two lines, one bar.** Anything more competes with the file name.
///  - **No internals.** The user is told *what* is happening, never which
///    transport is doing it.
///  - If the detailed screen is open, this steps aside so the two never stack.
class DoorstepTransferOverlay extends StatefulWidget {
  const DoorstepTransferOverlay({super.key});

  @override
  State<DoorstepTransferOverlay> createState() => _DoorstepTransferOverlayState();
}

const _idleResetAfter = Duration(seconds: 3);

class _DoorstepTransferOverlayState extends State<DoorstepTransferOverlay> with Refena {
  bool _dismissed = false;
  Timer? _idleTimer;

  @override
  void dispose() {
    _idleTimer?.cancel();
    super.dispose();
  }

  List<DoorstepTransferState> get _activeDoorstep {
    return ref.watch(
      doorstepTransferProvider.select(
        (list) => list.where((t) => t.status == DoorstepTransferStatus.pending || t.status == DoorstepTransferStatus.transferring).toList(),
      ),
    );
  }

  bool get _hasLegacyTransfer {
    final sending = ref.watch(sendProvider.select((sessions) => sessions.values.any((s) => s.status == SessionStatus.sending)));
    final receiving = ref.watch(serverProvider.select((s) => s?.session?.status)) == SessionStatus.sending;
    return sending || receiving;
  }

  /// The detailed screen needs a session id. Prefer the outbound session, then
  /// the inbound one — the same order the two providers are consulted in.
  String? get _activeSessionId {
    final sending = ref.watch(
      sendProvider.select((sessions) => sessions.values.where((s) => s.status == SessionStatus.sending).map((s) => s.sessionId).toList()),
    );
    if (sending.isNotEmpty) return sending.first;
    return ref.watch(serverProvider.select((s) => s?.session?.status == SessionStatus.sending ? s?.session?.sessionId : null));
  }

  void _openDetails() {
    final sessionId = _activeSessionId;
    if (sessionId == null) return;
    // Same navigation the rest of the app uses for this screen, so the
    // "stepped aside" bookkeeping in ProgressPage stays correct.
    // ignore: discarded_futures
    Routerino.context.pushImmediately(
      () => ProgressPage(showAppBar: true, closeSessionOnClose: false, sessionId: sessionId),
    );
  }

  @override
  Widget build(BuildContext context) {
    final doorstep = _activeDoorstep;
    final active = doorstep.isNotEmpty || _hasLegacyTransfer;

    if (!active) {
      _idleTimer ??= Timer(_idleResetAfter, () {
        if (mounted) setState(() => _dismissed = false);
      });
      return const SizedBox.shrink();
    }

    _idleTimer?.cancel();
    _idleTimer = null;

    return ValueListenableBuilder<int>(
      valueListenable: progressScreenDepth,
      builder: (context, detailedOpen, _) {
        // The detailed progress screen is the surface while it is open.
        if (detailedOpen > 0 || _dismissed) {
          return const SizedBox.shrink();
        }

        return Align(
          alignment: Alignment.bottomCenter,
          child: SafeArea(
            minimum: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Material(
              type: MaterialType.transparency,
              child: _TransferPill(
                doorstep: doorstep,
                canOpenDetails: _activeSessionId != null,
                onOpenDetails: _openDetails,
                onDismiss: () => setState(() => _dismissed = true),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// The banner itself: a ring, two lines, a hairline bar.
class _TransferPill extends StatelessWidget {
  final List<DoorstepTransferState> doorstep;
  final bool canOpenDetails;
  final VoidCallback onOpenDetails;
  final VoidCallback onDismiss;

  const _TransferPill({
    required this.doorstep,
    required this.canOpenDetails,
    required this.onOpenDetails,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final hasDoorstep = doorstep.isNotEmpty;
    final progress = hasDoorstep ? (doorstep.map((t) => t.progress).reduce((a, b) => a + b) / doorstep.length).clamp(0.0, 1.0) : null;
    final current = hasDoorstep ? doorstep.first : null;
    final primary = DoorstepTheme.primaryOf(context);

    final title = hasDoorstep ? 'Sending to ${current!.targetDevice}' : 'Transferring';

    // One file reads as its own name; several read as a count. Both fit on one
    // line, and neither mentions a transport.
    final detail = hasDoorstep
        ? (doorstep.length == 1 ? current!.fileName : '${doorstep.length} files')
        : 'Please keep Doorstep open';

    final percent = progress == null ? null : (progress * 100).round();

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 440),
      child: Container(
        decoration: BoxDecoration(
          color: DoorstepTheme.surfaceOf(context),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: DoorstepTheme.borderOf(context)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.22),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        padding: const EdgeInsets.fromLTRB(16, 13, 8, 13),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                SizedBox(
                  width: 26,
                  height: 26,
                  child: CustomPaint(
                    painter: _RingPainter(progress: progress, color: primary, track: DoorstepTheme.borderOf(context)),
                  ),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: DoorstepTheme.textMainOf(context),
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        detail,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: DoorstepTheme.textMutedOf(context), fontSize: 12),
                      ),
                    ],
                  ),
                ),
                if (percent != null)
                  Padding(
                    padding: const EdgeInsets.only(left: 6),
                    child: Text(
                      '$percent%',
                      style: TextStyle(color: primary, fontSize: 12.5, fontWeight: FontWeight.w800),
                    ),
                  ),
                if (canOpenDetails)
                  _PillAction(
                    icon: Icons.unfold_more_rounded,
                    tooltip: 'Show each file',
                    onPressed: onOpenDetails,
                  ),
                _PillAction(
                  icon: Icons.close_rounded,
                  tooltip: 'Hide',
                  onPressed: onDismiss,
                ),
              ],
            ),
            const SizedBox(height: 11),
            // Hairline progress: present, readable, never the loudest thing.
            ClipRRect(
              borderRadius: BorderRadius.circular(100),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 3,
                backgroundColor: DoorstepTheme.borderOf(context).withValues(alpha: 0.6),
                color: primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PillAction extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  const _PillAction({required this.icon, required this.tooltip, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed,
      tooltip: tooltip,
      visualDensity: VisualDensity.compact,
      padding: const EdgeInsets.all(6),
      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
      icon: Icon(icon, size: 17, color: DoorstepTheme.textMutedOf(context)),
    );
  }
}

/// A determinate ring. Reads faster than a bar at this size because the eye
/// gets the fraction from the arc itself, not from a length.
class _RingPainter extends CustomPainter {
  final double? progress;
  final Color color;
  final Color track;

  const _RingPainter({required this.progress, required this.color, required this.track});

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2 - 2;
    final base = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round
      ..color = track;

    canvas.drawCircle(center, radius, base);

    if (progress == null) {
      // Unknown total: a single quarter arc sweeping, so it still reads as
      // "working" without pretending to know the fraction.
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2,
        math.pi / 2,
        false,
        base..color = color,
      );
      return;
    }

    if (progress! <= 0) return;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      math.pi * 2 * progress!.clamp(0.0, 1.0),
      false,
      base..color = color,
    );
  }

  @override
  bool shouldRepaint(_RingPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.color != color || oldDelegate.track != track;
}
