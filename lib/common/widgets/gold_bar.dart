import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

/// A slim, rounded progress bar with gold fill. No tick markers.
class GoldBar extends StatelessWidget {
  final double value; // 0..1
  final double height;
  final int ticks; // kept for backward compat; ignored when 0
  final Color goldColor;
  const GoldBar({
    super.key,
    required this.value,
    this.height = 6,
    this.ticks = 0,
    this.goldColor = AppTheme.gold,
  });

  @override
  Widget build(BuildContext context) {
    final v = value.clamp(0.0, 1.0);
    return SizedBox(
      height: height,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(height),
        child: LayoutBuilder(
          builder: (context, c) {
            return Stack(
              fit: StackFit.expand,
              children: [
                // Track
                Container(color: Colors.white12),
                // Fill
                FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: v,
                  child: Container(color: goldColor),
                ),
                // No markers inside bar
              ],
            );
          },
        ),
      ),
    );
  }
}

// Tick painter removed intentionally to keep bars clean
