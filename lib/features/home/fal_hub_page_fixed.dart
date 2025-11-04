import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/entitlements/entitlements_controller.dart';
import '../../core/i18n/app_localizations.dart';
import '../../common/widgets/sharp_image.dart';

class FalHubPage extends StatefulWidget {
  const FalHubPage({super.key});
  @override
  State<FalHubPage> createState() => _FalHubPageState();
}

class _FalHubPageState extends State<FalHubPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      const paths = [
        'assets/images/categories/coffee.png',
        'assets/images/categories/tarot.png',
        'assets/images/categories/palm.png',
        'assets/images/categories/astro.png',
        'assets/images/categories/live.png',
        'assets/images/categories/dream.png',
      ];
      () async {
        // Throttled precache to avoid jank on first frame
        for (final p in paths) {
          if (!mounted) break;
          await Future.delayed(const Duration(milliseconds: 60));
          try {
            await precacheImage(AssetImage(p), context);
          } catch (_) {}
        }
      }();
    });
  }

  @override
  Widget build(BuildContext context) {
    final items = [
      _FalItem(AppLocalizations.of(context).t('coffee.title'), Icons.coffee, '/reading/coffee', image: 'assets/images/categories/coffee.png'),
      _FalItem(AppLocalizations.of(context).t('tarot.title'), Icons.style, '/reading/tarot', image: 'assets/images/categories/tarot.png'),
      _FalItem(AppLocalizations.of(context).t('palm.title'), Icons.pan_tool_alt_outlined, '/reading/palm', image: 'assets/images/categories/palm.png'),
      _FalItem(AppLocalizations.of(context).t('astro.title'), Icons.brightness_2_outlined, '/reading/astro', image: 'assets/images/categories/astro.png'),
      _FalItem(
        AppLocalizations.of(context).t('live.title'),
        Icons.live_tv,
        '/live',
        image: 'assets/images/categories/live.png',
        disabled: true,
        disabledLabel: AppLocalizations.of(context).t('common.coming_soon'),
      ),
      _FalItem(AppLocalizations.of(context).t('dream.title'), Icons.nightlight_round, '/reading/dream', image: 'assets/images/categories/dream.png'),
    ];

    final coins = context.watch<EntitlementsController>().coins;
    final loc = AppLocalizations.of(context);
    final premium = context.watch<EntitlementsController>().isPremium;
    return Scaffold(
      appBar: AppBar(title: Text(loc.t('app.name')), actions: [
        if (!premium)
          Padding(
            padding: const EdgeInsets.only(right: 8.0, top: 8.0, bottom: 8.0),
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () => context.push('/paywall'),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 6.0),
                child: Row(children: [
                  const Icon(Icons.monetization_on_outlined),
                  const SizedBox(width: 4),
                  Text('$coins'),
                  const SizedBox(width: 6),
                ]),
              ),
            ),
          )
      ]),
      body: Column(
        children: [
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.0,
              ),
              itemCount: items.length,
              itemBuilder: (_, i) => items[i],
            ),
          ),
          const SizedBox(height: 8),
          _MotivationBanner(),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

class _FalItem extends StatelessWidget {
  final String title;
  final IconData icon;
  final String route;
  final String? image;
  final bool disabled;
  final String? disabledLabel;
  const _FalItem(this.title, this.icon, this.route, {this.image, this.disabled = false, this.disabledLabel});

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(16);
    final isDisabled = disabled;
    return Card(
      shape: RoundedRectangleBorder(borderRadius: radius),
      elevation: 2,
      clipBehavior: Clip.antiAlias,
      child: AbsorbPointer(
        absorbing: isDisabled,
        child: InkWell(
          borderRadius: radius,
          overlayColor: WidgetStatePropertyAll(Theme.of(context).colorScheme.primary.withValues(alpha: 0.06)),
          onTap: isDisabled ? null : () => context.push(route),
        child: Stack(
          children: [
            Positioned.fill(
              child: isDisabled
                  ? ImageFiltered(
                      imageFilter: ui.ImageFilter.blur(sigmaX: 3.5, sigmaY: 3.5),
                      child: _CoverImage(icon: icon, image: image),
                    )
                  : _CoverImage(icon: icon, image: image),
            ),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.25),
                      Colors.black.withValues(alpha: 0.65),
                    ],
                  ),
                ),
              ),
            ),
            if (isDisabled)
              Positioned.fill(
                child: Container(color: Colors.black.withValues(alpha: 0.20)),
              ),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(0, -0.1),
                    radius: 1.1,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.35),
                    ],
                    stops: const [0.55, 1.0],
                  ),
                ),
              ),
            ),
            if (isDisabled)
              Positioned.fill(
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: Text(
                      disabledLabel ?? AppLocalizations.of(context).t('common.coming_soon'),
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ),
            // Show the title always, even when disabled, so users see
            // "Canlı Falcı" under the tile with a "Yakında" badge.
            Positioned(
              left: 12,
              right: 12,
              bottom: 12,
              child: Text(
                title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }
}

class _CoverImage extends StatelessWidget {
  final IconData icon;
  final String? image;
  const _CoverImage({required this.icon, required this.image});
  @override
  Widget build(BuildContext context) {
    if (image == null) {
      return Center(child: Icon(icon, size: 64, color: Theme.of(context).colorScheme.primary));
    }
    return SharpAssetFallback(
      image!,
      fit: BoxFit.cover,
      errorBuilder: (c, e, s) => Center(
        child: Icon(icon, size: 64, color: Theme.of(context).colorScheme.primary),
      ),
    );
  }
}

class _MotivationBanner extends StatelessWidget {
  _MotivationBanner();
  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final now = DateTime.now();
    final tipKey = 'daily.tip.${(((now.weekday - 1) % 7) + 1)}';
    final tip = loc.t(tipKey);
    final title = AppLocalizations.of(context).t('motivation.title');
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => context.push('/motivation'),
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              colors: [
                scheme.primary.withValues(alpha: 0.18),
                scheme.primary.withValues(alpha: 0.05),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(color: scheme.primary.withValues(alpha: 0.35)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: scheme.primary.withValues(alpha: 0.15),
                ),
                child: Icon(Icons.auto_awesome, color: scheme.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text(
                      tip,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white70),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}













