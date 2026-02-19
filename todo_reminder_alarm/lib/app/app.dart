import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/app_user.dart';
import '../models/business.dart';
import '../models/enums.dart';
import '../providers.dart';
import 'order_status_listener.dart';
import '../ui/screens/auth/login_screen.dart';
import '../ui/screens/auth/signup_screen.dart';
import '../ui/screens/home/admin_home.dart';
import '../ui/screens/home/business_home.dart';
import '../ui/screens/home/customer_home.dart';
import '../ui/screens/home/delivery_boy_home.dart';
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
      routes: {
        '/': (_) => const OrderStatusListener(child: AuthGate()),
        LoginScreen.routeName: (_) => const LoginScreen(),
        SignUpScreen.routeName: (_) => const SignUpScreen(),
      },
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
  bool _loading = true;
  bool _matchedDeliveryBoy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _provisionIfDeliveryBoy();
  }

  Future<void> _provisionIfDeliveryBoy() async {
    try {
      final phone = widget.user.phoneNumber?.trim() ?? '';
      if (phone.isEmpty) {
        setState(() => _loading = false);
        return;
      }
      final firestore = ref.read(firestoreServiceProvider);
      final agent = await firestore.findActiveDeliveryAgentByPhone(phone);
      if (agent == null) {
        setState(() => _loading = false);
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
      setState(() {
        _matchedDeliveryBoy = true;
        _loading = false;
      });
    } catch (err) {
      if (!mounted) return;
      setState(() {
        _error = err.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_error != null) {
      return Scaffold(body: Center(child: Text('Error: $_error')));
    }
    if (_matchedDeliveryBoy) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return const SignUpScreen();
  }
}

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
