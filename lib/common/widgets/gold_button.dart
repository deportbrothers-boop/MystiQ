import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

class GoldButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final EdgeInsets padding;
  const GoldButton({super.key, required this.text, this.onPressed, this.padding = const EdgeInsets.symmetric(horizontal: 20, vertical: 12)});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(32),
      child: Ink(
        padding: padding,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppTheme.gold, AppTheme.goldBright],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(32),
          boxShadow: [
            BoxShadow(color: AppTheme.gold.withValues(alpha: 0.35), blurRadius: 14, spreadRadius: 1),
          ],
        ),
        child: Text(
          text,
          style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w700),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
