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
  }) {
    final query = queryText.trim().toLowerCase();
    return businesses.where((business) {
      final categoryOk =
          categoryFilter == 'All' || business.category == categoryFilter;
      final cityOk = cityFilter == 'All' || business.city == cityFilter;
      final matchesQuery =
          query.isEmpty ||
          business.name.toLowerCase().contains(query) ||
          business.category.toLowerCase().contains(query) ||
          business.city.toLowerCase().contains(query);
      return categoryOk && cityOk && matchesQuery;
    }).toList();
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

  Widget? _buildPaymentBadge(Order order) {
    if (order.payment.status == PaymentStatus.pending) {
      return OrderStatusChip(
        label: 'Payment Pending',
        backgroundColor: Colors.red.shade100,
        foregroundColor: Colors.red.shade800,
      );
    }
    if (order.payment.status == PaymentStatus.done &&
        order.payment.collectedBy == PaymentCollectedBy.deliveryBoy) {
      return OrderStatusChip(
        label: 'Collected by Delivery',
        backgroundColor: Colors.green.shade100,
        foregroundColor: Colors.green.shade800,
      );
    }
    return null;
  }

  Color _statusColor(OrderStatus status) {
    return OrderSharedHelpers.statusColor(status);
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
    final storeSearch = ref.watch(_customerStoreSearchProvider);
    final categoryFilter = ref.watch(_customerCategoryFilterProvider);
    final cityFilter = ref.watch(_customerCityFilterProvider);
    return businessesAsync.when(
      data: (businesses) {
        final categories = <String>{
          'All',
          ...businesses.map((e) => e.category),
        };
        final cities = <String>{'All', ...businesses.map((e) => e.city)};
        final filtered = _applyFilters(
          businesses,
          queryText: storeSearch,
          categoryFilter: categoryFilter,
          cityFilter: cityFilter,
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
                      DropdownButtonFormField<String>(
                        isExpanded: true,
                        initialValue: cityFilter,
                        decoration: const InputDecoration(labelText: 'City'),
                        items: cities
                            .map(
                              (value) => DropdownMenuItem(
                                value: value,
                                child: Text(value),
                              ),
                            )
                            .toList(),
                        onChanged: (value) =>
                            ref
                                    .read(_customerCityFilterProvider.notifier)
                                    .state =
                                value ?? 'All',
                      ),
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
                      child: DropdownButtonFormField<String>(
                        isExpanded: true,
                        initialValue: cityFilter,
                        decoration: const InputDecoration(labelText: 'City'),
                        items: cities
                            .map(
                              (value) => DropdownMenuItem(
                                value: value,
                                child: Text(value),
                              ),
                            )
                            .toList(),
                        onChanged: (value) =>
                            ref
                                    .read(_customerCityFilterProvider.notifier)
                                    .state =
                                value ?? 'All',
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 12),
            if (filtered.isEmpty)
              const Text('No businesses match your filters.'),
            ...filtered.map((business) {
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        business.name,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text('${business.category} • ${business.city}'),
                      const SizedBox(height: 6),
                      Text(
                        (business.address ?? '').trim().isEmpty
                            ? '-'
                            : business.address!.trim(),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: FilledButton(
                              onPressed: () async {
                                final orderId = await Navigator.of(context)
                                    .push<String>(
                                      MaterialPageRoute(
                                        builder: (_) => CreateOrderScreen(
                                          business: business,
                                          customer: widget.profile,
                                        ),
                                      ),
                                    );
                                _onOrderPlaced(orderId, tabController);
                              },
                              child: const Text('Create Order'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () async {
                                final orderId = await Navigator.of(context)
                                    .push<String>(
                                      MaterialPageRoute(
                                        builder: (_) => CustomerCatalogScreen(
                                          business: business,
                                          customer: widget.profile,
                                        ),
                                      ),
                                    );
                                _onOrderPlaced(orderId, tabController);
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
                                    builder: (_) => PublicBusinessProfileScreen(
                                      business: business,
                                    ),
                                  ),
                                );
                              },
                              iconSize: 30,
                              icon: const Icon(Icons.storefront_outlined),
                            ),
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
              final effectiveStatus = _effectiveStatus(order);
              final canEdit = _canEditOrder(order);
              final isFast = order.priority == OrderPriority.fast;
              final statusColor = _statusColor(effectiveStatus);
              final priorityColor = isFast
                  ? Colors.red
                  : Theme.of(context).colorScheme.onSurface;
              final showAmountToCustomer =
                  effectiveStatus != OrderStatus.pending;
              final amount = order.payment.amount;
              final amountText = amount == null
                  ? 'Not set'
                  : (amount == amount.truncateToDouble()
                        ? amount.toInt().toString()
                        : amount.toStringAsFixed(2));
              final collectedBy = order.payment.collectedBy;
              final collectedByText =
                  collectedBy == null ||
                      order.payment.status != PaymentStatus.done
                  ? null
                  : (collectedBy == PaymentCollectedBy.deliveryBoy
                        ? 'Delivery Boy'
                        : 'Business');
              final badge = _buildPaymentBadge(order);
              final unavailableItems = order.items
                  .where((item) => !(item.isIncluded ?? true))
                  .map((item) => item.title)
                  .toList();
              final imageAttachments = _imageAttachments(order);
              final includedItems = order.items.where(
                (item) => item.isIncluded ?? true,
              );
              final itemSummary = includedItems
                  .take(3)
                  .map((item) {
                    final pack = (item.packSize ?? '').trim();
                    if (pack.isNotEmpty) {
                      final qty =
                          item.quantity == item.quantity.truncateToDouble()
                          ? item.quantity.toInt().toString()
                          : item.quantity.toStringAsFixed(2);
                      final suffix = item.quantity == 1 ? 'pack' : 'packs';
                      return '${item.title} $qty $suffix ($pack)';
                    }
                    final qty =
                        item.quantity == item.quantity.truncateToDouble()
                        ? item.quantity.toInt().toString()
                        : item.quantity.toStringAsFixed(2);
                    final unit = switch (item.unit) {
                      QuantityUnit.piece => 'pc',
                      QuantityUnit.kilogram => 'kg',
                      QuantityUnit.gram => 'g',
                      QuantityUnit.liter => 'L',
                    };
                    return '${item.title} $qty $unit';
                  })
                  .join(', ');
              return OrderCardShell(
                isHighlighted: isFast,
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => CustomerOrderDetailScreen(order: order),
                    ),
                  );
                },
                child: ListTile(
                  dense: true,
                  title: Row(
                    children: [
                      Expanded(
                        child: Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(text: '${order.businessName} • '),
                              TextSpan(
                                text: OrderSharedHelpers.statusLabel(
                                  effectiveStatus,
                                ),
                                style: TextStyle(
                                  color: statusColor,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (badge != null) ...[const SizedBox(width: 8), badge],
                    ],
                  ),
                  subtitleTextStyle: Theme.of(context).textTheme.bodyLarge,
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Order ${order.displayOrderNumber}'
                        '${showAmountToCustomer ? ' • Amount: $amountText' : ''}',
                      ),
                      Text.rich(
                        TextSpan(
                          children: [
                            const TextSpan(text: 'Delivery Priority: '),
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
                        'Payment: ${OrderSharedHelpers.capitalize(order.payment.status.name)}'
                        '${collectedByText == null ? '' : ' ($collectedByText)'}'
                        ' | Delivery: ${OrderSharedHelpers.capitalize(order.delivery.status.name)}',
                      ),
                      if (itemSummary.isNotEmpty) Text('Items: $itemSummary'),
                      if (unavailableItems.isNotEmpty)
                        Text('Unavailable: ${unavailableItems.join(', ')}'),
                      if (imageAttachments.isNotEmpty)
                        Text('Item Images: ${imageAttachments.length}'),
                    ],
                  ),
                  trailing: PopupMenuButton<String>(
                    tooltip: canEdit
                        ? 'Order actions'
                        : 'Locked: accepted orders cannot be edited/deleted',
                    onSelected: (value) async {
                      if (value == 'edit') {
                        await _editOrder(order, businessById);
                      } else if (value == 'delete') {
                        await _deleteOrder(order);
                      }
                    },
                    itemBuilder: (_) => [
                      const PopupMenuItem(
                        value: '__help__',
                        enabled: false,
                        child: Text('Editable only while order is New'),
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
                ),
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
