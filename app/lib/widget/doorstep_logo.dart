import 'package:doorstep_app/gen/assets.gen.dart';
import 'package:flutter/material.dart';

/// The Doorstep brand logo — the bundled `assets/doorstep/logo.png` instead of
/// the upstream LocalSend mark, shown with its original colors.
class DoorstepLogo extends StatelessWidget {
  final bool withText;
  final double? size;

  const DoorstepLogo({required this.withText, this.size});

  @override
  Widget build(BuildContext context) {
    final logo = Assets.doorstep.logo.image(width: size ?? 200);

    if (withText) {
      return Column(
        children: [
          logo,
          const Text(
            'Doorstep',
            style: TextStyle(fontSize: 36, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
        ],
      );
    } else {
      return logo;
    }
  }
}
