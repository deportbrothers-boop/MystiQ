import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class AdService {
  static Future<InitializationStatus> init() async {
    final status = await MobileAds.instance.initialize();
    try {
      const raw = String.fromEnvironment('ADMOB_TEST_DEVICE_IDS');
      final ids = raw.isEmpty
          ? const <String>[]
          : raw.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
      await MobileAds.instance.updateRequestConfiguration(
        RequestConfiguration(
          testDeviceIds: ids,
          // Keep content family-friendly by default
          maxAdContentRating: MaxAdContentRating.pg,
          tagForChildDirectedTreatment: TagForChildDirectedTreatment.unspecified,
          tagForUnderAgeOfConsent: TagForUnderAgeOfConsent.unspecified,
        ),
      );
    } catch (_) {}
    return status;
  }

  static String get bannerAdUnitId {
    if (Platform.isAndroid) {
      // MystiQ (Android) - Banner Ad Unit (prod)
      return 'ca-app-pub-4678612524495888/8393122228';
    } else if (Platform.isIOS) {
      // MystiQ (iOS) - Banner Ad Unit (prod)
      return 'ca-app-pub-4678612524495888/3711641189';
    }
    return ''; // other platforms not supported
  }
}

class AdBanner extends StatefulWidget {
  final AdSize size;
  const AdBanner({super.key, this.size = AdSize.banner});

  @override
  State<AdBanner> createState() => _AdBannerState();
}

class _AdBannerState extends State<AdBanner> {
  BannerAd? _ad;

  @override
  void initState() {
    super.initState();
    final unitId = AdService.bannerAdUnitId;
    if (unitId.isEmpty) return;
    _ad = BannerAd(
      adUnitId: unitId,
      size: widget.size,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          debugPrint('[Banner] loaded: ${ad.adUnitId}');
        },
        onAdFailedToLoad: (ad, err) {
          debugPrint('[Banner] failed to load: ${err.code} ${err.message}');
          ad.dispose();
        },
      ),
    )..load();
  }

  @override
  Widget build(BuildContext context) {
    final ad = _ad;
    if (ad == null) return const SizedBox.shrink();
    return SizedBox(
      width: ad.size.width.toDouble(),
      height: ad.size.height.toDouble(),
      child: AdWidget(ad: ad),
    );
  }

  @override
  void dispose() {
    _ad?.dispose();
    super.dispose();
  }
}
