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
      final matchesQuery =
          query.isEmpty ||
          business.name.toLowerCase().contains(query) ||
          business.category.toLowerCase().contains(query) ||
          (business.address ?? '').toLowerCase().contains(query) ||
          business.city.toLowerCase().contains(query);
      return categoryOk && matchesQuery;
    }).toList();
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
    final businessesAsync = ref.watch(businessesProvider);
    final businessById = {
      for (final business
          in businessesAsync.asData?.value ?? const <BusinessProfile>[])
        business.id: business,
    };
    final outgoingAsync = ref.watch(
      ordersPlacedByBusinessOwnerProvider(widget.profile.id),
    );

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
                              business.id != widget.profile.businessId &&
                              business.status != BusinessStatus.suspended,
                        )
                        .toList();
                    final categories = <String>{
                      'All',
                      ...options.map((e) => e.category),
                    };
                    final filtered = _filterBusinesses(options);
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
                            return GridView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: filtered.length,
                              gridDelegate:
                                  SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: crossAxisCount,
                                    crossAxisSpacing: 12,
                                    mainAxisSpacing: 12,
                                    mainAxisExtent: 190,
                                  ),
                              itemBuilder: (context, index) {
                                final business = filtered[index];
                                return Card(
                                  child: Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          business.name,
                                          style: Theme.of(
                                            context,
                                          ).textTheme.titleLarge,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 4),
                                        Wrap(
                                          spacing: 8,
                                          children: [
                                            Chip(
                                              label: Text(business.category),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          '${(business.address ?? '').trim().isEmpty ? '-' : business.address!.trim()}, ${business.city}',
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const Spacer(),
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
                          final statusColor = OrderSharedHelpers.statusColor(
                            effectiveStatus,
                          );
                          return OrderCardShell(
                            isHighlighted: isFast,
                            child: ListTile(
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        CustomerOrderDetailScreen(order: order),
                                  ),
                                );
                              },
                              title: Text(
                                '${order.businessName} • ${OrderSharedHelpers.statusLabel(effectiveStatus)}',
                              ),
                              subtitleTextStyle: Theme.of(
                                context,
                              ).textTheme.bodyLarge,
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Order ${order.displayOrderNumber}'),
                                  Text.rich(
                                    TextSpan(
                                      children: [
                                        const TextSpan(
                                          text: 'Delivery Priority: ',
                                        ),
                                        TextSpan(
                                          text: OrderSharedHelpers.capitalize(
                                            order.priority.name,
                                          ),
                                          style: TextStyle(
                                            color: priorityColor,
                                            fontWeight: isFast
                                                ? FontWeight.w700
                                                : FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Text(
                                    'Payment: ${OrderSharedHelpers.capitalize(order.payment.status.name)} | '
                                    'Delivery: ${OrderSharedHelpers.capitalize(order.delivery.status.name)}',
                                  ),
                                ],
                              ),
                              isThreeLine: true,
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  OrderStatusChip(
                                    label: OrderSharedHelpers.statusLabel(
                                      effectiveStatus,
                                    ),
                                    backgroundColor: statusColor.withValues(
                                      alpha: 0.12,
                                    ),
                                    foregroundColor: statusColor,
                                  ),
                                  const SizedBox(width: 6),
                                  PopupMenuButton<String>(
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
