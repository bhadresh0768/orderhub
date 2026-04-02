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

  String _formatDate(DateTime date) {
    final local = date.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    return '$day-$month-${local.year}';
  }

  String _subscriptionAlertText(DateTime subscriptionEndDate, DateTime now) {
    final endDate = DateTime(
      subscriptionEndDate.year,
      subscriptionEndDate.month,
      subscriptionEndDate.day,
    );
    final currentDate = DateTime(now.year, now.month, now.day);
    final daysLeft = endDate.difference(currentDate).inDays;
    final dayLabel = daysLeft == 1 ? 'day' : 'days';
    return 'Subscription ending in $daysLeft $dayLabel '
        'on ${_formatDate(subscriptionEndDate)}. Please renew before expiry.';
  }

  Future<void> _submitRenewalRequest(
    BuildContext context,
    WidgetRef ref, {
    required BusinessProfile business,
  }) async {
    final shouldSubmit = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Renewal Request'),
        content: Text(
          'Send a subscription renewal request for ${business.name} to admin?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    if (shouldSubmit != true) return;

    try {
      final request = SubscriptionRenewalRequest(
        id: const Uuid().v4(),
        businessId: business.id,
        businessName: business.name,
        ownerId: profile.id,
        ownerName: profile.name,
        ownerEmail: profile.email,
        ownerPhone: profile.phoneNumber,
        businessCity: business.city,
        status: 'pending',
        subscriptionEndDate: business.subscriptionEndDate,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await ref
          .read(firestoreServiceProvider)
          .createSubscriptionRenewalRequest(request);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Renewal request sent to admin successfully.'),
        ),
      );
    } on FirebaseException catch (err) {
      if (!context.mounted) return;
      final message = err.code == 'permission-denied'
          ? 'Renewal request could not be sent. Firestore rules for subscription renewal requests need to be deployed.'
          : 'Failed to send renewal request: ${err.message ?? err.code}';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } catch (err) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to send renewal request: $err')),
      );
    }
  }

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
    final now = DateTime.now();
    final subscriptionEndDate = ownBusiness?.subscriptionEndDate;
    final showSubscriptionAlert =
        ownBusiness != null &&
        ownBusiness.subscriptionActive &&
        subscriptionEndDate != null &&
        !now.isAfter(subscriptionEndDate) &&
        !subscriptionEndDate.isAfter(now.add(const Duration(days: 30)));
    final fiscalBannerDismissed = ownBusiness == null
        ? true
        : ref.watch(_fiscalYearBannerDismissedProvider(ownBusiness.id));
    final showFiscalYearBanner =
        ownBusiness != null &&
        ownBusiness.fiscalYearStartMonth == null &&
        !fiscalBannerDismissed;

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
        body: Column(
          children: [
            if (showFiscalYearBanner)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.amber.shade300),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.event_note_outlined,
                        color: Colors.amber.shade900,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Set your financial year start month to keep future order numbering correct.',
                              style: TextStyle(
                                color: Colors.amber.shade900,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              children: [
                                OutlinedButton(
                                  onPressed: () {
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            ProfileScreen(user: profile),
                                      ),
                                    );
                                  },
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.amber.shade900,
                                    side: BorderSide(
                                      color: Colors.amber.shade400,
                                    ),
                                  ),
                                  child: const Text('Open Profile Settings'),
                                ),
                                TextButton(
                                  onPressed: () {
                                    ref
                                            .read(
                                              _fiscalYearBannerDismissedProvider(
                                                ownBusiness!.id,
                                              ).notifier,
                                            )
                                            .state =
                                        true;
                                  },
                                  child: const Text('Later'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            if (showSubscriptionAlert)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red.shade300),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.warning_amber_rounded,
                        color: Colors.red.shade700,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _subscriptionAlertText(subscriptionEndDate, now),
                              style: TextStyle(
                                color: Colors.red.shade800,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 10),
                            OutlinedButton(
                              onPressed: () => _submitRenewalRequest(
                                context,
                                ref,
                                business: ownBusiness!,
                              ),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.red.shade800,
                                side: BorderSide(color: Colors.red.shade300),
                              ),
                              child: const Text('Contact Now'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            Expanded(
              child: TabBarView(
                children: [
                  _BusinessOrdersSection(profile: profile),
                  _PlaceOrdersTab(profile: profile, ownBusiness: ownBusiness),
                  _DeliveryTeamTab(profile: profile),
                  BusinessCatalogScreen(businessId: profile.businessId!),
                ],
              ),
            ),
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
