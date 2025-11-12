import 'dart:io';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/entitlements/entitlements_controller.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/i18n/locale_controller.dart';
import '../../core/rewards/rewards_controller.dart';
import '../../features/history/history_controller.dart';
import '../help/faq_page.dart';
import '../help/feedback_page.dart';
import '../legal/legal_pages.dart';
import '../notifications/notification_center_page.dart';
import 'edit_profile_page.dart';
import 'profile_controller.dart';
import 'user_profile.dart';
import '../../common/widgets/gold_bar.dart';
import '../../theme/app_theme.dart';
import '../../core/referral/referral_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    final ent = context.watch<EntitlementsController>();
    final loc = AppLocalizations.of(context);
    final rewards = context.watch<RewardsController>();
    final hist = context.watch<HistoryController>();
    final profileCtrl = context.watch<ProfileController>();
    final lc = context.watch<LocaleController>();
    final code = lc.locale?.languageCode;

    String langLabel(String? c) {
      switch (c) {
        case 'tr':
          return loc.t('lang.tr');
        case 'en':
          return loc.t('lang.en');
        case 'es':
          return loc.t('lang.es');
        case 'ar':
          return loc.t('lang.ar');
        default:
          return 'System';
      }
    }

    final p = profileCtrl.profile;
    ImageProvider? avatar;
    if (p.photoPath != null && p.photoPath!.isNotEmpty) {
      try { avatar = FileImage(File(p.photoPath!)); } catch (_) { avatar = null; }
    } else if (p.photoUrl != null && p.photoUrl!.isNotEmpty) {
      avatar = NetworkImage(p.photoUrl!);
    }

    return Scaffold(
      appBar: AppBar(title: Text(loc.t('profile.title'))),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          CircleAvatar(
            radius: 34,
            backgroundImage: avatar,
            child: avatar == null ? const Icon(Icons.person, size: 34) : null,
          ),
          const SizedBox(height: 12),
          Text(
            p.name.isEmpty ? loc.t('profile.anonymous') : p.name,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Row(children: [
            const Icon(Icons.cake, size: 18),
            const SizedBox(width: 6),
            Text(p.birthDate != null ? '${p.birthDate!.day}.${p.birthDate!.month}.${p.birthDate!.year}' : '-'),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            const Icon(Icons.star_border, size: 18),
            const SizedBox(width: 6),
            Text(p.zodiac.isEmpty ? '-' : p.zodiac),
          ]),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const EditProfilePage())),
            child: Text(loc.t('profile.edit')),
          ),
          const SizedBox(height: 16),

          // Energy
          Card(
            child: ListTile(
              leading: const Icon(Icons.bolt),
              title: Text(loc.t('profile.energy')),
              subtitle: GoldBar(value: (ent.energy.clamp(0, 100)) / 100),
              trailing: Text('${ent.energy}%'),
            ),
          ),
          const SizedBox(height: 12),

          // Elements
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(loc.t('profile.element_balance')),
                  const SizedBox(height: 8),
                  _ElementRow(
                    zodiac: p.zodiac.isEmpty && p.birthDate != null
                        ? ZodiacUtil.fromDate(p.birthDate!)
                        : p.zodiac,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Wallet
          Card(
            child: ListTile(
              leading: const Icon(Icons.monetization_on_outlined),
              title: Text(loc.t('profile.wallet')),
              trailing: Text('${ent.coins}'),
            ),
          ),
          const SizedBox(height: 12),

          // Refer a friend & Promo code buttons
          ElevatedButton.icon(
            icon: const Icon(Icons.group_add_outlined),
            onPressed: () async {
              final code = await ReferralService.myCode();
              if (!context.mounted) return;
              await showModalBottomSheet(
                context: context,
                showDragHandle: true,
                backgroundColor: const Color(0xFF121018),
                builder: (ctx) {
                  final ctrl = TextEditingController();
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Arkadasini getir – 1 fal hakki kazan', style: TextStyle(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 6),
                        Row(children: [
                          Expanded(child: SelectableText(code, style: const TextStyle(fontSize: 16))),
                          const SizedBox(width: 8),
                          OutlinedButton(onPressed: () async { await ReferralService.shareMyCode(ctx); }, child: const Text('Paylas')),
                        ]),
                        const SizedBox(height: 12),
                        const Text('Arkadas kodu gir:'),
                        const SizedBox(height: 6),
                        TextField(controller: ctrl, decoration: const InputDecoration(border: OutlineInputBorder(), hintText: 'KOD')), 
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerRight,
                          child: ElevatedButton(
                            onPressed: () async {
                              final ok = await ReferralService.redeemReferral(code: ctrl.text, ent: ent);
                              if (ctx.mounted) {
                                Navigator.pop(ctx);
                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ok ? '+1 fal hakki (100 coin) verildi' : 'Kod kullanilamadi')));
                              }
                            },
                            child: const Text('Kullan'),
                          ),
                        )
                      ],
                    ),
                  );
                },
              );
            },
            label: const Text('Arkadasini getir – 1 fal hakki kazan'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            icon: const Icon(Icons.card_giftcard_outlined),
            onPressed: () async {
              final ctrl = TextEditingController();
              await showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Promosyon Kodu'),
                  content: TextField(controller: ctrl, decoration: const InputDecoration(hintText: 'Kodu gir (1 kez, 1 fal hakki)')),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Iptal')),
                    ElevatedButton(
                      onPressed: () async {
                        final ok = await ReferralService.redeemPromo(code: ctrl.text, ent: ent);
                        if (ctx.mounted) {
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ok ? 'Promosyon: +1 fal hakki (100 coin) verildi' : 'Gecersiz kod veya daha once kullanildi')));
                        }
                      },
                      child: const Text('Kullan'),
                    ),
                  ],
                ),
              );
            },
            label: const Text('Promosyon Kodu'),
          ),
          const SizedBox(height: 12),

          if (kDebugMode)
            OutlinedButton.icon(
              icon: const Icon(Icons.bug_report),
              label: Text(AppLocalizations.of(context).t('profile.test.add_10000_button')),
              onPressed: () async {
                await ent.addCoins(10000);
                if (context.mounted) {
                  ScaffoldMessenger.of(context)
                      .showSnackBar(const SnackBar(content: Text('+10000 coin eklendi')));
                }
              },
            ),
          if (kDebugMode) const SizedBox(height: 12),

          // Premium
          ElevatedButton(onPressed: () => context.push('/paywall'), child: Text(loc.t('profile.premium'))),
          const SizedBox(height: 8),
          Text(
            ent.isPremium
                ? "Premium: ${ent.premiumSku == 'lifetime.mystic_plus' ? 'Lifetime' : 'Bitis: ${ent.premiumUntil}'}"
                : loc.t('premium.inactive'),
          ),
          const SizedBox(height: 8),

          // Daily reward
          ElevatedButton(
            onPressed: rewards.canClaimDaily()
                ? () async {
                    final ok = await rewards.claimDaily(ent);
                    if (ok && context.mounted) {
                      ScaffoldMessenger.of(context)
                          .showSnackBar(SnackBar(content: Text(loc.t('rewards.daily.snack'))));
                    }
                  }
                : null,
            child: Text(loc.t('rewards.daily.button')),
          ),
          const SizedBox(height: 8),

          // Weekly reward
          ElevatedButton(
            onPressed: rewards.canClaimWeekly(hist)
                ? () async {
                    final ok = await rewards.claimWeekly(ent, hist);
                    if (ok && context.mounted) {
                      ScaffoldMessenger.of(context)
                          .showSnackBar(SnackBar(content: Text(loc.t('rewards.weekly.snack'))));
                    }
                  }
                : null,
            child: Text(loc.t('rewards.weekly.button')),
          ),
          const SizedBox(height: 8),

          // Notifications
          OutlinedButton(
            onPressed: () => Navigator.of(context)
                .push(MaterialPageRoute(builder: (_) => const NotificationCenterPage())),
            child: Text(loc.t('common.notifications')),
          ),
          const SizedBox(height: 8),

          // Language (settings)
          Card(
            color: const Color(0xFF151019),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: Colors.white12),
            ),
            child: ListTile(
              leading: const Icon(Icons.language),
              title: Text(loc.t('settings.language')),
              subtitle: Text(langLabel(code)),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/settings'),
            ),
          ),
          const SizedBox(height: 8),

          OutlinedButton(
            onPressed: () => Navigator.of(context)
                .push(MaterialPageRoute(builder: (_) => const FaqPage())),
            child: Text(loc.t('help.faq')),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: () => Navigator.of(context)
                .push(MaterialPageRoute(builder: (_) => const FeedbackPage())),
            child: Text(loc.t('help.feedback')),
          ),
          const SizedBox(height: 8),
          Row(children: [
            OutlinedButton(
              onPressed: () => Navigator.of(context)
                  .push(MaterialPageRoute(builder: (_) => const TermsPage())),
              child: Text(loc.t('legal.terms_short')),
            ),
            const SizedBox(width: 8),
            OutlinedButton(
              onPressed: () => Navigator.of(context)
                  .push(MaterialPageRoute(builder: (_) => const PrivacyPage())),
              child: Text(loc.t('legal.privacy_short')),
            ),
          ]),
          const SizedBox(height: 16),
          // Sign out
          ElevatedButton.icon(
            icon: const Icon(Icons.logout),
            label: const Text('Çıkış Yap'),
            onPressed: () async {
              try {
                final prefs = await SharedPreferences.getInstance();
                await prefs.setBool('remember_me', false);
                await prefs.setBool('just_signed_up', false);
              } catch (_) {}
              try { await FirebaseAuth.instance.signOut(); } catch (_) {}
              if (context.mounted) {
                // root’a dön ve auth’a git
                context.go('/auth');
              }
            },
          )
        ],
      ),
    );
  }
}

