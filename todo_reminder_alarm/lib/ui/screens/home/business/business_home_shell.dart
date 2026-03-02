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

    return DefaultTabController(
      length: 6,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Dashboard'),
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: 'New Orders'),
              Tab(text: 'Processing'),
              Tab(text: 'Completed'),
              Tab(text: 'Place Orders'),
              Tab(text: 'Delivery Team'),
              Tab(text: 'Catalog'),
            ],
          ),
        ),
        drawer: _buildDrawer(
          context: context,
          ref: ref,
          incomingOrders: incomingAsync.value ?? const [],
          outgoingOrders: outgoingAsync.value ?? const [],
        ),
        body: TabBarView(
          children: [
            _BusinessOrdersTab(
              profile: profile,
              emptyMessage: 'No new incoming orders.',
              allowedStatuses: [OrderStatus.pending],
              allowActions: true,
            ),
            _BusinessOrdersTab(
              profile: profile,
              emptyMessage: 'No processing orders.',
              allowedStatuses: [OrderStatus.inProgress],
              allowActions: true,
            ),
            _BusinessOrdersTab(
              profile: profile,
              emptyMessage: 'No completed orders.',
              allowedStatuses: [OrderStatus.completed],
              allowActions: false,
            ),
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
