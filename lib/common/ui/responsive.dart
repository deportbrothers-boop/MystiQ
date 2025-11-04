import 'package:flutter/widgets.dart';

class R {
  // Base iPhone 11 width baseline: 375
  static double scale(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final minSide = size.shortestSide;
    final s = minSide / 375.0;
    if (s < 0.85) return 0.85;
    if (s > 1.25) return 1.25;
    return s;
  }
}

