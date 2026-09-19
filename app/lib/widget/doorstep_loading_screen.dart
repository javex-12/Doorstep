import 'dart:async';

import 'package:doorstep_app/config/doorstep_theme.dart';
import 'package:doorstep_app/model/state/doorstep_transfer_state.dart';
import 'package:doorstep_app/provider/doorstep_transfer_provider.dart';
import 'package:doorstep_app/provider/network/send_provider.dart';
import 'package:doorstep_app/provider/network/server/server_provider.dart';
import 'package:doorstep_app/util/ui/progress_route.dart';
import 'package:doorstep_app/widget/doorstep_card.dart';
import 'package:doorstep_app/widget/doorstep_logo.dart';
import 'package:doorstep_isolates/model/session_status.dart';
import 'package:flutter/material.dart';
import 'package:refena_flutter/refena_flutter.dart';

/// The one and only in-app progress surface: a compact banner that slides in
/// at the bottom while a transfer runs.
///
/// It is deliberately *not* a full-screen takeover — a transfer should never
/// block you from using Doorstep — and it shows **once per session**, not once
/// per file. If the user opens the detailed progress screen, the banner steps
/// aside so the two never stack.
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
              child: _ProgressCard(
                doorstep: doorstep,
                onMinimize: () => setState(() => _dismissed = true),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ProgressCard extends StatelessWidget {
  final List<DoorstepTransferState> doorstep;
  final VoidCallback onMinimize;

  const _ProgressCard({required this.doorstep, required this.onMinimize});

  @override
  Widget build(BuildContext context) {
    final hasDoorstep = doorstep.isNotEmpty;
    final progress = hasDoorstep ? (doorstep.map((t) => t.progress).reduce((a, b) => a + b) / doorstep.length).clamp(0.0, 1.0) : 0.5;
    final current = hasDoorstep ? doorstep.first : null;
    final percent = (progress * 100).toInt();

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 480),
      child: DoorstepCard(
        borderColor: DoorstepTheme.borderOf(context),
        backgroundColor: DoorstepTheme.surfaceOf(context),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: Doorstep Emblem + Transfer Direction
            Row(
              children: [
                const DoorstepLogo(withText: false, size: 36),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        hasDoorstep ? 'Sending to ${current!.targetDevice}' : 'Transfer in Progress',
                        style: TextStyle(
                          color: DoorstepTheme.textMainOf(context),
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Doorstep Network · Direct Peer Link',
                        style: TextStyle(
                          color: DoorstepTheme.primaryOf(context),
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: DoorstepTheme.primaryOf(context).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: Text(
                    '$percent%',
                    style: TextStyle(
                      color: DoorstepTheme.primaryOf(context),
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Current File Name
            Text(
              hasDoorstep ? current!.fileName : 'Moving files between devices…',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: DoorstepTheme.textMainOf(context),
                fontSize: 14.5,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 10),

            // Linear Progress Bar
            ClipRRect(
              borderRadius: BorderRadius.circular(100),
              child: LinearProgressIndicator(
                value: progress > 0 ? progress : null,
                minHeight: 8,
                backgroundColor: DoorstepTheme.borderOf(context),
                color: DoorstepTheme.primaryOf(context),
              ),
            ),
            const SizedBox(height: 12),

            // Subtitle info row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  hasDoorstep && doorstep.length > 1 ? '${doorstep.length} items remaining' : 'High-speed local transfer',
                  style: TextStyle(color: DoorstepTheme.textMutedOf(context), fontSize: 12),
                ),
                Text(
                  'Encrypted & Direct',
                  style: TextStyle(color: DoorstepTheme.textMutedOf(context), fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Actions: keep it out of the way without stopping the transfer.
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onMinimize,
                icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 20),
                label: const Text('Hide'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