class _ElementRow extends StatelessWidget {
  final String zodiac;
  const _ElementRow({required this.zodiac});

  @override
  Widget build(BuildContext context) {
    final items = _distributionForZodiac(zodiac);
    final loc = AppLocalizations.of(context);
    return Column(
      children: items
          .map((e) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(children: [
                  SizedBox(width: 64, child: Text(_labelFor(e.name, loc))),
                  const SizedBox(width: 8),
                  Expanded(
                    child: LinearProgressIndicator(
                      value: e.value,
                      minHeight: 8,
                      backgroundColor: Colors.white12,
                      valueColor:
                          const AlwaysStoppedAnimation<Color>(AppTheme.gold),
                    ),
                  ),
                ]),
              ))
          .toList(),
    );
  }
}

List<_Element> _distributionForZodiac(String zodiac) {
  // Defaults if zodiac is unknown
  double fire = 0.25, earth = 0.25, air = 0.25, water = 0.25;

  final z = _norm(zodiac);
  final isFire = ['koc', 'aslan', 'yay'].contains(z);
  final isEarth = ['boga', 'basak', 'oglak'].contains(z);
  final isAir = ['ikizler', 'terazi', 'kova'].contains(z);
  final isWater = ['yengec', 'akrep', 'balik'].contains(z);

  if (isFire || isEarth || isAir || isWater) {
    // Primary element dominates; allied gets secondary weight
    // Allies: Fire↔Air, Earth↔Water
    const p = 0.58; // primary
    const s = 0.22; // allied
    const r = 0.10; // others
    if (isFire) {
      fire = p; air = s; earth = r; water = r;
    } else if (isEarth) {
      earth = p; water = s; fire = r; air = r;
    } else if (isAir) {
      air = p; fire = s; earth = r; water = r;
    } else if (isWater) {
      water = p; earth = s; fire = r; air = r;
    }
  }

  return [
    _Element('fire', fire),
    _Element('earth', earth),
    _Element('air', air),
    _Element('water', water),
  ];
}

String _norm(String s) {
  var t = s.trim().toLowerCase();
  const pairs = <String, String>{
    '\u00E7': 'c', // ç
    '\u011F': 'g', // ğ
    '\u0131': 'i', // ı
    '\u0130': 'i', // İ
    'i\u0307': 'i', // i̇ (i + dot)
    '\u00F6': 'o', // ö
    '\u015F': 's', // ş
    '\u00FC': 'u', // ü
    '\u00E2': 'a', // â
    '\u00EE': 'i', // î
    '\u00FB': 'u', // û
  };
  pairs.forEach((k, v) => t = t.replaceAll(k, v));
  return t;
}

class _Element {
  final String name; // fire | earth | air | water
  final double value;
  const _Element(this.name, this.value);
}

String _labelFor(String key, AppLocalizations loc) {
  switch (key) {
    case 'fire':
      return loc.t('elements.fire');
    case 'earth':
      return loc.t('elements.earth');
    case 'air':
      return loc.t('elements.air');
    case 'water':
      return loc.t('elements.water');
    default:
      return key;
  }
}


