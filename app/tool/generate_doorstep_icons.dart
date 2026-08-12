// Generates every Doorstep app icon from `assets/doorstep/logo.png`.
//
// Run from `app/`:
//   ../.fvm/flutter_sdk/bin/dart run tool/generate_doorstep_icons.dart
//
// The logo is a full-bleed navy badge with a white waveform glyph. Icons that
// need a standalone mark (adaptive monochrome, quick tile, macOS menu bar,
// Linux tray) are cut from the glyph; everything else keeps the full logo.
//
// Covers: Android mipmaps (legacy + adaptive foreground + monochrome + quick
// tile + TV banner), Windows app_icon.ico, web PWA icons + favicon, the
// bundled tray icons, and the iOS/macOS AppIcon asset catalogs (parsed from
// their Contents.json).
// ignore_for_file: avoid_print
import 'dart:convert';
import 'dart:io';

import 'package:image/image.dart' as img;

const logoPath = 'assets/doorstep/logo.png';

bool _isWhite(img.Pixel p) => p.r > 200 && p.g > 200 && p.b > 200;

void main() {
  final logo = img.decodeImage(File(logoPath).readAsBytesSync())!;
  final w = logo.width;
  final h = logo.height;

  // The white glyph = near-white pixels that are NOT connected to a corner
  // (the corner whites are just the rounded-corner gaps of the badge).
  final corner = List.generate(h, (_) => List.filled(w, false));
  final stack = <(int, int)>[(0, 0), (w - 1, 0), (0, h - 1), (w - 1, h - 1)];
  for (final (x, y) in stack) {
    corner[y][x] = true;
  }
  while (stack.isNotEmpty) {
    final (x, y) = stack.removeLast();
    for (final (dx, dy) in [(1, 0), (-1, 0), (0, 1), (0, -1)]) {
      final nx = x + dx, ny = y + dy;
      if (nx < 0 || ny < 0 || nx >= w || ny >= h || corner[ny][nx]) continue;
      if (_isWhite(logo.getPixel(nx, ny))) {
        corner[ny][nx] = true;
        stack.add((nx, ny));
      }
    }
  }
  var minX = w, minY = h, maxX = -1, maxY = -1;
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      if (_isWhite(logo.getPixel(x, y)) && !corner[y][x]) {
        if (x < minX) minX = x;
        if (x > maxX) maxX = x;
        if (y < minY) minY = y;
        if (y > maxY) maxY = y;
      }
    }
  }
  // Fit the glyph inside the adaptive 66/108 safe zone (monochrome + tiles).
  final glyphW = maxX - minX + 1;
  final glyphH = maxY - minY + 1;
  print('logo: ${w}x$h, glyph bbox: x=$minX..$maxX y=$minY..$maxY ($glyphW x $glyphH)');

  // ── Android ──────────────────────────────────────────────────────────────
  const androidDensities = {
    'mipmap-mdpi': 1,
    'mipmap-hdpi': 1.5,
    'mipmap-xhdpi': 2,
    'mipmap-xxhdpi': 3,
    'mipmap-xxxhdpi': 4,
  };
  for (final entry in androidDensities.entries) {
    final base = entry.key;
    final scale = entry.value;
    // Legacy launcher icon (pre-API-26): 48dp full logo.
    _writePng('android/app/src/main/res/$base/ic_launcher.png', _resize(logo, (48 * scale).round()));
    // Adaptive foreground: the full logo on the (white) background layer.
    _writePng('android/app/src/main/res/$base/ic_launcher_foreground.png', _resize(logo, (108 * scale).round()));
    // Quick-settings tile: white glyph on transparency (tile bg is dark).
    _writePng(
      'android/app/src/main/res/$base/ic_launcher_quicktile_foreground.png',
      _glyphImage(logo, (108 * scale).round(), minX, minY, glyphW, glyphH, white: true),
    );
    // Monochrome (themed icons): black glyph on transparency.
    _writePng(
      'android/app/src/main/res/$base/ic_launcher_monochrome.png',
      _glyphImage(logo, (108 * scale).round(), minX, minY, glyphW, glyphH, white: false),
    );
  }
  // TV banner (320x180).
  final banner = img.Image(width: 320, height: 180);
  img.fill(banner, color: img.ColorRgb8(255, 255, 255));
  final bannerLogo = img.copyResize(logo, height: 150, interpolation: img.Interpolation.cubic);
  img.compositeImage(banner, bannerLogo, dstX: (320 - bannerLogo.width) ~/ 2, dstY: (180 - bannerLogo.height) ~/ 2);
  _writePng('android/app/src/main/res/drawable/banner.png', banner);

  // ── Windows .ico ─────────────────────────────────────────────────────────
  File('windows/runner/resources/app_icon.ico').writeAsBytesSync(img.encodeIco(_resize(logo, 256)));
  print('wrote windows/runner/resources/app_icon.ico');

  // ── Web (PWA + favicon) ──────────────────────────────────────────────────
  _writePng('web/icons/Icon-192.png', _resize(logo, 192));
  _writePng('web/icons/Icon-512.png', _resize(logo, 512));
  _writePng('web/icons/Icon-maskable-192.png', _maskable(logo, 192));
  _writePng('web/icons/Icon-maskable-512.png', _maskable(logo, 512));
  _writePng('web/favicon.png', _resize(logo, 64));

  // ── Bundled tray icons (filenames the tray code references) ──────────────
  _writePng('assets/img/logo-32.png', _resize(logo, 32));
  _writePng('assets/img/logo-32-white.png', _glyphImage(logo, 32, minX, minY, glyphW, glyphH, white: true));
  File('assets/img/logo.ico').writeAsBytesSync(img.encodeIco(_resize(logo, 256)));
  print('wrote assets/img/logo.ico');

  // ── macOS status bar template icon (glyph shape, black) ──────────────────
  _writePng(
    'macos/Runner/Assets.xcassets/StatusBarItemIcon.imageset/logo-32-black.png',
    _glyphImage(logo, 32, minX, minY, glyphW, glyphH, white: false),
  );

  // ── iOS + macOS AppIcon asset catalogs ───────────────────────────────────
  _fromContentsJson('ios/Runner/Assets.xcassets/AppIcon.appiconset/Contents.json', logo);
  _fromContentsJson('macos/Runner/Assets.xcassets/AppIcon.appiconset/Contents.json', logo);

  print('All icons generated.');
}

