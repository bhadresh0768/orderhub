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
    _searchController.text = ref
        .read(_placeOrdersUiProvider(_uiKey))
        .searchQuery;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<BusinessProfile> _filterBusinesses(List<BusinessProfile> businesses) {
    final ui = ref.read(_placeOrdersUiProvider(_uiKey));
    final query = ui.searchQuery.trim().toLowerCase();
    return businesses.where((business) {
      final categoryOk =
          ui.categoryFilter == 'All' || business.category == ui.categoryFilter;
      final cityOk = ui.cityFilter == 'All' || business.city == ui.cityFilter;
      final matchesQuery =
          query.isEmpty ||
          business.name.toLowerCase().contains(query) ||
          business.category.toLowerCase().contains(query) ||
          (business.address ?? '').toLowerCase().contains(query) ||
          business.city.toLowerCase().contains(query);
      return categoryOk && cityOk && matchesQuery;
    }).toList();
  }

  List<String> _recentBusinessIds(List<Order> orders) {
    final sorted = [...orders]
      ..sort((a, b) {
        final ad =
            a.updatedAt ??
            a.createdAt ??
            DateTime.fromMillisecondsSinceEpoch(0);
        final bd =
            b.updatedAt ??
            b.createdAt ??
            DateTime.fromMillisecondsSinceEpoch(0);
        return bd.compareTo(ad);
      });
    final seen = <String>{};
    final ids = <String>[];
    for (final order in sorted) {
      final id = order.businessId.trim();
      if (id.isEmpty || seen.contains(id)) continue;
      seen.add(id);
      ids.add(id);
    }
    return ids;
  }

  List<BusinessProfile> _sortBusinessesForUser(
    List<BusinessProfile> businesses, {
    required Set<String> favoriteIds,
    required List<String> recentBusinessIds,
  }) {
    final recentIndex = {
      for (var i = 0; i < recentBusinessIds.length; i++)
        recentBusinessIds[i]: i,
    };
    final sorted = [...businesses];
    sorted.sort((a, b) {
      final favA = favoriteIds.contains(a.id);
      final favB = favoriteIds.contains(b.id);
      if (favA != favB) return favA ? -1 : 1;
      final recentA = recentIndex[a.id];
      final recentB = recentIndex[b.id];
      if (recentA != null && recentB != null) {
        final byRecent = recentA.compareTo(recentB);
        if (byRecent != 0) return byRecent;
      } else if (recentA != null || recentB != null) {
        return recentA != null ? -1 : 1;
      }
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return sorted;
  }

  DateTime _effectiveOrderDate(Order order) {
    return order.createdAt ?? order.updatedAt ?? DateTime.now();
  }

  bool _matchesPlacedDateFilter(
    Order order,
    OrderDateFilterOption filter,
    DateTime now,
    _PlaceOrdersUiState ui,
  ) {
    if (filter == OrderDateFilterOption.all) return true;
    final effectiveDate = _effectiveOrderDate(order);
    return OrderSharedHelpers.matchesDateFilter(
      effectiveDate,
      filter,
      now,
      customFrom: ui.placedFromDate,
      customTo: ui.placedToDate,
    );
  }

  Future<void> _pickPlacedCustomRange(_PlaceOrdersUiState ui) async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year + 2),
      initialDateRange: (ui.placedFromDate != null && ui.placedToDate != null)
          ? DateTimeRange(start: ui.placedFromDate!, end: ui.placedToDate!)
          : null,
    );
    if (picked == null || !mounted) return;
    ref.read(_placeOrdersUiProvider(_uiKey).notifier).state = ui.copyWith(
      placedDateFilter: OrderDateFilterOption.custom,
      placedFromDate: picked.start,
      placedToDate: picked.end,
    );
  }

  bool _canEditOrder(Order order) {
    return order.status == OrderStatus.pending &&
        order.delivery.status == DeliveryStatus.pending;
  }

  void _onOutgoingOrderPlaced(String? orderLabel) {
    if (orderLabel == null || !mounted) return;
    final tabController = DefaultTabController.of(context);
    tabController.animateTo(1);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('$orderLabel placed successfully')));
  }

  Future<void> _editPlacedOrder(
    Order order,
    Map<String, BusinessProfile> businessById,
  ) async {
    final business = businessById[order.businessId];
    if (business == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Store not found for edit')));
      return;
    }
    final updatedOrderId = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => CreateOrderScreen(
          business: business,
          customer: widget.profile,
          requesterBusiness: widget.ownBusiness,
          existingOrder: order,
        ),
      ),
    );
    if (!mounted || updatedOrderId == null) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Order ${order.displayOrderNumber} updated successfully'),
      ),
    );
  }

  Future<void> _deletePlacedOrder(Order order) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Order'),
        content: Text(
          'Delete Order ${order.displayOrderNumber}? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    try {
      await ref.read(firestoreServiceProvider).deleteOrder(order.id);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Order deleted')));
    } catch (err) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to delete order: $err')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final ui = ref.watch(_placeOrdersUiProvider(_uiKey));
    final currentUid =
        ref.watch(authStateProvider).value?.uid ?? widget.profile.id;
    final liveProfile =
        ref.watch(userProfileProvider(currentUid)).asData?.value ??
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
                businessesAsync.when(
                  data: (businesses) {
                    final options = businesses
                        .where(
                          (business) =>
                              business.id != widget.profile.businessId,
                        )
                        .toList();
                    final categories = <String>{
                      'All',
                      ...options.map((e) => e.category),
                    };
                    final normalizedCities =
                        options
                            .map((e) => e.city.trim())
                            .where((city) => city.isNotEmpty)
                            .toSet()
                            .toList()
                          ..sort(
                            (a, b) =>
                                a.toLowerCase().compareTo(b.toLowerCase()),
                          );
                    final cities = ['All', ...normalizedCities];
                    final ownCity = (widget.ownBusiness?.city ?? '').trim();
                    if (ui.cityFilter == 'All' &&
                        ownCity.isNotEmpty &&
                        cities.contains(ownCity)) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (!mounted) return;
                        final current = ref.read(
                          _placeOrdersUiProvider(_uiKey),
                        );
                        if (current.cityFilter == 'All') {
                          ref
                              .read(_placeOrdersUiProvider(_uiKey).notifier)
                              .state = current.copyWith(
                            cityFilter: ownCity,
                          );
                        }
                      });
                    }
                    final filtered = _filterBusinesses(options);
                    final sortedBusinesses = _sortBusinessesForUser(
                      filtered,
                      favoriteIds: favoriteBusinessIds,
                      recentBusinessIds: _recentBusinessIds(outgoingOrders),
                    );
                    if (options.isEmpty) {
                      return const Center(
                        child: Text('No other businesses available.'),
                      );
                    }
                    return ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        Text(
                          'Order from Other Businesses',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 12),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final isNarrow = constraints.maxWidth < 700;
                            if (isNarrow) {
                              return Column(
                                children: [
                                  TextField(
                                    controller: _searchController,
                                    decoration: const InputDecoration(
                                      labelText:
                                          'Search business/category/address/city',
                                      prefixIcon: Icon(Icons.search),
                                    ),
                                    onChanged: (value) {
                                      ref
                                          .read(
                                            _placeOrdersUiProvider(
                                              _uiKey,
                                            ).notifier,
                                          )
                                          .state = ui.copyWith(
                                        searchQuery: value,
                                      );
                                    },
                                  ),
                                  const SizedBox(height: 10),
                                  DropdownButtonFormField<String>(
                                    isExpanded: true,
                                    initialValue: ui.categoryFilter,
                                    decoration: const InputDecoration(
                                      labelText: 'Category',
                                    ),
                                    items: categories
                                        .map(
                                          (value) => DropdownMenuItem(
                                            value: value,
                                            child: Text(value),
                                          ),
                                        )
                                        .toList(),
                                    onChanged: (value) {
                                      ref
                                          .read(
                                            _placeOrdersUiProvider(
                                              _uiKey,
                                            ).notifier,
                                          )
                                          .state = ui.copyWith(
                                        categoryFilter: value ?? 'All',
                                      );
                                    },
                                  ),
                                  const SizedBox(height: 10),
                                  DropdownButtonFormField<String>(
                                    isExpanded: true,
                                    initialValue: ui.cityFilter,
                                    decoration: const InputDecoration(
                                      labelText: 'City',
                                    ),
                                    items: cities
                                        .map(
                                          (value) => DropdownMenuItem(
                                            value: value,
                                            child: Text(value),
                                          ),
                                        )
                                        .toList(),
                                    onChanged: (value) {
                                      ref
                                          .read(
                                            _placeOrdersUiProvider(
                                              _uiKey,
                                            ).notifier,
                                          )
                                          .state = ui.copyWith(
                                        cityFilter: value ?? 'All',
                                      );
                                    },
                                  ),
                                ],
                              );
                            }
                            return Row(
                              children: [
                                Expanded(
                                  flex: 3,
                                  child: TextField(
                                    controller: _searchController,
                                    decoration: const InputDecoration(
                                      labelText:
                                          'Search business/category/address/city',
                                      prefixIcon: Icon(Icons.search),
                                    ),
                                    onChanged: (value) {
                                      ref
                                          .read(
                                            _placeOrdersUiProvider(
                                              _uiKey,
                                            ).notifier,
                                          )
                                          .state = ui.copyWith(
                                        searchQuery: value,
                                      );
                                    },
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: DropdownButtonFormField<String>(
                                    isExpanded: true,
                                    initialValue: ui.categoryFilter,
                                    decoration: const InputDecoration(
                                      labelText: 'Category',
                                    ),
                                    items: categories
                                        .map(
                                          (value) => DropdownMenuItem(
                                            value: value,
                                            child: Text(value),
                                          ),
                                        )
                                        .toList(),
                                    onChanged: (value) {
                                      ref
                                          .read(
                                            _placeOrdersUiProvider(
                                              _uiKey,
                                            ).notifier,
                                          )
                                          .state = ui.copyWith(
                                        categoryFilter: value ?? 'All',
                                      );
                                    },
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: DropdownButtonFormField<String>(
                                    isExpanded: true,
                                    initialValue: ui.cityFilter,
                                    decoration: const InputDecoration(
                                      labelText: 'City',
                                    ),
                                    items: cities
                                        .map(
                                          (value) => DropdownMenuItem(
                                            value: value,
                                            child: Text(value),
                                          ),
                                        )
                                        .toList(),
                                    onChanged: (value) {
                                      ref
                                          .read(
                                            _placeOrdersUiProvider(
                                              _uiKey,
                                            ).notifier,
                                          )
                                          .state = ui.copyWith(
                                        cityFilter: value ?? 'All',
                                      );
                                    },
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 12),
                        if (filtered.isEmpty)
                          const Align(
                            alignment: Alignment.centerLeft,
                            child: Text('No businesses match current filters.'),
                          ),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final isWide = constraints.maxWidth >= 900;
                            final crossAxisCount = isWide ? 2 : 1;
                            final cardExtent = isWide ? 206.0 : 214.0;
                            final cardPadding = isWide ? 12.0 : 10.0;
                            final titleStyle = isWide
                                ? Theme.of(context).textTheme.titleLarge
                                : Theme.of(context).textTheme.titleMedium;
                            return GridView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: sortedBusinesses.length,
                              gridDelegate:
                                  SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: crossAxisCount,
                                    crossAxisSpacing: 12,
                                    mainAxisSpacing: 12,
                                    mainAxisExtent: cardExtent,
                                  ),
                              itemBuilder: (context, index) {
                                final business = sortedBusinesses[index];
                                final isFavorite = favoriteBusinessIds.contains(
                                  business.id,
                                );
                                final ownerName = (business.ownerName ?? '')
                                    .trim();
                                return Card(
                                  child: Padding(
                                    padding: EdgeInsets.all(cardPadding),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Expanded(
                                                    child: Text(
                                                      business.name,
                                                      style: titleStyle,
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                  IconButton(
                                                    tooltip: isFavorite
                                                        ? 'Remove from favorites'
                                                        : 'Pin to favorites',
                                                    onPressed: () async {
                                                      await ref
                                                          .read(
                                                            firestoreServiceProvider,
                                                          )
                                                          .setCustomerFavoriteBusiness(
                                                            userId: currentUid,
                                                            businessId:
                                                                business.id,
                                                            isFavorite:
                                                                !isFavorite,
                                                          );
                                                    },
                                                    icon: Icon(
                                                      isFavorite
                                                          ? Icons.push_pin
                                                          : Icons
                                                                .push_pin_outlined,
                                                      color: isFavorite
                                                          ? Theme.of(context)
                                                                .colorScheme
                                                                .primary
                                                          : Colors
                                                                .grey
                                                                .shade600,
                                                    ),
                                                    iconSize: 20,
                                                    padding: EdgeInsets.zero,
                                                    constraints:
                                                        const BoxConstraints(),
                                                  ),
                                                ],
                                              ),
                                              if (ownerName.isNotEmpty) ...[
                                                Text(
                                                  'By $ownerName',
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .bodySmall
                                                      ?.copyWith(
                                                        color: Colors.black54,
                                                        fontSize:
                                                            ((Theme.of(context)
                                                                    .textTheme
                                                                    .bodySmall
                                                                    ?.fontSize ??
                                                                12) +
                                                            3),
                                                      ),
                                                ),
                                              ],
                                              const SizedBox(height: 2),
                                              Wrap(
                                                spacing: 6,
                                                children: [
                                                  Chip(
                                                    visualDensity:
                                                        VisualDensity.compact,
                                                    materialTapTargetSize:
                                                        MaterialTapTargetSize
                                                            .shrinkWrap,
                                                    label: Text(
                                                      business.category,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                '${(business.address ?? '').trim().isEmpty ? '-' : business.address!.trim()}, ${business.city}',
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Row(
                                          children: [
                                            Expanded(
                                              child: FilledButton(
                                                onPressed:
                                                    widget.ownBusiness == null
                                                    ? null
                                                    : () async {
                                                        final orderId =
                                                            await Navigator.of(
                                                              context,
                                                            ).push<String>(
                                                              MaterialPageRoute(
                                                                builder: (_) => CreateOrderScreen(
                                                                  business:
                                                                      business,
                                                                  customer: widget
                                                                      .profile,
                                                                  requesterBusiness:
                                                                      widget
                                                                          .ownBusiness,
                                                                ),
                                                              ),
                                                            );
                                                        _onOutgoingOrderPlaced(
                                                          orderId,
                                                        );
                                                      },
                                                child: const Text(
                                                  'Place Order',
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: OutlinedButton(
                                                onPressed: () async {
                                                  final orderId =
                                                      await Navigator.of(
                                                        context,
                                                      ).push<String>(
                                                        MaterialPageRoute(
                                                          builder: (_) =>
                                                              CustomerCatalogScreen(
                                                                business:
                                                                    business,
                                                                customer: widget
                                                                    .profile,
                                                                requesterBusiness:
                                                                    widget
                                                                        .ownBusiness,
                                                              ),
                                                        ),
                                                      );
                                                  _onOutgoingOrderPlaced(
                                                    orderId,
                                                  );
                                                },
                                                child: const Text('Catalog'),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            SizedBox(
                                              width: 52,
                                              child: IconButton(
                                                onPressed: () {
                                                  Navigator.of(context).push(
                                                    MaterialPageRoute(
                                                      builder: (_) =>
                                                          PublicBusinessProfileScreen(
                                                            business: business,
                                                          ),
                                                    ),
                                                  );
                                                },
                                                iconSize: 30,
                                                icon: const Icon(
                                                  Icons.storefront_outlined,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            );
                          },
                        ),
                      ],
                    );
                  },
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (_, _) => const Center(
                    child: Text('Something went wrong. Please retry.'),
                  ),
                ),
                outgoingAsync.when(
                  data: (orders) {
                    final now = DateTime.now();
                    final filteredOrders = orders.where((order) {
                      return _matchesPlacedDateFilter(
                        order,
                        ui.placedDateFilter,
                        now,
                        ui,
                      );
                    }).toList();
                    return ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        Text(
                          'Orders I Placed',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<OrderDateFilterOption>(
                          initialValue: ui.placedDateFilter,
                          decoration: const InputDecoration(
                            labelText: 'Date Filter',
                          ),
                          items: OrderDateFilterOption.values
                              .map(
                                (filter) => DropdownMenuItem(
                                  value: filter,
                                  child: Text(
                                    OrderSharedHelpers.dateFilterLabel(filter),
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (value) {
                            if (value == null) return;
                            ref
                                .read(_placeOrdersUiProvider(_uiKey).notifier)
                                .state = ui.copyWith(
                              placedDateFilter: value,
                            );
                            if (value == OrderDateFilterOption.custom &&
                                (ui.placedFromDate == null ||
                                    ui.placedToDate == null)) {
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                if (!mounted) return;
                                _pickPlacedCustomRange(
                                  ref.read(_placeOrdersUiProvider(_uiKey)),
                                );
                              });
                            }
                          },
                        ),
                        if (ui.placedDateFilter ==
                            OrderDateFilterOption.custom) ...[
                          const SizedBox(height: 8),
                          OrderDateRangeRow(
                            fromDate: ui.placedFromDate,
                            toDate: ui.placedToDate,
                            onSelect: () => _pickPlacedCustomRange(ui),
                            onClear: () {
                              ref
                                  .read(_placeOrdersUiProvider(_uiKey).notifier)
                                  .state = ui.copyWith(
                                placedFromDate: null,
                                placedToDate: null,
                              );
                            },
                          ),
                        ],
                        const SizedBox(height: 12),
                        if (filteredOrders.isEmpty)
                          const Padding(
                            padding: EdgeInsets.only(top: 24),
                            child: Center(
                              child: Text(
                                'No outgoing orders for selected filter.',
                              ),
                            ),
                          ),
                        ...filteredOrders.map((order) {
                          final effectiveStatus =
                              OrderSharedHelpers.effectiveStatus(order);
                          final canEdit = _canEditOrder(order);
                          final isFast = order.priority == OrderPriority.fast;
                          final priorityColor = isFast
                              ? Colors.red
                              : Theme.of(context).colorScheme.onSurface;
                          final cardIconColor = Colors.grey.shade600;
                          final orderDateLabel = order.createdAt == null
                              ? null
                              : OrderSharedHelpers.formatDateTime(
                                  order.createdAt!,
                                );
                          final statusColor = OrderSharedHelpers.statusColor(
                            effectiveStatus,
                          );
                          final paymentDone =
                              order.payment.status == PaymentStatus.done;
                          final paymentLabel = paymentDone
                              ? 'Payment Done'
                              : 'Payment Pending';
                          final paymentBg = paymentDone
                              ? Colors.blueGrey.shade50
                              : Colors.red.shade100;
                          final paymentFg = paymentDone
                              ? Colors.blueGrey.shade800
                              : Colors.red.shade800;
                          final deliveryDelivered =
                              order.delivery.status == DeliveryStatus.delivered;
                          final deliveryLabel = OrderSharedHelpers.capitalize(
                            order.delivery.status.name,
                          );
                          final deliveryBg = deliveryDelivered
                              ? Colors.green.shade100
                              : Colors.grey.shade200;
                          final deliveryFg = deliveryDelivered
                              ? Colors.green.shade700
                              : Colors.grey.shade800;
                          final amountText = OrderSharedHelpers.amountLabel(
                            order.payment.amount,
                          );
                          return OrderCardShell(
                            isHighlighted: isFast,
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) =>
                                      CustomerOrderDetailScreen(order: order),
                                ),
                              );
                            },
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(
                                16,
                                14,
                                10,
                                14,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                order.businessName,
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .titleMedium
                                                    ?.copyWith(
                                                      fontWeight:
                                                          FontWeight.w600,
                                                    ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      PopupMenuButton<String>(
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                        iconSize: 22,
                                        iconColor: cardIconColor,
                                        tooltip: canEdit
                                            ? 'Order actions'
                                            : 'Locked: accepted orders cannot be edited/deleted',
                                        onSelected: (value) async {
                                          if (value == 'edit') {
                                            await _editPlacedOrder(
                                              order,
                                              businessById,
                                            );
                                          } else if (value == 'delete') {
                                            await _deletePlacedOrder(order);
                                          }
                                        },
                                        itemBuilder: (_) => [
                                          const PopupMenuItem(
                                            value: '__help__',
                                            enabled: false,
                                            child: Text(
                                              'Editable only while order is New',
                                            ),
                                          ),
                                          PopupMenuItem(
                                            value: 'edit',
                                            enabled: canEdit,
                                            child: const Text('Edit Order'),
                                          ),
                                          PopupMenuItem(
                                            value: 'delete',
                                            enabled: canEdit,
                                            child: const Text('Delete Order'),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Row(
                                          children: [
                                            Icon(
                                              Icons.receipt_long_outlined,
                                              size: 18,
                                              color: cardIconColor,
                                            ),
                                            const SizedBox(width: 4),
                                            Expanded(
                                              child: Text(
                                                order.displayOrderNumber,
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .bodyMedium
                                                    ?.copyWith(
                                                      fontWeight:
                                                          FontWeight.w700,
                                                    ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      if (orderDateLabel != null)
                                        Expanded(
                                          child: Row(
                                            children: [
                                              Icon(
                                                Icons.schedule,
                                                size: 18,
                                                color: cardIconColor,
                                              ),
                                              const SizedBox(width: 4),
                                              Expanded(
                                                child: Text(
                                                  orderDateLabel,
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Icon(
                                        isFast
                                            ? Icons.bolt_outlined
                                            : Icons.speed_outlined,
                                        size: 18,
                                        color: cardIconColor,
                                      ),
                                      const SizedBox(width: 4),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: priorityColor.withValues(
                                            alpha: 0.12,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                        child: Text(
                                          OrderSharedHelpers.capitalize(
                                            order.priority.name,
                                          ),
                                          style: TextStyle(
                                            color: priorityColor,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.local_shipping_outlined,
                                        size: 18,
                                        color: cardIconColor,
                                      ),
                                      const SizedBox(width: 4),
                                      Expanded(
                                        child: Wrap(
                                          spacing: 8,
                                          runSpacing: 8,
                                          children: [
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 10,
                                                    vertical: 4,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: paymentBg,
                                                borderRadius:
                                                    BorderRadius.circular(14),
                                              ),
                                              child: Text(
                                                paymentLabel,
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .bodySmall
                                                    ?.copyWith(
                                                      color: paymentFg,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                    ),
                                              ),
                                            ),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 10,
                                                    vertical: 4,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: deliveryBg,
                                                borderRadius:
                                                    BorderRadius.circular(14),
                                              ),
                                              child: Text(
                                                deliveryLabel,
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .bodySmall
                                                    ?.copyWith(
                                                      color: deliveryFg,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                    ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Divider(
                                    height: 1,
                                    color: Colors.grey.shade200,
                                  ),
                                  const SizedBox(height: 8),
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: Text(
                                      'Amount: $amountText',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }),
                      ],
                    );
                  },
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (_, _) => const Center(
                    child: Text('Something went wrong. Please retry.'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
