// One-off: regenerate assets/img logo variants from the current
// assets/doorstep/logo.png. Run from app/:
//   dart run tool/regenerate_img_logos.dart
//
// ignore_for_file: avoid_print
import 'dart:io';

import 'package:image/image.dart' as img;

void main() {
  final logo = img.decodePng(File('assets/doorstep/logo.png').readAsBytesSync());
  print('logo: ${logo!.width}x${logo.height}');

  for (final size in [32, 128, 256, 512]) {
    final resized = img.copyResize(logo, width: size, height: size, interpolation: img.Interpolation.cubic);
    File('assets/img/logo-$size.png').writeAsBytesSync(img.encodePng(resized));
    print('wrote assets/img/logo-$size.png');
  }

  // White variants for dark surfaces.
  for (final size in [32, 512]) {
    final resized = img.copyResize(logo, width: size, height: size, interpolation: img.Interpolation.cubic);
    final white = resized.clone();
    // Invert RGB, keep alpha: turns the navy badge white-ish for dark surfaces.
    for (final p in white) {
      p.r = 255 - p.r;
      p.g = 255 - p.g;
      p.b = 255 - p.b;
    }
    File('assets/img/logo-$size-white.png').writeAsBytesSync(img.encodePng(white));
    print('wrote assets/img/logo-$size-white.png');
  }

  File('assets/img/logo-32-black.png').writeAsBytesSync(
    img.encodePng(img.copyResize(logo, width: 32, height: 32, interpolation: img.Interpolation.cubic)),
  );
  print('done');
}