img.Image _resize(img.Image logo, int size) => img.copyResize(logo, width: size, height: size, interpolation: img.Interpolation.cubic);

/// Full-bleed icon (the logo already carries its own background).
img.Image _icon(img.Image logo, int size) => _resize(logo, size);

/// Maskable PWA icon: logo scaled to 80% on white, so safe-zone cropping
/// never clips the badge.
img.Image _maskable(img.Image logo, int size) {
  final canvas = img.Image(width: size, height: size);
  img.fill(canvas, color: img.ColorRgb8(255, 255, 255));
  final scaled = img.copyResize(logo, width: (size * 0.8).round(), height: (size * 0.8).round(), interpolation: img.Interpolation.cubic);
  img.compositeImage(canvas, scaled, dstX: (size - scaled.width) ~/ 2, dstY: (size - scaled.height) ~/ 2);
  return canvas;
}

/// The white waveform glyph alone on transparency, scaled so its longer side
/// fills the adaptive safe zone (66dp of the 108dp canvas). [white] picks
/// white or black pixels.
img.Image _glyphImage(img.Image logo, int size, int minX, int minY, int glyphW, int glyphH, {required bool white}) {
  final safe = size * 66.0 / 108.0;
  final targetW = glyphW > glyphH ? safe.round() : (glyphW / glyphH * safe).round();
  final targetH = glyphH > glyphW ? safe.round() : (glyphH / glyphW * safe).round();
  final crop = img.copyCrop(logo, x: minX, y: minY, width: glyphW, height: glyphH);
  final scaled = img.copyResize(crop, width: targetW, height: targetH, interpolation: img.Interpolation.cubic);
  final canvas = img.Image(width: size, height: size, numChannels: 4);
  final fg = white ? 255 : 0;
  final dx = (size - scaled.width) ~/ 2;
  final dy = (size - scaled.height) ~/ 2;
  for (var y = 0; y < scaled.height; y++) {
    for (var x = 0; x < scaled.width; x++) {
      final p = scaled.getPixel(x, y);
      // Anti-aliased edge: alpha ramps from the near-white threshold to full.
      final lum = (p.r.toInt() + p.g.toInt() + p.b.toInt()) / 3;
      final a = ((lum - 200) * 255 / 55).round().clamp(0, 255);
      if (a > 0) {
        canvas.setPixelRgba(x + dx, y + dy, fg, fg, fg, a);
      }
    }
  }
  return canvas;
}

/// Generates every image referenced by an AppIcon `Contents.json`.
void _fromContentsJson(String contentsPath, img.Image logo) {
  final dir = File(contentsPath).parent.path;
  final json = jsonDecode(File(contentsPath).readAsStringSync()) as Map<String, dynamic>;
  for (final entry in (json['images'] as List).cast<Map<String, dynamic>>()) {
    final filename = entry['filename'] as String?;
    if (filename == null) continue;
    // Sizes can be fractional on iOS (e.g. "83.5x83.5").
    final size = double.parse((entry['size'] as String).split('x').first);
    final scale = double.parse(((entry['scale'] as String?) ?? '1x').replaceAll('x', ''));
    _writePng('$dir/$filename', _icon(logo, (size * scale).round()));
  }
}

void _writePng(String path, img.Image image) {
  File(path).writeAsBytesSync(img.encodePng(image));
  print('wrote $path (${image.width}x${image.height})');
}
