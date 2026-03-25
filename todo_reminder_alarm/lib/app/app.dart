import 'dart:async';
import 'package:android_intent_plus/android_intent.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart' show StateProvider;
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../models/app_user.dart';
import '../models/business.dart';
import '../models/enums.dart';
import '../providers.dart';
import 'ads/ad_units.dart';
import 'order_status_listener.dart';
import '../ui/screens/auth/login_screen.dart';
import '../ui/screens/auth/signup_screen.dart';
import '../ui/screens/home/admin/admin_home.dart';
import '../ui/screens/home/business/business_home.dart';
import '../ui/screens/home/customer/customer_home.dart';
import '../ui/screens/home/delivery_agent/delivery_boy_home.dart';
import '../ui/screens/profile/public_business_profile_screen.dart';
import 'theme.dart';

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp(
      title: 'OrderHub',
      debugShowCheckedModeBanner: false,
      themeMode: themeMode,
      theme: lightTheme(),
      darkTheme: darkTheme(),
      builder: (context, child) {
        return _InternetStatusOverlay(child: child ?? const SizedBox.shrink());
      },
      routes: {
        '/': (_) => const OrderStatusListener(child: AuthGate()),
        LoginScreen.routeName: (_) => const LoginScreen(),
        SignUpScreen.routeName: (_) => const SignUpScreen(),
      },
    );
  }
}

class _InternetStatusOverlay extends ConsumerWidget {
  const _InternetStatusOverlay({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final internetAsync = ref.watch(internetConnectedProvider);
    final isOnline = internetAsync.value ?? true;
    final showAds = ref.watch(showAdsProvider);
    final authUser = ref.watch(authStateProvider).value;
    final adConsent = ref.watch(adConsentProvider);
    final showGlobalBanner =
        showAds && authUser != null && adConsent.canRequestAds;
    return Stack(
      children: [
        Padding(
          padding: EdgeInsets.only(
            bottom: showGlobalBanner ? _GlobalBottomBannerAd.totalHeight : 0,
          ),
          child: child,
        ),
        if (showGlobalBanner)
          const Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _GlobalBottomBannerAd(),
          ),
        if (!isOnline)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: Material(
                color: Colors.red.shade700,
                elevation: 4,
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.wifi_off, color: Colors.white, size: 18),
                      SizedBox(width: 8),
                      Text(
                        'No internet connection',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _GlobalBottomBannerAd extends ConsumerStatefulWidget {
  const _GlobalBottomBannerAd();

  static const double totalHeight = 58;

  @override
  ConsumerState<_GlobalBottomBannerAd> createState() =>
      _GlobalBottomBannerAdState();
}

final _globalBannerAdProvider = StateProvider<BannerAd?>((ref) => null);
final _globalBannerLoadedProvider = StateProvider<bool>((ref) => false);

class _GlobalBottomBannerAdState extends ConsumerState<_GlobalBottomBannerAd> {
  BannerAd? _bannerAd;

  @override
  void initState() {
    super.initState();
    _loadBanner();
  }

  void _loadBanner() {
    if (kIsWeb) return;
    final adUnitId = AdUnitIds.globalBottomBanner;
    if (adUnitId.isEmpty) return;

    final ad = BannerAd(
      adUnitId: adUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          if (!mounted) {
            ad.dispose();
            return;
          }
          final loadedAd = ad as BannerAd;
          final previous = _bannerAd;
          if (previous != null && previous != loadedAd) {
            previous.dispose();
          }
          _bannerAd = loadedAd;
          _queueBannerStateUpdate(ad: loadedAd, isLoaded: true);
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          if (!mounted) return;
          debugPrint(
            'Global banner failed to load: '
            'code=${error.code}, domain=${error.domain}, message=${error.message}',
          );
          _bannerAd = null;
          _queueBannerStateUpdate(ad: null, isLoaded: false);
        },
      ),
    );
    ad.load();
  }

  void _queueBannerStateUpdate({
    required BannerAd? ad,
    required bool isLoaded,
  }) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(_globalBannerAdProvider.notifier).state = ad;
      ref.read(_globalBannerLoadedProvider.notifier).state = isLoaded;
    });
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    _bannerAd = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bannerAd = ref.watch(_globalBannerAdProvider);
    final isLoaded = ref.watch(_globalBannerLoadedProvider);
    if (!isLoaded || bannerAd == null) {
      return const SizedBox(height: _GlobalBottomBannerAd.totalHeight);
    }
    return Material(
      color: Colors.white,
      elevation: 6,
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: _GlobalBottomBannerAd.totalHeight,
          child: Center(
            child: SizedBox(
              width: bannerAd.size.width.toDouble(),
              height: bannerAd.size.height.toDouble(),
              child: AdWidget(ad: bannerAd),
            ),
          ),
        ),
      ),
    );
  }
}

class AuthGate extends ConsumerStatefulWidget {
  const AuthGate({super.key});

