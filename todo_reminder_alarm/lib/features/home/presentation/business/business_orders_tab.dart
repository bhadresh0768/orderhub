part of 'business_home.dart';

class _BusinessOrdersTab extends ConsumerStatefulWidget {
  const _BusinessOrdersTab({
    required this.profile,
    required this.allowedStatuses,
    required this.emptyMessage,
    required this.allowActions,
  });

  final AppUser profile;
  final List<OrderStatus> allowedStatuses;
  final String emptyMessage;
  final bool allowActions;

  @override
  ConsumerState<_BusinessOrdersTab> createState() => _BusinessOrdersTabState();
}

class _BusinessOrdersTabState extends ConsumerState<_BusinessOrdersTab> {
  final TextEditingController _searchController = TextEditingController();
  late final String _uiKey;

  @override
  void initState() {
    super.initState();
    _uiKey =
        '${widget.profile.businessId}-${widget.allowedStatuses.map((e) => e.name).join(",")}';
    _searchController.text =
        ref.read(_businessOrdersUiProvider(_uiKey)).searchQuery;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ui = ref.watch(_businessOrdersUiProvider(_uiKey));
    final ordersAsync = ref.watch(
      ordersForBusinessProvider(widget.profile.businessId!),
    );
    return ordersAsync.when(
      data: (orders) {
        final now = DateTime.now();
        final query = ui.searchQuery.trim().toLowerCase();
        final tabOrders = orders.where((order) {
          final effectiveStatus = _effectiveOrderStatus(order);
          if (!widget.allowedStatuses.contains(effectiveStatus)) return false;
          if (_isCompletedTab &&
              !_matchesCompletedDateFilter(order, ui.completedDateFilter, now)) {
            return false;
          }
          if (query.isEmpty) return true;
          final itemText = order.items
              .map((item) => '${item.title} ${item.packSize ?? ''}'.toLowerCase())
              .join(' ');
          return order.customerName.toLowerCase().contains(query) ||
              (order.requesterBusinessName ?? '').toLowerCase().contains(query) ||
              order.displayOrderNumber.toLowerCase().contains(query) ||
              order.id.toLowerCase().contains(query) ||
              itemText.contains(query);
        }).toList();
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                labelText: 'Search order/customer/item',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (value) {
                ref.read(_businessOrdersUiProvider(_uiKey).notifier).state =
                    ui.copyWith(searchQuery: value);
              },
            ),
            if (_isCompletedTab) ...[
              const SizedBox(height: 12),
              DropdownButtonFormField<OrderDateFilterOption>(
                initialValue: ui.completedDateFilter,
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
                  ref.read(_businessOrdersUiProvider(_uiKey).notifier).state =
                      ui.copyWith(completedDateFilter: value);
                  if (value == OrderDateFilterOption.custom &&
                      (ui.completedFromDate == null || ui.completedToDate == null)) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (!mounted) return;
                      _pickCompletedCustomRange(
                        ref.read(_businessOrdersUiProvider(_uiKey)),
                      );
                    });
                  }
                },
              ),
              if (ui.completedDateFilter == OrderDateFilterOption.custom) ...[
                const SizedBox(height: 8),
                OrderDateRangeRow(
                  fromDate: ui.completedFromDate,
                  toDate: ui.completedToDate,
                  onSelect: () => _pickCompletedCustomRange(ui),
                  onClear: () {
                    ref.read(_businessOrdersUiProvider(_uiKey).notifier).state =
                        ui.copyWith(completedFromDate: null, completedToDate: null);
                  },
                ),
              ],
            ],
            const SizedBox(height: 12),
            if (tabOrders.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 24),
                child: Center(child: Text(widget.emptyMessage)),
              )
            else
              ...tabOrders.map((order) => _buildOrderCard(context, order)),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) =>
          const Center(child: Text('Something went wrong. Please retry.')),
    );
  }
}
