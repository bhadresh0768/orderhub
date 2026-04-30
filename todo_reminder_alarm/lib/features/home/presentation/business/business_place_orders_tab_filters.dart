part of 'business_home.dart';

extension _PlaceOrdersTabFilters on _PlaceOrdersBodyState {
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
      for (var i = 0; i < recentBusinessIds.length; i++) recentBusinessIds[i]: i,
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
}
