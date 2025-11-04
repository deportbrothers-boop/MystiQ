import 'package:flutter/material.dart';
import 'sharp_image.dart';

class MystiqBackground extends StatelessWidget {
  final Widget child;
  const MystiqBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: Stack(
        children: [
        const Positioned.fill(
          child: SharpAssetFallback(
            'assets/images/bg/coffee_premium_bg.png',
            fit: BoxFit.cover,
            alignment: Alignment.center,
            filterQuality: FilterQuality.high,
          ),
        ),
        child,
      ],
    ));
  }
}
