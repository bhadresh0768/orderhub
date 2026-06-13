import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:todo_reminder_alarm/app/ads/ad_units.dart';

class BannerAdService {
  BannerAdService._();

  static final BannerAdService instance = BannerAdService._();

  final ValueNotifier<bool> isLoaded = ValueNotifier(false);

  BannerAd? bannerAd;

  Future<void> loadBanner() async {
    final adUnitId = AdUnitIds.globalBottomBanner;
    if (adUnitId.isEmpty) {
      debugPrint('Ad Unit ID is empty');
      return;
    }
    if (adUnitId.isEmpty) return;

    bannerAd = BannerAd(
      adUnitId: adUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          debugPrint("✅ Banner Loaded");
          bannerAd = ad as BannerAd;
          isLoaded.value = true;
        },
        onAdFailedToLoad: (ad, error) {
          debugPrint("❌ Banner Failed: $error");
          ad.dispose();
        },
      ),
    );

    bannerAd!.load();
  }
}
