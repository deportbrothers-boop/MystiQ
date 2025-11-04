import 'dart:async';
import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../core/i18n/app_localizations.dart';

class ScanningOverlay extends StatefulWidget {
  final Duration duration;
  final VoidCallback onDone;
  const ScanningOverlay({super.key, required this.onDone, this.duration = const Duration(seconds: 2)});

  @override
  State<ScanningOverlay> createState() => _ScanningOverlayState();
}

class _ScanningOverlayState extends State<ScanningOverlay> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat(reverse: true);

  @override
  void initState() {
    super.initState();
    Timer(widget.duration, () {
      if (mounted) widget.onDone();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withValues(alpha: 0.6),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ScaleTransition(
              scale: Tween(begin: 0.9, end: 1.1).animate(CurvedAnimation(parent: _c, curve: Curves.easeInOut)),
              child: const Icon(Icons.auto_awesome, color: AppTheme.gold, size: 48),
            ),
            const SizedBox(height: 16),
            Builder(builder: (ctx) => Text(
              AppLocalizations.of(ctx).t('ai.scanning') != 'ai.scanning'
                  ? AppLocalizations.of(ctx).t('ai.scanning')
                  : 'AI analiz ediliyor...',
              style: const TextStyle(color: AppTheme.gold),
            )),
            const SizedBox(height: 12),
            const SizedBox(
              width: 220,
              child: LinearProgressIndicator(
                backgroundColor: Colors.white12,
                valueColor: AlwaysStoppedAnimation<Color>(AppTheme.gold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }
}
