part of 'customer_home.dart';

class _CustomerHomeBodyState extends ConsumerState<_CustomerHomeBody> {
  void _onOrderPlaced(String? orderLabel, TabController tabController) {
    if (orderLabel == null || !mounted) return;
    tabController.animateTo(1);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('$orderLabel placed successfully')));
  }

  bool _canEditOrder(Order order) {
    return order.status == OrderStatus.pending &&
        order.delivery.status == DeliveryStatus.pending;
  }

  Future<void> _editOrder(
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
    final result = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => CreateOrderScreen(
          business: business,
          customer: widget.profile,
          existingOrder: order,
        ),
      ),
    );
    if (!mounted || result == null) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Order ${order.displayOrderNumber} updated successfully'),
      ),
    );
  }

  Future<void> _deleteOrder(Order order) async {
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

  List<BusinessProfile> _applyFilters(
    List<BusinessProfile> businesses, {
    required String queryText,
    required String categoryFilter,
    required String cityFilter,
    required Map<String, String> ownerNamesByBusinessId,
  }) {
    final query = queryText.trim().toLowerCase();
    return businesses.where((business) {
      final categoryOk =
          categoryFilter == 'All' || business.category == categoryFilter;
      final cityOk = cityFilter == 'All' || business.city == cityFilter;
      final ownerName = (ownerNamesByBusinessId[business.id] ?? '')
          .trim()
          .toLowerCase();
      final matchesQuery =
          query.isEmpty ||
          business.name.toLowerCase().contains(query) ||
          business.category.toLowerCase().contains(query) ||
          business.city.toLowerCase().contains(query) ||
          ownerName.contains(query);
      return categoryOk && cityOk && matchesQuery;
    }).toList();
  }

  String? _inferDefaultCityFromAddress(List<String> cities) {
    final rawAddress = (widget.profile.address ?? '').trim().toLowerCase();
    if (rawAddress.isEmpty) return null;
    final matches = cities
        .where((city) => city != 'All')
        .where((city) => rawAddress.contains(city.toLowerCase()))
        .toList();
    if (matches.isEmpty) return null;
    matches.sort((a, b) => b.length.compareTo(a.length));
    return matches.first;
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

  List<BusinessProfile> _sortBusinessesForCustomer(
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

  Future<void> _showCityPicker(List<String> cities, String selectedCity) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        var searchQuery = '';
        return StatefulBuilder(
          builder: (context, setModalState) {
            final filteredCities = cities.where((city) {
              if (searchQuery.trim().isEmpty) return true;
              return city.toLowerCase().contains(searchQuery.toLowerCase());
            }).toList();
            return SafeArea(
              child: Padding(
                padding: EdgeInsets.only(
                  left: 16,
                  right: 16,
                  top: 16,
                  bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 16,
                ),
                child: SizedBox(
                  height: 420,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Select City',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        decoration: const InputDecoration(
                          labelText: 'Search city',
                          prefixIcon: Icon(Icons.search),
                        ),
                        onChanged: (value) {
                          setModalState(() {
                            searchQuery = value;
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: filteredCities.isEmpty
                            ? const Center(
                                child: Text('No city matches your search.'),
                              )
                            : ListView.builder(
                                itemCount: filteredCities.length,
                                itemBuilder: (context, index) {
                                  final city = filteredCities[index];
                                  final isSelected = city == selectedCity;
                                  return ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    title: Text(city),
                                    trailing: isSelected
                                        ? const Icon(Icons.check)
                                        : null,
                                    onTap: () {
                                      ref
                                              .read(
                                                _customerCityFilterProvider
                                                    .notifier,
                                              )
                                              .state =
                                          city;
                                      Navigator.of(sheetContext).pop();
                                    },
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildCityPickerField(List<String> cities, String cityFilter) {
    return InkWell(
      onTap: () => _showCityPicker(cities, cityFilter),
      borderRadius: BorderRadius.circular(12),
      child: InputDecorator(
        decoration: const InputDecoration(
          labelText: 'City',
          suffixIcon: Icon(Icons.search),
        ),
        child: Text(cityFilter, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
    );
  }

  OrderStatus _effectiveStatus(Order order) {
    return OrderSharedHelpers.effectiveStatus(order);
  }

  DateTime _effectiveOrderDate(Order order) {
    return order.createdAt ?? order.updatedAt ?? DateTime.now();
  }

  bool _matchesOrderDateFilter(
    Order order,
    OrderDateFilterOption filter,
    DateTime now,
    DateTime? from,
    DateTime? to,
  ) {
    if (filter == OrderDateFilterOption.all) return true;
    final effectiveDate = _effectiveOrderDate(order);
    return OrderSharedHelpers.matchesDateFilter(
      effectiveDate,
      filter,
      now,
      customFrom: from,
      customTo: to,
    );
  }

  Future<void> _pickOrderCustomRange() async {
    final now = DateTime.now();
    final from = ref.read(_customerOrderFromDateProvider);
    final to = ref.read(_customerOrderToDateProvider);
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year + 2),
      initialDateRange: (from != null && to != null)
          ? DateTimeRange(start: from, end: to)
          : null,
    );
    if (picked == null || !mounted) return;
    ref.read(_customerOrderDateFilterProvider.notifier).state =
        OrderDateFilterOption.custom;
    ref.read(_customerOrderFromDateProvider.notifier).state = picked.start;
    ref.read(_customerOrderToDateProvider.notifier).state = picked.end;
  }

  List<Order> _applyOrderFilters(
    List<Order> orders, {
    required String queryText,
    required String orderFilter,
  }) {
    final query = queryText.trim().toLowerCase();
    return orders.where((order) {
      final effectiveStatus = _effectiveStatus(order);
      final paymentPending = order.payment.status == PaymentStatus.pending;
      final matchesFilter = switch (orderFilter) {
        'Pending' => effectiveStatus == OrderStatus.pending,
        'Processing' =>
          effectiveStatus == OrderStatus.approved ||
              effectiveStatus == OrderStatus.inProgress,
        'Completed' => effectiveStatus == OrderStatus.completed,
        'Payment Pending' => paymentPending,
        _ => true,
      };
      if (!matchesFilter) return false;
      if (query.isEmpty) return true;
      return order.businessName.toLowerCase().contains(query) ||
          order.displayOrderNumber.toLowerCase().contains(query) ||
          order.items.any((item) => item.title.toLowerCase().contains(query));
    }).toList();
  }

  bool _looksLikeImage(String value) {
    final normalized = value.toLowerCase();
    return normalized.contains('.jpg') ||
        normalized.contains('.jpeg') ||
        normalized.contains('.png') ||
        normalized.contains('.webp') ||
        normalized.contains('.gif');
  }

  List<OrderAttachment> _imageAttachments(Order order) {
    final itemLevel = order.items.expand((item) => item.attachments);
    return [...order.attachments, ...itemLevel]
        .where(
          (attachment) =>
              _looksLikeImage(attachment.name) ||
              _looksLikeImage(attachment.url),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    // Show only approved stores; search/filters are applied client-side.
    final businessesAsync = ref.watch(approvedBusinessesProvider);
    final ordersAsync = ref.watch(ordersForCustomerProvider(widget.profile.id));

    return Scaffold(
      appBar: AppBar(title: const Text('Dashboard')),
      drawer: _buildDrawer(ordersAsync.value ?? const []),
      body: DefaultTabController(
        length: 2,
        child: Column(
          children: [
            const TabBar(
              tabs: [
                Tab(text: 'Stores'),
                Tab(text: 'My Orders'),
              ],
            ),
            Expanded(
              child: TabBarView(
                children: [
                  Builder(
                    builder: (tabContext) => _buildStoresTab(
                      businessesAsync,
                      DefaultTabController.of(tabContext),
                    ),
                  ),
                  _buildOrdersTab(ordersAsync),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Drawer _buildDrawer(List<Order> orders) {
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
                    builder: (_) => ProfileScreen(user: widget.profile),
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
                      title: 'Customer History & Reports',
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
                    builder: (_) => SupportTicketsScreen(user: widget.profile),
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
                    builder: (_) => ContactUsScreen(user: widget.profile),
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

  Widget _buildStoresTab(
    AsyncValue<List<BusinessProfile>> businessesAsync,
    TabController tabController,
  ) {
    final currentUid =
        ref.watch(authStateProvider).value?.uid ?? widget.profile.id;
    final storeSearch = ref.watch(_customerStoreSearchProvider);
    final categoryFilter = ref.watch(_customerCategoryFilterProvider);
    final cityFilter = ref.watch(_customerCityFilterProvider);
    final liveProfile =
        ref.watch(userProfileProvider(currentUid)).asData?.value ??
        widget.profile;
    final favoriteBusinessIds = liveProfile.favoriteBusinessIds.toSet();
    final customerOrders =
        ref.watch(ordersForCustomerProvider(widget.profile.id)).asData?.value ??
        const <Order>[];
    return businessesAsync.when(
      data: (businesses) {
        final ownerNamesByBusinessId = {
          for (final business in businesses)
            business.id: (business.ownerName ?? '').trim(),
        };
        final categories = <String>{
          'All',
          ...businesses.map((e) => e.category),
        };
        final normalizedCities =
            businesses
                .map((e) => e.city.trim())
                .where((city) => city.isNotEmpty)
                .toSet()
                .toList()
              ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
        final cities = ['All', ...normalizedCities];
        final inferredCity = _inferDefaultCityFromAddress(cities);
        if (cityFilter == 'All' &&
            inferredCity != null &&
            inferredCity.isNotEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            final current = ref.read(_customerCityFilterProvider);
            if (current == 'All') {
              ref.read(_customerCityFilterProvider.notifier).state =
                  inferredCity;
            }
          });
        }
        final effectiveCityFilter = cityFilter == 'All' && inferredCity != null
            ? inferredCity
            : cityFilter;
        final filtered = _applyFilters(
          businesses,
          queryText: storeSearch,
          categoryFilter: categoryFilter,
          cityFilter: effectiveCityFilter,
          ownerNamesByBusinessId: ownerNamesByBusinessId,
        );
        final sortedBusinesses = _sortBusinessesForCustomer(
          filtered,
          favoriteIds: favoriteBusinessIds,
          recentBusinessIds: _recentBusinessIds(customerOrders),
        );
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'Find Businesses',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, constraints) {
                final isNarrow = constraints.maxWidth < 700;
                if (isNarrow) {
                  return Column(
                    children: [
                      TextField(
                        decoration: const InputDecoration(
                          labelText: 'Search by business/category/city',
                          prefixIcon: Icon(Icons.search),
                        ),
                        onChanged: (value) =>
                            ref
                                    .read(_customerStoreSearchProvider.notifier)
                                    .state =
                                value,
                      ),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<String>(
                        isExpanded: true,
                        initialValue: categoryFilter,
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
                        onChanged: (value) =>
                            ref
                                    .read(
                                      _customerCategoryFilterProvider.notifier,
                                    )
                                    .state =
                                value ?? 'All',
                      ),
                      const SizedBox(height: 10),
                      _buildCityPickerField(cities, effectiveCityFilter),
                    ],
                  );
                }
                return Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: TextField(
                        decoration: const InputDecoration(
                          labelText: 'Search by business/category/city',
                          prefixIcon: Icon(Icons.search),
                        ),
                        onChanged: (value) =>
                            ref
                                    .read(_customerStoreSearchProvider.notifier)
                                    .state =
                                value,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        isExpanded: true,
                        initialValue: categoryFilter,
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
                        onChanged: (value) =>
                            ref
                                    .read(
                                      _customerCategoryFilterProvider.notifier,
                                    )
                                    .state =
                                value ?? 'All',
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildCityPickerField(cities, effectiveCityFilter),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 12),
            if (filtered.isEmpty)
              const Text('No businesses match your filters.'),
            ...sortedBusinesses.map((business) {
              final isFavorite = favoriteBusinessIds.contains(business.id);
              return _CustomerStoreCard(
                business: business,
                isFavorite: isFavorite,
                onToggleFavorite: () async {
                  await ref
                      .read(firestoreServiceProvider)
                      .setCustomerFavoriteBusiness(
                        userId: currentUid,
                        businessId: business.id,
                        isFavorite: !isFavorite,
                      );
                },
                onCreateOrder: () async {
                  final orderId = await Navigator.of(context).push<String>(
                    MaterialPageRoute(
                      builder: (_) => CreateOrderScreen(
                        business: business,
                        customer: widget.profile,
                      ),
                    ),
                  );
                  _onOrderPlaced(orderId, tabController);
                },
                onOpenCatalog: () async {
                  final orderId = await Navigator.of(context).push<String>(
                    MaterialPageRoute(
                      builder: (_) => CustomerCatalogScreen(
                        business: business,
                        customer: widget.profile,
                      ),
                    ),
                  );
                  _onOrderPlaced(orderId, tabController);
                },
                onOpenStoreProfile: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) =>
                          PublicBusinessProfileScreen(business: business),
                    ),
                  );
                },
              );
            }),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) =>
          const Center(child: Text('Something went wrong. Please retry.')),
    );
  }

  Widget _buildOrdersTab(AsyncValue<List<Order>> ordersAsync) {
    final orderSearch = ref.watch(_customerOrderSearchProvider);
    final orderFilter = ref.watch(_customerOrderFilterProvider);
    final dateFilter = ref.watch(_customerOrderDateFilterProvider);
    final fromDate = ref.watch(_customerOrderFromDateProvider);
    final toDate = ref.watch(_customerOrderToDateProvider);
    final businessesAsync = ref.watch(businessesProvider);
    final businessById = {
      for (final business
          in businessesAsync.asData?.value ?? const <BusinessProfile>[])
        business.id: business,
    };
    return ordersAsync.when(
      data: (orders) {
        final now = DateTime.now();
        final filteredOrders =
            _applyOrderFilters(
              orders,
              queryText: orderSearch,
              orderFilter: orderFilter,
            ).where((order) {
              return _matchesOrderDateFilter(
                order,
                dateFilter,
                now,
                fromDate,
                toDate,
              );
            }).toList();
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('My Orders', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 12),
            TextField(
              decoration: const InputDecoration(
                labelText: 'Search by store/order/item',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (value) =>
                  ref.read(_customerOrderSearchProvider.notifier).state = value,
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              initialValue: orderFilter,
              decoration: const InputDecoration(labelText: 'Order Filter'),
              items: const [
                DropdownMenuItem(value: 'All', child: Text('All')),
                DropdownMenuItem(value: 'Pending', child: Text('Pending')),
                DropdownMenuItem(
                  value: 'Processing',
                  child: Text('Processing'),
                ),
                DropdownMenuItem(value: 'Completed', child: Text('Completed')),
                DropdownMenuItem(
                  value: 'Payment Pending',
                  child: Text('Payment Pending'),
                ),
              ],
              onChanged: (value) =>
                  ref.read(_customerOrderFilterProvider.notifier).state =
                      value ?? 'All',
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<OrderDateFilterOption>(
              initialValue: dateFilter,
              decoration: const InputDecoration(labelText: 'Date Filter'),
              items: OrderDateFilterOption.values
                  .map(
                    (value) => DropdownMenuItem(
                      value: value,
                      child: Text(OrderSharedHelpers.dateFilterLabel(value)),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value == null) return;
                ref.read(_customerOrderDateFilterProvider.notifier).state =
                    value;
                if (value == OrderDateFilterOption.custom &&
                    (fromDate == null || toDate == null)) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (!mounted) return;
                    _pickOrderCustomRange();
                  });
                }
              },
            ),
            if (dateFilter == OrderDateFilterOption.custom) ...[
              const SizedBox(height: 8),
              OrderDateRangeRow(
                fromDate: fromDate,
                toDate: toDate,
                onSelect: _pickOrderCustomRange,
                onClear: () {
                  ref.read(_customerOrderFromDateProvider.notifier).state =
                      null;
                  ref.read(_customerOrderToDateProvider.notifier).state = null;
                },
              ),
            ],
            const SizedBox(height: 12),
            if (filteredOrders.isEmpty)
              const Text('No orders match current filters.'),
            ...filteredOrders.map((order) {
              final business = businessById[order.businessId];
              final canEdit = _canEditOrder(order);
              final unavailableItems = order.items
                  .where((item) => !(item.isIncluded ?? true))
                  .map((item) => item.title)
                  .toList();
              return _CustomerOrderCard(
                order: order,
                business: business,
                canEdit: canEdit,
                imageAttachmentCount: _imageAttachments(order).length,
                unavailableItems: unavailableItems,
                onEditOrder: () => _editOrder(order, businessById),
                onDeleteOrder: () => _deleteOrder(order),
                onOpenOrderDetail: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => CustomerOrderDetailScreen(order: order),
                    ),
                  );
                },
              );
            }),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) =>
          const Center(child: Text('Something went wrong. Please retry.')),
    );
  }
}
