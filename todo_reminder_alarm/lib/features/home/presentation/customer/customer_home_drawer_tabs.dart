part of 'customer_home.dart';

extension _CustomerHomeDrawerTabs on _CustomerHomeBodyState {
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
    final currentUid = ref.watch(authStateProvider).value?.uid ?? widget.profile.id;
    final storeSearch = ref.watch(_customerStoreSearchProvider);
    final categoryFilter = ref.watch(_customerCategoryFilterProvider);
    final cityFilter = ref.watch(_customerCityFilterProvider);
    final liveProfile = ref.watch(userProfileProvider(currentUid)).asData?.value ??
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
        final categories = <String>{'All', ...businesses.map((e) => e.category)};
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
              ref.read(_customerCityFilterProvider.notifier).state = inferredCity;
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
            Text('Find Businesses', style: Theme.of(context).textTheme.headlineSmall),
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
                            ref.read(_customerStoreSearchProvider.notifier).state =
                                value,
                      ),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<String>(
                        isExpanded: true,
                        initialValue: categoryFilter,
                        decoration: const InputDecoration(labelText: 'Category'),
                        items: categories
                            .map(
                              (value) => DropdownMenuItem(
                                value: value,
                                child: Text(value),
                              ),
                            )
                            .toList(),
                        onChanged: (value) =>
                            ref.read(_customerCategoryFilterProvider.notifier).state =
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
                            ref.read(_customerStoreSearchProvider.notifier).state =
                                value,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        isExpanded: true,
                        initialValue: categoryFilter,
                        decoration: const InputDecoration(labelText: 'Category'),
                        items: categories
                            .map(
                              (value) => DropdownMenuItem(
                                value: value,
                                child: Text(value),
                              ),
                            )
                            .toList(),
                        onChanged: (value) =>
                            ref.read(_customerCategoryFilterProvider.notifier).state =
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
            if (filtered.isEmpty) const Text('No businesses match your filters.'),
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
              return _matchesOrderDateFilter(order, dateFilter, now, fromDate, toDate);
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
                DropdownMenuItem(value: 'Processing', child: Text('Processing')),
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
                ref.read(_customerOrderDateFilterProvider.notifier).state = value;
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
                  ref.read(_customerOrderFromDateProvider.notifier).state = null;
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
