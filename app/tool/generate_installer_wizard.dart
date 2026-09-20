// Generates the Inno Setup wizard artwork so the Windows installer looks like
// Doorstep instead of a stock Inno wizard.
//
// Inno Setup only accepts BMP, and its modern wizard style expects a portrait
// image on the welcome/finish pages plus a small image in the title bar. Both
// are composed here from assets/doorstep/logo.png on the brand background.
//
// Run from app/:
//   dart run tool/generate_installer_wizard.dart
//
// ignore_for_file: avoid_print
import 'dart:io';

import 'package:image/image.dart' as img;

/// The Doorstep brand background (#0B132B).
final _navy = img.ColorUint8.rgb(11, 19, 43);

void main() {
  final logoBytes = File('assets/doorstep/logo.png').readAsBytesSync();
  final logo = img.decodePng(logoBytes);
  if (logo == null) {
    print('Could not decode assets/doorstep/logo.png');
    exit(1);
  }
  print('logo: ${logo.width}x${logo.height}');

  _writeWizardImage(logo);
  _writeWizardSmallImage(logo);

  print('done');
}

/// 164x314 — the large image Inno shows beside the welcome and finish pages.
void _writeWizardImage(img.Image logo) {
  final canvas = img.Image(width: 164, height: 314);
  img.fill(canvas, color: _navy);

  final badge = img.copyResize(logo, width: 104, height: 104, interpolation: img.Interpolation.cubic);
  img.compositeImage(canvas, badge, dstX: 30, dstY: 72);

  img.drawString(
    canvas,
    'Doorstep',
    font: img.arial24,
    x: 30,
    y: 196,
    color: img.ColorUint8.rgb(255, 255, 255),
  );
  img.drawString(
    canvas,
    'Files find you',
    font: img.arial14,
    x: 30,
    y: 224,
    color: img.ColorUint8.rgb(124, 183, 255),
  );

  final out = File('assets/packaging/wizard.bmp');
  out.writeAsBytesSync(img.encodeBmp(canvas));
  print('wrote ${out.path} (${canvas.width}x${canvas.height})');
}

/// 55x55 — the small image Inno shows in the title bar of every page.
void _writeWizardSmallImage(img.Image logo) {
  final canvas = img.Image(width: 55, height: 55);
  img.fill(canvas, color: _navy);

  final badge = img.copyResize(logo, width: 41, height: 41, interpolation: img.Interpolation.cubic);
  img.compositeImage(canvas, badge, dstX: 7, dstY: 7);

  final out = File('assets/packaging/wizard-small.bmp');
  out.writeAsBytesSync(img.encodeBmp(canvas));
  print('wrote ${out.path} (${canvas.width}x${canvas.height})');
}
