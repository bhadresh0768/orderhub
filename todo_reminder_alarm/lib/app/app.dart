import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart' show StateProvider;

import '../models/app_user.dart';
import '../models/business.dart';
import '../models/enums.dart';
import '../providers.dart';
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
        return _InternetStatusOverlay(
          child: child ?? const SizedBox.shrink(),
        );
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
    return Stack(
      children: [
        child,
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
            if (!profile.isActive) {
              return const _BlockedUserScreen();
            }
            ref.read(pushNotificationServiceProvider).initForUser(user.uid);
            switch (profile.role) {
              case UserRole.admin:
                return const AdminHomeScreen();
              case UserRole.businessOwner:
                return const BusinessHomeScreen();
              case UserRole.deliveryBoy:
                return const DeliveryBoyHomeScreen();
              case UserRole.customer:
                return const CustomerHomeScreen();
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
  void _updateUi(_AutoProvisionUiState Function(_AutoProvisionUiState state) update) {
    final notifier = ref.read(_autoProvisionUiProvider(widget.user.uid).notifier);
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
        (state) => state.copyWith(
          matchedDeliveryBoy: true,
          loading: false,
        ),
      );
    } catch (err) {
      if (!mounted) return;
      _updateUi((state) => state.copyWith(error: err.toString(), loading: false));
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
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return const SignUpScreen();
  }
}

final _autoProvisionUiProvider =
    StateProvider.autoDispose.family<_AutoProvisionUiState, String>(
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
  const _BlockedUserScreen();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Your account is blocked by admin.'),
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
