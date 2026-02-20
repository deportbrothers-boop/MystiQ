import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
  static const String _kInfoAccepted = 'coffee_info_accepted';

  @override
  void initState() {
    super.initState();
    // Decide target route based on remember-me and current auth state
    WidgetsBinding.instance.addPostFrameCallback((_) => _decideRoute());
  }

  Future<void> _decideRoute() async {
    try {
      // small splash delay for visual consistency
      await Future.delayed(const Duration(milliseconds: 600));
      final prefs = await SharedPreferences.getInstance();
      final remember = prefs.getBool('remember_me') ?? false;
      final infoAccepted = prefs.getBool(_kInfoAccepted) ?? false;
      User? user;
      try {
        user = FirebaseAuth.instance.currentUser;
      } catch (_) {
        user = null;
      }
      if (!remember && user != null) {
        try { await FirebaseAuth.instance.signOut(); } catch (_) {}
        user = null;
      }
      final target = (remember && user != null) ? '/home' : '/onboarding';
      if (!infoAccepted) {
        if (!mounted) return;
        final ok = await _showInfoDialog();
        if (!ok || !mounted) return;
        await prefs.setBool(_kInfoAccepted, true);
      }
      if (!mounted || _navigated) return;
      _navigated = true;
      context.go(target);
    } catch (_) {
      if (!mounted || _navigated) return;
      _navigated = true;
      context.go('/onboarding');
    }
  }

  Future<bool> _showInfoDialog() async {
    bool checked = false;
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setState) {
            return WillPopScope(
              onWillPop: () async => false,
              child: AlertDialog(
                title: const Text('Bilgilendirme'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Bu uygulama eğlence amaçlı kahve yorumu sunar. '
                      'Gelecek hakkında tahmin yapmaz ve kesinlik içermez.',
                    ),
                    const SizedBox(height: 12),
                    CheckboxListTile(
                      value: checked,
                      onChanged: (v) => setState(() => checked = v ?? false),
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      title: const Text('Okudum, kabul ediyorum'),
                    ),
                  ],
                ),
                actions: [
                  ElevatedButton(
                    onPressed: checked ? () => Navigator.of(ctx).pop(true) : null,
                    child: const Text('Devam'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
    return result == true;
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