  @override
  ConsumerState<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends ConsumerState<AuthGate> {
  bool _deepLinkStarted = false;
  StreamSubscription<String>? _deepLinkSub;
  String? _pendingBusinessId;
  bool _openingDeepLink = false;
  final Set<String> _subscriptionSyncKeys = <String>{};

  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(adConsentProvider.notifier).initialize());
  }

  void _startDeepLinkListener() {
    if (_deepLinkStarted) return;
    _deepLinkStarted = true;
    final deepLinkService = ref.read(deepLinkServiceProvider);
    unawaited(deepLinkService.init());
    _deepLinkSub = deepLinkService.businessIdStream.listen((businessId) async {
      _pendingBusinessId = businessId;
      await _tryOpenPendingDeepLink();
    });
  }

  Future<void> _tryOpenPendingDeepLink() async {
    if (_openingDeepLink) return;
    final businessId = _pendingBusinessId;
    if (businessId == null) return;
    final user = ref.read(firebaseAuthProvider).currentUser;
    if (user == null || !mounted) return;

    _openingDeepLink = true;
    try {
      final business = await ref
          .read(firestoreServiceProvider)
          .getBusinessById(businessId);
      if (!mounted || business == null) return;
      _pendingBusinessId = null;
      _openBusinessDeepLink(business);
    } finally {
      _openingDeepLink = false;
    }
  }

  void _openBusinessDeepLink(BusinessProfile business) {
    final route = MaterialPageRoute(
      builder: (_) => PublicBusinessProfileScreen(business: business),
    );
    Navigator.of(context).push(route);
  }

  @override
  void dispose() {
    _deepLinkSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _startDeepLinkListener();
    unawaited(_tryOpenPendingDeepLink());
    final authState = ref.watch(authStateProvider);
    return authState.when(
      data: (user) {
        if (user == null) {
          return const LoginScreen();
        }
        final profileAsync = ref.watch(userProfileProvider(user.uid));
        return profileAsync.when(
          data: (profile) {
            if (profile == null) {
              final phoneNumber = user.phoneNumber?.trim() ?? '';
              if (phoneNumber.isNotEmpty) {
                return _AutoProvisionDeliveryBoyProfile(user: user);
              }
              return const SignUpScreen();
            }
            final businessId = profile.businessId;
            if (businessId != null && businessId.isNotEmpty) {
              final businessAsync = ref.watch(businessByIdProvider(businessId));
              final business = businessAsync.value;
              if (businessAsync.isLoading) {
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              }
              if (profile.role == UserRole.businessOwner &&
                  business?.status == BusinessStatus.suspended) {
                return const _BlockedUserScreen(
                  message: 'Your business account is suspended by admin.',
                );
              }
              if (profile.role == UserRole.businessOwner &&
                  business?.status == BusinessStatus.pending) {
                return const _BlockedUserScreen(
                  message: 'Your business approval is pending admin review.',
                );
              }
              if (business != null) {
                _syncExpiredSubscriptionIfNeeded(business);
              }
            }
            if (!profile.isActive) {
              return const _BlockedUserScreen();
            }
            ref.read(pushNotificationServiceProvider).initForUser(user.uid);
            switch (profile.role) {
              case UserRole.admin:
                return const _AppUpdateGate(child: AdminHomeScreen());
              case UserRole.businessOwner:
                return const _AppUpdateGate(child: BusinessHomeScreen());
              case UserRole.deliveryBoy:
                return const _AppUpdateGate(child: DeliveryBoyHomeScreen());
              case UserRole.customer:
                return const _AppUpdateGate(child: CustomerHomeScreen());
            }
          },
          loading: () =>
              const Scaffold(body: Center(child: CircularProgressIndicator())),
          error: (err, _) => Scaffold(body: Center(child: Text('Error: $err'))),
        );
      },
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (err, _) => Scaffold(body: Center(child: Text('Error: $err'))),
    );
  }

  void _syncExpiredSubscriptionIfNeeded(BusinessProfile business) {
    if (!business.subscriptionActive) return;
    final end = business.subscriptionEndDate;
    if (end == null) return;
    final now = DateTime.now();
    if (!now.isAfter(end)) return;

    final syncKey = '${business.id}-${end.millisecondsSinceEpoch}';
    if (_subscriptionSyncKeys.contains(syncKey)) return;
    _subscriptionSyncKeys.add(syncKey);
    unawaited(
      ref
          .read(firestoreServiceProvider)
          .deactivateExpiredBusinessSubscription(business.id)
          .catchError((_) {
            _subscriptionSyncKeys.remove(syncKey);
          }),
    );
  }
}

class _AppUpdateGate extends ConsumerStatefulWidget {
  const _AppUpdateGate({required this.child});

  final Widget child;

  @override
  ConsumerState<_AppUpdateGate> createState() => _AppUpdateGateState();
}

class _AppUpdateGateState extends ConsumerState<_AppUpdateGate> {
  bool _dialogOpen = false;
  String? _lastPromptedVersion;

