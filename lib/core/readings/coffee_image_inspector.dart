import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';

class CoffeeImageInspector {
  /// Heuristic: returns `true` if the image looks "too empty/too uniform"
  /// to contain meaningful coffee grounds patterns.
  ///
  /// This is intentionally conservative: if decoding fails, it returns `null`
  /// (don't block the user based on uncertainty).
  static Future<bool?> looksEmpty(String path) async {
    if (kIsWeb) return null;
    final p = path.trim();
    if (p.isEmpty) return null;
    return _looksEmptySingle(p);
  }

  /// Backwards-compatible helper.
  ///
  /// NOTE: Blocks only if **every decodable** image is empty (very permissive).
  /// Prefer calling [looksEmpty] per image when you want stricter behavior.
  static Future<bool> allImagesLookEmpty(Iterable<String> paths) async {
    if (kIsWeb) return false;
    final list = paths.where((p) => p.trim().isNotEmpty).toList();
    if (list.isEmpty) return false;

    var checked = 0;
    var emptyCount = 0;
    for (final p in list) {
      final r = await _looksEmptySingle(p);
      if (r == null) continue; // couldn't decode; don't treat as empty
      checked++;
      if (r) emptyCount++;
    }

    // If we could not decode any, don't block.
    if (checked == 0) return false;

    // Only block if every decodable image looks empty.
    return emptyCount == checked;
  }

  static Future<bool?> _looksEmptySingle(String path) async {
    try {
      final f = File(path);
      if (!await f.exists()) return null;
      final bytes = await f.readAsBytes();
      if (bytes.isEmpty) return null;

      // Downscale decode to keep it fast.
      final codec = await ui.instantiateImageCodec(bytes, targetWidth: 256);
      final frame = await codec.getNextFrame();
      final img = frame.image;
      final data = await img.toByteData(format: ui.ImageByteFormat.rawRgba);
      if (data == null) return null;
      final b = data.buffer.asUint8List();
      if (b.length < 4) return null;

      // Sample pixels (every Nth pixel) to estimate contrast/variance.
      final pixelCount = (b.length / 4).floor();
      final step = max(1, (pixelCount / 9000).floor()); // ~9k samples

      var n = 0;
      var sum = 0.0;
      var sumSq = 0.0;
      var dark = 0;
      var bright = 0;
      var mid = 0;

      for (var i = 0; i < pixelCount; i += step) {
        final idx = i * 4;
        final r = b[idx] / 255.0;
        final g = b[idx + 1] / 255.0;
        final bl = b[idx + 2] / 255.0;
        // Relative luminance
        final y = 0.2126 * r + 0.7152 * g + 0.0722 * bl;
        sum += y;
        sumSq += y * y;
        if (y < 0.22) dark++;
        if (y > 0.85) bright++;
        if (y >= 0.25 && y <= 0.60) mid++;
        n++;
      }
      if (n < 200) return null;

      final mean = sum / n;
      final variance = max(0.0, (sumSq / n) - (mean * mean));
      final std = sqrt(variance);
      final darkRatio = dark / n;
      final brightRatio = bright / n;
      final midRatio = mid / n;

      // "Empty" photos tend to be very uniform and either:
      // - uniformly bright (white ceramic), or
      // - uniformly dark (lens cap / dark surface), with almost no mid/dark texture.
      //
      // IMPORTANT: We keep this *strict* to avoid blocking low-quality but non-empty images.
      final veryUniform = std < 0.030;
      final almostNoTexture = midRatio < 0.12;

      final uniformBright =
          mean > 0.72 && brightRatio > 0.60 && darkRatio < 0.010 && almostNoTexture;
      final uniformDark =
          mean < 0.18 && darkRatio > 0.65 && brightRatio < 0.020 && midRatio < 0.06;

      return veryUniform && (uniformBright || uniformDark);
    } catch (_) {
      return null;
    }
  }
}
