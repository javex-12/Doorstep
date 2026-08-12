import 'dart:async';

import 'package:flutter/material.dart';
import 'package:localsend_app/config/doorstep_theme.dart';
import 'package:localsend_app/gen/assets.gen.dart';
import 'package:localsend_app/model/state/doorstep_transfer_state.dart';
import 'package:localsend_app/provider/doorstep_transfer_provider.dart';
import 'package:localsend_app/provider/network/send_provider.dart';
import 'package:localsend_app/provider/network/server/server_provider.dart';
import 'package:localsend_app/widget/doorstep_logo.dart';
import 'package:localsend_isolates/model/session_status.dart';
import 'package:refena_flutter/refena_flutter.dart';
import 'package:video_player/video_player.dart';

/// Full-screen loading screen shown while files are transferring.
///
/// Plays `assets/doorstep/loading.mp4` on top of the entire app (mounted via
/// `MaterialApp.builder`, so it covers every route). Renders nothing when no
/// transfer is active. A close button dismisses it for the current transfer;
/// it comes back for the next one.
class DoorstepTransferOverlay extends StatefulWidget {
  const DoorstepTransferOverlay({super.key});

  @override
  State<DoorstepTransferOverlay> createState() => _DoorstepTransferOverlayState();
}

class _DoorstepTransferOverlayState extends State<DoorstepTransferOverlay> with Refena {
  /// True while the user dismissed the overlay for the current transfer.
  /// Reset automatically once every transfer has finished, so the next
  /// transfer shows the screen again.
  bool _dismissed = false;

  bool get _hasActiveTransfer {
    // Narrow the watches to booleans so progress polls (every 300ms during a
    // Doorstep transfer) do not rebuild this overlay on every tick.
    final sending = ref.watch(sendProvider.select((sessions) => sessions.values.any((s) => s.status == SessionStatus.sending)));
    final receiving = ref.watch(serverProvider.select((s) => s?.session?.status)) == SessionStatus.sending;
    final doorstep = ref.watch(
      doorstepTransferProvider.select((list) => list.any((t) => t.status == DoorstepTransferStatus.transferring)),
    );
    return sending || receiving || doorstep;
  }

  @override
  Widget build(BuildContext context) {
    final active = _hasActiveTransfer;
    if (!active) {
      // All transfers finished — allow the next one to show the screen again.
      _dismissed = false;
      return const SizedBox.shrink();
    }
    if (_dismissed) {
      return const SizedBox.shrink();
    }

    return Material(
      type: MaterialType.transparency,
      child: Container(
        color: Colors.black,
        child: Stack(
          fit: StackFit.expand,
          children: [
            const _DoorstepLoadingVideo(),
            SafeArea(
              child: Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: IconButton(
                    tooltip: 'Dismiss',
                    onPressed: () => setState(() => _dismissed = true),
                    icon: const Icon(Icons.close, color: Colors.white),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Plays the bundled loading video in a loop. Shows a static fallback while
/// the video initializes and whenever playback is not possible.
class _DoorstepLoadingVideo extends StatefulWidget {
  const _DoorstepLoadingVideo();

  @override
  State<_DoorstepLoadingVideo> createState() => _DoorstepLoadingVideoState();
}

class _DoorstepLoadingVideoState extends State<_DoorstepLoadingVideo> {
  VideoPlayerController? _controller;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    unawaited(_init());
  }

  Future<void> _init() async {
    final controller = VideoPlayerController.asset(Assets.doorstep.loading);
    try {
      await controller.initialize();
      await controller.setLooping(true);
      await controller.setVolume(0);
      await controller.play();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() {
        _controller = controller;
        _ready = true;
      });
    } catch (_) {
      // Unsupported platform (no video_player implementation, e.g. Windows) or
      // unreadable asset — the fallback screen below is shown instead.
      await controller.dispose();
    }
  }

  @override
  void dispose() {
    unawaited(_controller?.dispose() ?? Future.value());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    if (_ready && controller != null && controller.value.isInitialized) {
      return FittedBox(
        fit: BoxFit.cover,
        clipBehavior: Clip.hardEdge,
        child: SizedBox(
          width: controller.value.size.width,
          height: controller.value.size.height,
          child: VideoPlayer(controller),
        ),
      );
    }
    return const _DoorstepLoadingFallback();
  }
}

/// Static loading screen shown when the video cannot play.
class _DoorstepLoadingFallback extends StatelessWidget {
  const _DoorstepLoadingFallback();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: DoorstepTheme.background,
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const DoorstepLogo(withText: false),
          const SizedBox(height: 28),
          const SizedBox(
            width: 34,
            height: 34,
            child: CircularProgressIndicator(strokeWidth: 3, color: DoorstepTheme.primary),
          ),
          const SizedBox(height: 18),
          const Text(
            'Doorstep',
            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