  @override
  Widget build(BuildContext context) {
    final config = ref.watch(appUpdateConfigProvider).value;
    final appVersion = ref.watch(appVersionProvider).value;

    final shouldPrompt =
        config != null &&
        config.enabled &&
        appVersion != null &&
        _isVersionNewer(config.latestVersion, appVersion) &&
        _lastPromptedVersion != config.latestVersion &&
        !_dialogOpen;

    if (shouldPrompt) {
      _dialogOpen = true;
      _lastPromptedVersion = config.latestVersion;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        await _showUpdateDialog(
          config.latestVersion,
          config.storeUrl,
          config.notes,
        );
        if (mounted) {
          _dialogOpen = false;
        }
      });
    }

    return widget.child;
  }

  List<int> _parseVersion(String raw) {
    final clean = raw.trim().split('+').first;
    final parts = clean.split('.');
    final numbers = parts.map((p) => int.tryParse(p) ?? 0).toList();
    while (numbers.length < 3) {
      numbers.add(0);
    }
    return numbers.take(3).toList();
  }

  bool _isVersionNewer(String latest, String current) {
    final a = _parseVersion(latest);
    final b = _parseVersion(current);
    for (var i = 0; i < 3; i++) {
      if (a[i] > b[i]) return true;
      if (a[i] < b[i]) return false;
    }
    return false;
  }

  Future<void> _openStoreLink(String link) async {
    try {
      final intent = AndroidIntent(
        action: 'android.intent.action.VIEW',
        data: link,
      );
      await intent.launch();
    } catch (_) {
      await Clipboard.setData(ClipboardData(text: link));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to open store. Link copied.')),
      );
    }
  }

  Future<void> _showUpdateDialog(
    String latestVersion,
    String storeUrl,
    String? notes,
  ) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (context) => AlertDialog(
        title: const Text('Update Available'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('A newer app version ($latestVersion) is available.'),
            if ((notes ?? '').trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('What\'s new:\n${notes!.trim()}'),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Later'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.of(context).pop();
              await _openStoreLink(storeUrl);
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }
}

class _AutoProvisionDeliveryBoyProfile extends ConsumerStatefulWidget {
  const _AutoProvisionDeliveryBoyProfile({required this.user});

  final User user;

  @override
  ConsumerState<_AutoProvisionDeliveryBoyProfile> createState() =>
      _AutoProvisionDeliveryBoyProfileState();
}

class _AutoProvisionDeliveryBoyProfileState
    extends ConsumerState<_AutoProvisionDeliveryBoyProfile> {
  void _updateUi(
    _AutoProvisionUiState Function(_AutoProvisionUiState state) update,
  ) {
    final notifier = ref.read(
      _autoProvisionUiProvider(widget.user.uid).notifier,
    );
    notifier.state = update(notifier.state);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _provisionIfDeliveryBoy();
    });
  }

  Future<void> _provisionIfDeliveryBoy() async {
    try {
      final phone = widget.user.phoneNumber?.trim() ?? '';
      if (phone.isEmpty) {
        _updateUi((state) => state.copyWith(loading: false));
        return;
      }
      final firestore = ref.read(firestoreServiceProvider);
      final agent = await firestore.findActiveDeliveryAgentByPhone(phone);
      if (agent == null) {
        _updateUi((state) => state.copyWith(loading: false));
        return;
      }
      final profile = AppUser(
        id: widget.user.uid,
        email: widget.user.email ?? '',
        role: UserRole.deliveryBoy,
        name: (widget.user.displayName ?? '').trim().isEmpty
            ? agent.name
            : widget.user.displayName!.trim(),
        phoneNumber: phone,
        businessId: agent.businessId,
      );
      await firestore.createUserProfile(profile);
      if (!mounted) return;
      _updateUi(
        (state) => state.copyWith(matchedDeliveryBoy: true, loading: false),
      );
    } catch (err) {
      if (!mounted) return;
      _updateUi(
        (state) => state.copyWith(error: err.toString(), loading: false),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final ui = ref.watch(_autoProvisionUiProvider(widget.user.uid));
    if (ui.loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (ui.error != null) {
      return Scaffold(body: Center(child: Text('Error: ${ui.error}')));
    }
    if (ui.matchedDeliveryBoy) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return const SignUpScreen();
  }
}

final _autoProvisionUiProvider = StateProvider.autoDispose
    .family<_AutoProvisionUiState, String>(
      (ref, _) => const _AutoProvisionUiState(),
    );

class _AutoProvisionUiState {
  const _AutoProvisionUiState({
    this.loading = true,
    this.matchedDeliveryBoy = false,
    this.error,
  });

  final bool loading;
  final bool matchedDeliveryBoy;
  final String? error;

  _AutoProvisionUiState copyWith({
    bool? loading,
    bool? matchedDeliveryBoy,
    Object? error = _autoProvisionUnset,
  }) {
    return _AutoProvisionUiState(
      loading: loading ?? this.loading,
      matchedDeliveryBoy: matchedDeliveryBoy ?? this.matchedDeliveryBoy,
      error: error == _autoProvisionUnset ? this.error : error as String?,
    );
  }
}

const _autoProvisionUnset = Object();

class _BlockedUserScreen extends ConsumerWidget {
  const _BlockedUserScreen({
    this.message = 'Your account is blocked by admin.',
  });

  final String message;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () => ref.read(authServiceProvider).signOut(),
              child: const Text('Logout'),
            ),
          ],
        ),
      ),
    );
  }
}
