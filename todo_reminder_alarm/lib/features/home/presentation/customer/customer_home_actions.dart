part of 'customer_home.dart';

extension _CustomerHomeActions on _CustomerHomeBodyState {
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
                                                _customerCityFilterProvider.notifier,
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
}
