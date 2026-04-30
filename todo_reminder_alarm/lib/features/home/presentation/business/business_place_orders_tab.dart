part of 'business_home.dart';

class _PlaceOrdersTab extends ConsumerWidget {
  const _PlaceOrdersTab({required this.profile, required this.ownBusiness});

  final AppUser profile;
  final BusinessProfile? ownBusiness;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _PlaceOrdersBody(profile: profile, ownBusiness: ownBusiness);
  }
}

class _PlaceOrdersBody extends ConsumerStatefulWidget {
  const _PlaceOrdersBody({required this.profile, required this.ownBusiness});

  final AppUser profile;
  final BusinessProfile? ownBusiness;

  @override
  ConsumerState<_PlaceOrdersBody> createState() => _PlaceOrdersBodyState();
}

class _PlaceOrdersBodyState extends ConsumerState<_PlaceOrdersBody> {
  final TextEditingController _searchController = TextEditingController();
  late final String _uiKey;

  @override
  void initState() {
    super.initState();
    _uiKey = widget.profile.id;
    _searchController.text = ref.read(_placeOrdersUiProvider(_uiKey)).searchQuery;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ui = ref.watch(_placeOrdersUiProvider(_uiKey));
    final currentUid = ref.watch(authStateProvider).value?.uid ?? widget.profile.id;
    final liveProfile = ref.watch(userProfileProvider(currentUid)).asData?.value ??
        widget.profile;
    final favoriteBusinessIds = liveProfile.favoriteBusinessIds.toSet();
    final businessesAsync = ref.watch(approvedBusinessesProvider);
    final businessById = {
      for (final business
          in businessesAsync.asData?.value ?? const <BusinessProfile>[])
        business.id: business,
    };
    final outgoingAsync = ref.watch(
      ordersPlacedByBusinessOwnerProvider(widget.profile.id),
    );
    final outgoingOrders = outgoingAsync.asData?.value ?? const <Order>[];

    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          const SizedBox(height: 8),
          const TabBar(
            tabs: [
              Tab(text: 'Businesses'),
              Tab(text: 'Orders Placed'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _buildBusinessesTab(
                  context,
                  ui,
                  currentUid,
                  favoriteBusinessIds,
                  businessesAsync,
                  outgoingOrders,
                ),
                _buildPlacedOrdersTab(context, ui, outgoingAsync, businessById),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
