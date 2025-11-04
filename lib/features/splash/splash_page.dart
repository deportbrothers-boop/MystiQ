import 'dart:async';
import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../common/widgets/sharp_image.dart';
import 'package:go_router/go_router.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    // Navigate after first frame to avoid doing work during build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Primary navigation after a very short display
      Future.delayed(const Duration(milliseconds: 900), () {
        if (!mounted || _navigated) return;
        _navigated = true;
        context.go('/onboarding');
      });
      // Safety fallback (if something blocks the first navigation)
      Future.delayed(const Duration(milliseconds: 2500), () {
        if (!mounted || _navigated) return;
        _navigated = true;
        context.go('/home');
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Solid gradient background to avoid blank/purple screen
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF0B0A0E), Color(0xFF121018)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
          // Branded image with webp→png fallback
          const Align(
            alignment: Alignment(0, -0.1),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 24.0),
              child: SharpAssetFallback('assets/splash/brand.png', fit: BoxFit.contain),
            ),
          ),
          const Center(child: _Stars()),
        ],
      ),
    );
  }
}

class _Stars extends StatefulWidget {
  const _Stars();

  @override
  State<_Stars> createState() => _StarsState();
}

class _StarsState extends State<_Stars> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(seconds: 2))
        ..repeat(reverse: true);
  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween(begin: 0.4, end: 1.0).animate(CurvedAnimation(
        parent: _c,
        curve: Curves.easeInOut,
      )),
      child: const Icon(Icons.auto_awesome, color: AppTheme.gold, size: 24),
    );
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }
}
