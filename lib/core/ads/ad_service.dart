import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'consent_helper.dart';

class AdService {
  static Future<InitializationStatus>? _initFuture;

  static Future<InitializationStatus> init() => _initFuture ??= _initInternal();

  static Future<InitializationStatus> _initInternal() async {
    final status = await MobileAds.instance.initialize();

    try {
      final ids = kDebugMode
          ? () {
              const raw = String.fromEnvironment('ADMOB_TEST_DEVICE_IDS');
              return raw.isEmpty
                  ? const <String>[]
                  : raw.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
            }()
          : const <String>[];
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

  static AdRequest buildRequest() {
    final npaFlag = const String.fromEnvironment('NPA') == '1';
    final useNpa = npaFlag || AdConsent.npa;
    return AdRequest(nonPersonalizedAds: useNpa);
  }

  static String get bannerAdUnitId {
    if (Platform.isAndroid) {
      // Banner Ad Unit (prod)
      return 'ca-app-pub-4678612524495888/8393122228';
    } else if (Platform.isIOS) {
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
      // Defer to next frame to safely read MediaQuery for adaptive size
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        final unitId = AdService.bannerAdUnitId;
        if (unitId.isEmpty || !mounted) return;
      late BannerAd banner;
        try {
          final width = MediaQuery.of(context).size.width.truncate();
          final adaptive = await AdSize.getCurrentOrientationAnchoredAdaptiveBannerAdSize(width);
          final size = adaptive ?? widget.size;
          banner = BannerAd(
          adUnitId: unitId,
          size: size,
          request: AdService.buildRequest(),
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
      } catch (e) {
        banner = BannerAd(
          adUnitId: unitId,
          size: widget.size,
          request: AdService.buildRequest(),
          listener: BannerAdListener(
            onAdLoaded: (ad) {
              debugPrint('[Banner] loaded (fallback): ${ad.adUnitId}');
            },
            onAdFailedToLoad: (ad, err) {
              debugPrint('[Banner] failed to load (fallback): ${err.code} ${err.message}');
              ad.dispose();
            },
          ),
        )..load();
      }
      if (!mounted) {
        banner.dispose();
        return;
      }
      setState(() => _ad = banner);
    });
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
