import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class AdConsentState {
  const AdConsentState({
    this.initializing = false,
    this.initialized = false,
    this.canRequestAds = false,
    this.privacyOptionsRequired = false,
    this.error,
  });

  final bool initializing;
  final bool initialized;
  final bool canRequestAds;
  final bool privacyOptionsRequired;
  final String? error;

  AdConsentState copyWith({
    bool? initializing,
    bool? initialized,
    bool? canRequestAds,
    bool? privacyOptionsRequired,
    String? error,
    bool clearError = false,
  }) {
    return AdConsentState(
      initializing: initializing ?? this.initializing,
      initialized: initialized ?? this.initialized,
      canRequestAds: canRequestAds ?? this.canRequestAds,
      privacyOptionsRequired:
          privacyOptionsRequired ?? this.privacyOptionsRequired,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class AdConsentController extends Notifier<AdConsentState> {
  bool _mobileAdsInitialized = false;

  @override
  AdConsentState build() => const AdConsentState();

  Future<void> initialize() async {
    if (kIsWeb || state.initializing) return;

    state = state.copyWith(initializing: true, clearError: true);

    final completer = Completer<void>();
    ConsentInformation.instance.requestConsentInfoUpdate(
      ConsentRequestParameters(tagForUnderAgeOfConsent: false),
      () async {
        await ConsentForm.loadAndShowConsentFormIfRequired((formError) async {
          await _syncState(error: formError?.message);
          if (!completer.isCompleted) completer.complete();
        });
      },
      (error) async {
        await _syncState(error: error.message);
        if (!completer.isCompleted) completer.complete();
      },
    );

    await completer.future;
  }

  Future<void> showPrivacyOptionsForm() async {
    if (kIsWeb) return;

    state = state.copyWith(initializing: true, clearError: true);
    await ConsentForm.showPrivacyOptionsForm((formError) async {
      await _syncState(error: formError?.message);
    });
  }

  Future<void> _syncState({String? error}) async {
    final canRequestAds = await ConsentInformation.instance.canRequestAds();
    final privacyOptionsStatus =
        await ConsentInformation.instance.getPrivacyOptionsRequirementStatus();

    if (canRequestAds && !_mobileAdsInitialized) {
      await MobileAds.instance.initialize();
      _mobileAdsInitialized = true;
    }

    state = state.copyWith(
      initializing: false,
      initialized: true,
      canRequestAds: canRequestAds,
      privacyOptionsRequired:
          privacyOptionsStatus == PrivacyOptionsRequirementStatus.required,
      error: error,
    );
  }
}
