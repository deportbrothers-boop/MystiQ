import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

class GoldGlow extends StatelessWidget {
  final Widget child;
  const GoldGlow({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: AppTheme.gold.withValues(alpha: 0.35),
            blurRadius: 18,
            spreadRadius: 1,
          ),
        ],
      ),
      child: child,
    );
  }
}
