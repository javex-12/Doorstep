import 'package:flutter/material.dart';
import 'package:localsend_app/gen/assets.gen.dart';

/// The Doorstep brand logo — the bundled `assets/doorstep/logo.png` instead of
/// the upstream LocalSend mark, shown with its original colors.
class DoorstepLogo extends StatelessWidget {
  final bool withText;

  const DoorstepLogo({required this.withText});

  @override
  Widget build(BuildContext context) {
    final logo = Assets.doorstep.logo.image(width: 200);

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
