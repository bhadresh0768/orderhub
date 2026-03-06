import 'package:flutter/foundation.dart';

class AdUnitIds {
  AdUnitIds._();

  // IMPORTANT (AdMob policy):
  // Use a unique ad unit per placement. Do not reuse the same ad unit ID
  // in multiple sections/screens.

  // Global bottom banner placement (shown app-wide when showAds=true).
  static const String _androidGlobalBottomBannerProd =
      'ca-app-pub-xxxxxxxxxxxxxxxx/1111111111';
  static const String _iosGlobalBottomBannerProd =
      'ca-app-pub-xxxxxxxxxxxxxxxx/2222222222';

  // Test IDs (safe for development/testing).
  static const String _androidBannerTest =
      'ca-app-pub-3940256099942544/6300978111';
  static const String _iosBannerTest = 'ca-app-pub-3940256099942544/2934735716';

  static String get globalBottomBanner {
    if (kIsWeb) return '';
    final isIOS = defaultTargetPlatform == TargetPlatform.iOS;
    if (kDebugMode) {
      return isIOS ? _iosBannerTest : _androidBannerTest;
    }
    return isIOS ? _iosGlobalBottomBannerProd : _androidGlobalBottomBannerProd;
  }
}
