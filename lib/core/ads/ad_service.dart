import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class AdService {
  static Future<InitializationStatus> init() => MobileAds.instance.initialize();

  static String get bannerAdUnitId {
    if (Platform.isAndroid) {
      return 'ca-app-pub-3940256099942544/6300978111'; // test
    } else if (Platform.isIOS) {
      return 'ca-app-pub-3940256099942544/2934735716'; // test
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
        onAdFailedToLoad: (ad, err) {
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

