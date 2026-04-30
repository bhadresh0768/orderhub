part of 'business_home.dart';

extension _PlaceOrdersTabSections on _PlaceOrdersBodyState {
  Widget _buildBusinessesTab(
    BuildContext context,
    _PlaceOrdersUiState ui,
    String currentUid,
    Set<String> favoriteBusinessIds,
    AsyncValue<List<BusinessProfile>> businessesAsync,
    List<Order> outgoingOrders,
  ) {
    return businessesAsync.when(
      data: (businesses) {
        final options = businesses
            .where((business) => business.id != widget.profile.businessId)
            .toList();
        final categories = <String>{'All', ...options.map((e) => e.category)};
        final normalizedCities =
            options
                .map((e) => e.city.trim())
                .where((city) => city.isNotEmpty)
                .toSet()
                .toList()
              ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
        final cities = ['All', ...normalizedCities];
        final ownCity = (widget.ownBusiness?.city ?? '').trim();
        if (ui.cityFilter == 'All' && ownCity.isNotEmpty && cities.contains(ownCity)) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            final current = ref.read(_placeOrdersUiProvider(_uiKey));
            if (current.cityFilter == 'All') {
              ref.read(_placeOrdersUiProvider(_uiKey).notifier).state =
                  current.copyWith(cityFilter: ownCity);
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
          return const Center(child: Text('No other businesses available.'));
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
                      _buildSearchField(ui),
                      const SizedBox(height: 10),
                      _buildCategoryDropdown(ui, categories),
                      const SizedBox(height: 10),
                      _buildCityDropdown(ui, cities),
                    ],
                  );
                }
                return Row(
                  children: [
                    Expanded(flex: 3, child: _buildSearchField(ui)),
                    const SizedBox(width: 10),
                    Expanded(child: _buildCategoryDropdown(ui, categories)),
                    const SizedBox(width: 10),
                    Expanded(child: _buildCityDropdown(ui, cities)),
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
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    mainAxisExtent: cardExtent,
                  ),
                  itemBuilder: (context, index) {
                    final business = sortedBusinesses[index];
                    final isFavorite = favoriteBusinessIds.contains(business.id);
                    return _BusinessOrderSourceCard(
                      business: business,
                      isFavorite: isFavorite,
                      titleStyle: titleStyle,
                      cardPadding: cardPadding,
                      onToggleFavorite: () async {
                        await ref
                            .read(firestoreServiceProvider)
                            .setCustomerFavoriteBusiness(
                              userId: currentUid,
                              businessId: business.id,
                              isFavorite: !isFavorite,
                            );
                      },
                      onPlaceOrder: widget.ownBusiness == null
                          ? null
                          : () async {
                              final orderId = await Navigator.of(context)
                                  .push<String>(
                                    MaterialPageRoute(
                                      builder: (_) => CreateOrderScreen(
                                        business: business,
                                        customer: widget.profile,
                                        requesterBusiness: widget.ownBusiness,
                                      ),
                                    ),
                                  );
                              _onOutgoingOrderPlaced(orderId);
                            },
                      onOpenCatalog: () async {
                        final orderId = await Navigator.of(context).push<String>(
                          MaterialPageRoute(
                            builder: (_) => CustomerCatalogScreen(
                              business: business,
                              customer: widget.profile,
                              requesterBusiness: widget.ownBusiness,
                            ),
                          ),
                        );
                        _onOutgoingOrderPlaced(orderId);
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
                  },
                );
              },
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) =>
          const Center(child: Text('Something went wrong. Please retry.')),
    );
  }

  Widget _buildPlacedOrdersTab(
    BuildContext context,
    _PlaceOrdersUiState ui,
    AsyncValue<List<Order>> outgoingAsync,
    Map<String, BusinessProfile> businessById,
  ) {
    return outgoingAsync.when(
      data: (orders) {
        final now = DateTime.now();
        final filteredOrders = orders.where((order) {
          return _matchesPlacedDateFilter(order, ui.placedDateFilter, now, ui);
        }).toList();
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('Orders I Placed', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            DropdownButtonFormField<OrderDateFilterOption>(
              initialValue: ui.placedDateFilter,
              decoration: const InputDecoration(labelText: 'Date Filter'),
              items: OrderDateFilterOption.values
                  .map(
                    (filter) => DropdownMenuItem(
                      value: filter,
                      child: Text(OrderSharedHelpers.dateFilterLabel(filter)),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value == null) return;
                ref.read(_placeOrdersUiProvider(_uiKey).notifier).state =
                    ui.copyWith(placedDateFilter: value);
                if (value == OrderDateFilterOption.custom &&
                    (ui.placedFromDate == null || ui.placedToDate == null)) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (!mounted) return;
                    _pickPlacedCustomRange(ref.read(_placeOrdersUiProvider(_uiKey)));
                  });
                }
              },
            ),
            if (ui.placedDateFilter == OrderDateFilterOption.custom) ...[
              const SizedBox(height: 8),
              OrderDateRangeRow(
                fromDate: ui.placedFromDate,
                toDate: ui.placedToDate,
                onSelect: () => _pickPlacedCustomRange(ui),
                onClear: () {
                  ref.read(_placeOrdersUiProvider(_uiKey).notifier).state =
                      ui.copyWith(placedFromDate: null, placedToDate: null);
                },
              ),
            ],
            const SizedBox(height: 12),
            if (filteredOrders.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 24),
                child: Center(
                  child: Text('No outgoing orders for selected filter.'),
                ),
              ),
            ...filteredOrders.map((order) {
              final canEdit = _canEditOrder(order);
              return _PlacedOutgoingOrderCard(
                order: order,
                canEdit: canEdit,
                onEditOrder: () => _editPlacedOrder(order, businessById),
                onDeleteOrder: () => _deletePlacedOrder(order),
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

  Widget _buildSearchField(_PlaceOrdersUiState ui) {
    return TextField(
      controller: _searchController,
      decoration: const InputDecoration(
        labelText: 'Search business/category/address/city',
        prefixIcon: Icon(Icons.search),
      ),
      onChanged: (value) {
        ref.read(_placeOrdersUiProvider(_uiKey).notifier).state =
            ui.copyWith(searchQuery: value);
      },
    );
  }

  Widget _buildCategoryDropdown(_PlaceOrdersUiState ui, Set<String> categories) {
    return DropdownButtonFormField<String>(
      isExpanded: true,
      initialValue: ui.categoryFilter,
      decoration: const InputDecoration(labelText: 'Category'),
      items: categories
          .map(
            (value) => DropdownMenuItem(value: value, child: Text(value)),
          )
          .toList(),
      onChanged: (value) {
        ref.read(_placeOrdersUiProvider(_uiKey).notifier).state =
            ui.copyWith(categoryFilter: value ?? 'All');
      },
    );
  }

  Widget _buildCityDropdown(_PlaceOrdersUiState ui, List<String> cities) {
    return DropdownButtonFormField<String>(
      isExpanded: true,
      initialValue: ui.cityFilter,
      decoration: const InputDecoration(labelText: 'City'),
      items: cities
          .map(
            (value) => DropdownMenuItem(value: value, child: Text(value)),
          )
          .toList(),
      onChanged: (value) {
        ref.read(_placeOrdersUiProvider(_uiKey).notifier).state =
            ui.copyWith(cityFilter: value ?? 'All');
      },
    );
  }
}
