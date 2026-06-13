import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:todo_reminder_alarm/services/banner_ad_service.dart';

class GlobalBannerWidget extends StatelessWidget {
  const GlobalBannerWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: BannerAdService.instance.isLoaded,
      builder: (context, loaded, child) {
        debugPrint("GlobalBannerWidget rebuild => loaded=$loaded");

        final bannerAd = BannerAdService.instance.bannerAd;

        if (!loaded || bannerAd == null) {
          return const SizedBox.shrink();
        }

        return Material(
          color: Colors.white,
          elevation: 4,
          child: SafeArea(
            top: false,
            child: SizedBox(
              height: bannerAd.size.height.toDouble(),
              child: Center(
                child: SizedBox(
                  width: bannerAd.size.width.toDouble(),
                  height: bannerAd.size.height.toDouble(),
                  child: AdWidget(key: ValueKey(bannerAd), ad: bannerAd),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
