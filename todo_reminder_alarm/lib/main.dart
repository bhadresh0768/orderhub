import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:todo_reminder_alarm/services/banner_ad_service.dart';

import 'app/app.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  debugPrint("STEP 1");

  await Hive.initFlutter();

  debugPrint("STEP 2");

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  debugPrint("STEP 3");

  await FirebaseAppCheck.instance.activate(
    providerAndroid: kDebugMode
        ? const AndroidDebugProvider()
        : const AndroidPlayIntegrityProvider(),
    providerApple: kDebugMode
        ? const AppleDebugProvider()
        : const AppleDeviceCheckProvider(),
  );

  debugPrint("STEP 4");

  await MobileAds.instance.initialize();

  debugPrint("STEP 5");

  await BannerAdService.instance.loadBanner();

  debugPrint("STEP 6");

  runApp(const ProviderScope(child: MyApp()));
}
