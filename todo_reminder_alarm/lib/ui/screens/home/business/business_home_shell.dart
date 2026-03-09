part of 'business_home.dart';

class BusinessHomeScreen extends ConsumerWidget {
  const BusinessHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider).value;
    if (authState == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final profileAsync = ref.watch(userProfileProvider(authState.uid));
    return profileAsync.when(
      data: (profile) {
        if (profile == null || profile.businessId == null) {
          return const Scaffold(
            body: Center(child: Text('No business linked')),
          );
        }
        return _BusinessHomeBody(profile: profile);
      },
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (_, _) => Scaffold(
        body: Center(child: Text('Something went wrong. Please retry.')),
      ),
    );
  }
}

class _BusinessHomeBody extends ConsumerWidget {
  const _BusinessHomeBody({required this.profile});

  final AppUser profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final incomingAsync = ref.watch(
      ordersForBusinessProvider(profile.businessId!),
    );
    final outgoingAsync = ref.watch(
      ordersPlacedByBusinessOwnerProvider(profile.id),
    );
    final businessesAsync = ref.watch(businessesProvider);
    BusinessProfile? ownBusiness;
    final availableBusinesses = businessesAsync.value;
    if (availableBusinesses != null) {
      for (final business in availableBusinesses) {
        if (business.id == profile.businessId) {
          ownBusiness = business;
          break;
        }
      }
    }
    final incomingOrders = incomingAsync.value ?? const <Order>[];
    final hasUpcoming = incomingOrders.any(
      (order) =>
          OrderSharedHelpers.effectiveStatus(
            order,
            normalizeApprovedToInProgress: true,
          ) ==
          OrderStatus.pending,
    );
    final hasProcessing = incomingOrders.any(
      (order) =>
          OrderSharedHelpers.effectiveStatus(
            order,
            normalizeApprovedToInProgress: true,
          ) ==
          OrderStatus.inProgress,
    );
    final Color? newOrdersIndicatorColor = hasUpcoming
        ? Colors.red
        : (hasProcessing ? Colors.orange : null);

    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Dashboard'),
          bottom: TabBar(
            isScrollable: true,
            tabs: <Widget>[
              Tab(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('New Orders'),
                    if (newOrdersIndicatorColor != null) ...[
                      const SizedBox(width: 6),
                      _BlinkingDot(color: newOrdersIndicatorColor),
                    ],
                  ],
                ),
              ),
              const Tab(text: 'Place Orders'),
              const Tab(text: 'Delivery Team'),
              const Tab(text: 'Catalog'),
            ],
          ),
        ),
        drawer: _buildDrawer(
          context: context,
          ref: ref,
          incomingOrders: incomingOrders,
          outgoingOrders: outgoingAsync.value ?? const [],
        ),
        body: TabBarView(
          children: [
            _BusinessOrdersSection(profile: profile),
            _PlaceOrdersTab(profile: profile, ownBusiness: ownBusiness),
            _DeliveryTeamTab(profile: profile),
            BusinessCatalogScreen(businessId: profile.businessId!),
          ],
        ),
      ),
    );
  }

  Drawer _buildDrawer({
    required BuildContext context,
    required WidgetRef ref,
    required List<Order> incomingOrders,
    required List<Order> outgoingOrders,
  }) {
    final orders = [...incomingOrders, ...outgoingOrders];
    return Drawer(
      backgroundColor: Colors.white,
      child: SafeArea(
        child: ListView(
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Text('Menu', style: TextStyle(fontSize: 24)),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.person_outline),
              title: const Text('Profile'),
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ProfileScreen(user: profile),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.assessment_outlined),
              title: const Text('Report & History'),
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => OrderHistoryReportScreen(
                      title: 'Business History & Reports',
                      orders: orders,
                    ),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.support_agent),
              title: const Text('Help & Support'),
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => SupportTicketsScreen(user: profile),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.contact_phone_outlined),
              title: const Text('Contact Us'),
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ContactUsScreen(user: profile),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.group_add_outlined),
              title: const Text('Invite Friends'),
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const InviteFriendsScreen(),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.privacy_tip_outlined),
              title: const Text('Privacy Policy'),
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const PrivacyPolicyScreen(),
                  ),
                );
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Logout'),
              onTap: () {
                Navigator.of(context).pop();
                ref.read(authServiceProvider).signOut();
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _BlinkingDot extends StatefulWidget {
  const _BlinkingDot({required this.color});

  final Color color;

  @override
  State<_BlinkingDot> createState() => _BlinkingDotState();
}

class _BlinkingDotState extends State<_BlinkingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
      lowerBound: 0.2,
      upperBound: 1,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _controller,
      child: Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(shape: BoxShape.circle, color: widget.color),
      ),
    );
  }
}
