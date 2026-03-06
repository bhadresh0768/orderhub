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
    _searchController.text = ref
        .read(_businessOrdersUiProvider(_uiKey))
        .searchQuery;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool get _isCompletedTab {
    return widget.allowedStatuses.length == 1 &&
        widget.allowedStatuses.first == OrderStatus.completed;
  }

  DateTime _effectiveCompletedAt(Order order) {
    return order.delivery.deliveredAt ??
        order.updatedAt ??
        order.createdAt ??
        DateTime.now();
  }

  bool _matchesCompletedDateFilter(
    Order order,
    OrderDateFilterOption filter,
    DateTime now,
  ) {
    if (filter == OrderDateFilterOption.all) return true;
    final effectiveDate = _effectiveCompletedAt(order);
    final ui = ref.read(_businessOrdersUiProvider(_uiKey));
    return OrderSharedHelpers.matchesDateFilter(
      effectiveDate,
      filter,
      now,
      customFrom: ui.completedFromDate,
      customTo: ui.completedToDate,
    );
  }

  Future<void> _pickCompletedCustomRange(_BusinessOrdersUiState ui) async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year + 2),
      initialDateRange:
          (ui.completedFromDate != null && ui.completedToDate != null)
          ? DateTimeRange(
              start: ui.completedFromDate!,
              end: ui.completedToDate!,
            )
          : null,
    );
    if (picked == null || !mounted) return;
    ref.read(_businessOrdersUiProvider(_uiKey).notifier).state = ui.copyWith(
      completedDateFilter: OrderDateFilterOption.custom,
      completedFromDate: picked.start,
      completedToDate: picked.end,
    );
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
              !_matchesCompletedDateFilter(
                order,
                ui.completedDateFilter,
                now,
              )) {
            return false;
          }
          if (query.isEmpty) return true;
          final itemText = order.items
              .map(
                (item) => '${item.title} ${item.packSize ?? ''}'.toLowerCase(),
              )
              .join(' ');
          return order.customerName.toLowerCase().contains(query) ||
              (order.requesterBusinessName ?? '').toLowerCase().contains(
                query,
              ) ||
              order.displayOrderNumber.toLowerCase().contains(query) ||
              order.id.toLowerCase().contains(query) ||
              itemText.contains(query);
        }).toList();
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                return TextField(
                  controller: _searchController,
                  decoration: const InputDecoration(
                    labelText: 'Search order/customer/item',
                    prefixIcon: Icon(Icons.search),
                  ),
                  onChanged: (value) {
                    ref.read(_businessOrdersUiProvider(_uiKey).notifier).state =
                        ui.copyWith(searchQuery: value);
                  },
                );
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
                      (ui.completedFromDate == null ||
                          ui.completedToDate == null)) {
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
                    ref
                        .read(_businessOrdersUiProvider(_uiKey).notifier)
                        .state = ui.copyWith(
                      completedFromDate: null,
                      completedToDate: null,
                    );
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

  OrderStatus _effectiveOrderStatus(Order order) {
    return OrderSharedHelpers.effectiveStatus(
      order,
      normalizeApprovedToInProgress: true,
    );
  }

  String _requestedByAddress(Order order) {
    final direct = (order.deliveryAddress ?? '').trim();
    if (direct.isNotEmpty) return direct;

    if (order.requesterType == OrderRequesterType.businessOwner) {
      final requesterBusinessId = order.requesterBusinessId;
      if (requesterBusinessId == null || requesterBusinessId.isEmpty) {
        return '-';
      }
      final businessAsync = ref.watch(
        businessByIdProvider(requesterBusinessId),
      );
      final business = businessAsync.asData?.value;
      final address = (business?.address ?? '').trim();
      final city = (business?.city ?? '').trim();
      if (address.isEmpty && city.isEmpty) return '-';
      if (address.isEmpty) return city;
      if (city.isEmpty) return address;
      return '$address, $city';
    }
    return '-';
  }

  String? _paymentCollectorLabel(Order order) {
    final collectedBy = order.payment.collectedBy;
    if (collectedBy == null || order.payment.status != PaymentStatus.done) {
      return null;
    }
    final who = collectedBy == PaymentCollectedBy.deliveryBoy
        ? 'Delivery Boy'
        : 'Business';
    final whoName = (order.payment.collectedByName ?? '').trim();
    if (whoName.isEmpty) return who;
    return '$who ($whoName)';
  }

  Widget _buildOrderCard(BuildContext context, Order order) {
    final colorScheme = Theme.of(context).colorScheme;
    final isBusinessOrder =
        order.requesterType == OrderRequesterType.businessOwner;
    final sourceLabel = isBusinessOrder ? 'Business Order' : 'Customer Order';
    final requestedBy = isBusinessOrder
        ? (order.requesterBusinessName ?? order.customerName)
        : order.customerName;
    final requestedAddress = _requestedByAddress(order);
    final paymentCollector = _paymentCollectorLabel(order);
    final paymentColor = order.payment.status == PaymentStatus.done
        ? const Color(0xFF1A7F47)
        : const Color(0xFFC4432A);
    final priorityColor = order.priority == OrderPriority.fast
        ? const Color(0xFFD65A31)
        : colorScheme.onSurface;
    final isFast = order.priority == OrderPriority.fast;
    final lineStyle = Theme.of(context).textTheme.bodyLarge?.copyWith(
      fontSize: 16,
      height: 1.38,
      color: colorScheme.onSurface.withValues(alpha: 0.92),
    );
    final titleStyle = Theme.of(context).textTheme.titleMedium?.copyWith(
      fontSize: 20,
      fontWeight: FontWeight.w700,
      height: 1.2,
      color: const Color(0xFF1F2A37),
    );
    return OrderCardShell(
      isHighlighted: isFast,
      margin: const EdgeInsets.only(bottom: 14),
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => BusinessOrderDetailScreen(order: order),
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    'Order ${order.displayOrderNumber} • $sourceLabel',
                    style: titleStyle,
                  ),
                ),
                const SizedBox(width: 8),
                widget.allowActions
                    ? PopupMenuButton<String>(
                        icon: Icon(
                          Icons.more_vert_rounded,
                          color: colorScheme.onSurface.withValues(alpha: 0.75),
                        ),
                        onSelected: (value) =>
                            _handleOrderAction(context, order, value),
                        itemBuilder: (context) {
                          final canApprove =
                              order.status == OrderStatus.pending;
                          final canUpdateAfterAccept =
                              order.status == OrderStatus.approved ||
                              order.status == OrderStatus.inProgress;
                          return [
                            if (canApprove)
                              const PopupMenuItem(
                                value: 'approve',
                                child: Text('Approve Order'),
                              ),
                            if (canUpdateAfterAccept)
                              const PopupMenuItem(
                                value: 'mark_delivered',
                                child: Text('Mark Delivered'),
                              ),
                            if (canUpdateAfterAccept &&
                                order.payment.status != PaymentStatus.done)
                              const PopupMenuItem(
                                value: 'payment_done',
                                child: Text('Set Payment Done'),
                              ),
                          ];
                        },
                      )
                    : const Icon(Icons.chevron_right),
              ],
            ),
            const SizedBox(height: 12),
            Text('Order by: $requestedBy', style: lineStyle),
            const SizedBox(height: 8),
            Text('Address: $requestedAddress', style: lineStyle),
            const SizedBox(height: 8),
            Text.rich(
              TextSpan(
                children: [
                  const TextSpan(text: 'Delivery Priority: '),
                  TextSpan(
                    text: OrderSharedHelpers.capitalize(order.priority.name),
                    style: TextStyle(
                      color: priorityColor,
                      fontWeight: order.priority == OrderPriority.fast
                          ? FontWeight.w700
                          : FontWeight.w500,
                    ),
                  ),
                ],
              ),
              style: lineStyle,
            ),
            const SizedBox(height: 8),
            Text.rich(
              TextSpan(
                children: [
                  const TextSpan(text: 'Payment: '),
                  TextSpan(
                    text: OrderSharedHelpers.paymentStatusLabel(
                      order.payment.status,
                    ),
                    style: TextStyle(
                      color: paymentColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const TextSpan(text: ' | Amount: '),
                  TextSpan(
                    text: OrderSharedHelpers.amountLabel(order.payment.amount),
                    style: TextStyle(
                      color: paymentColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              style: lineStyle,
            ),
            if (paymentCollector != null) ...[
              const SizedBox(height: 8),
              Text('Collected by: $paymentCollector', style: lineStyle),
            ],
            if ((order.notes ?? '').trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Remark: ${order.notes!.trim()}',
                style: lineStyle?.copyWith(
                  color: const Color(0xFFB54708),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _paymentMethodLabel(PaymentMethod method) {
    return OrderSharedHelpers.paymentMethodLabel(method);
  }

  Future<(PaymentStatus, PaymentMethod)?> _askPaymentOnDelivery(
    BuildContext context,
    Order order,
  ) async {
    var selectedStatus = order.payment.status;
    var selectedMethod = order.payment.method;
    return showDialog<(PaymentStatus, PaymentMethod)>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocalState) => AlertDialog(
          title: const Text('Mark Delivered'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Payment confirmation'),
              const SizedBox(height: 8),
              DropdownButtonFormField<PaymentStatus>(
                initialValue: selectedStatus,
                items: const [
                  DropdownMenuItem(
                    value: PaymentStatus.done,
                    child: Text('Done'),
                  ),
                  DropdownMenuItem(
                    value: PaymentStatus.pending,
                    child: Text('Remaining'),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setLocalState(() => selectedStatus = value);
                  }
                },
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<PaymentMethod>(
                initialValue: selectedMethod,
                items: PaymentMethod.values
                    .map(
                      (method) => DropdownMenuItem(
                        value: method,
                        child: Text(_paymentMethodLabel(method)),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) {
                    setLocalState(() => selectedMethod = value);
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.of(context).pop((selectedStatus, selectedMethod)),
              child: const Text('Confirm'),
            ),
          ],
        ),
      ),
    );
  }

  Future<bool> _confirmZeroAmountDelivery(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Amount is 0'),
        content: const Text(
          'This order amount is 0. Do you still want to mark it as delivered?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<void> _handleOrderAction(
    BuildContext context,
    Order order,
    String value,
  ) async {
    final firestore = ref.read(firestoreServiceProvider);
    if (value == 'approve') {
      if (order.status != OrderStatus.pending) return;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => BusinessOrderDetailScreen(order: order),
        ),
      );
    } else if (value == 'mark_delivered') {
      if (order.status == OrderStatus.pending) return;
      final amount = order.payment.amount ?? 0;
      if (amount.abs() < 0.000001) {
        final shouldContinue = await _confirmZeroAmountDelivery(context);
        if (!shouldContinue) return;
      }
      if (!context.mounted) return;
      final paymentChoice = await _askPaymentOnDelivery(context, order);
      if (paymentChoice == null) return;
      await firestore.updateOrder(order.id, {
        'status': enumToString(OrderStatus.completed),
        'delivery': {
          ...order.delivery.toMap(),
          'status': enumToString(DeliveryStatus.delivered),
          'updatedAt': Timestamp.fromDate(DateTime.now()),
          'deliveredAt': Timestamp.fromDate(DateTime.now()),
        },
        'payment': {
          ...order.payment.toMap(),
          'status': enumToString(paymentChoice.$1),
          'method': enumToString(paymentChoice.$2),
          'collectedBy': paymentChoice.$1 == PaymentStatus.done
              ? enumToString(PaymentCollectedBy.businessOwner)
              : null,
          'collectedByName': paymentChoice.$1 == PaymentStatus.done
              ? widget.profile.name
              : null,
          'collectedAt': paymentChoice.$1 == PaymentStatus.done
              ? Timestamp.fromDate(DateTime.now())
              : null,
          'collectionNote': paymentChoice.$1 == PaymentStatus.done
              ? order.payment.collectionNote
              : null,
          'updatedAt': Timestamp.fromDate(DateTime.now()),
        },
      });
    } else if (value == 'payment_done') {
      if (order.status == OrderStatus.pending) return;
      final payment = PaymentInfo(
        status: PaymentStatus.done,
        method: order.payment.method,
        amount: order.payment.amount,
        remark: order.payment.remark,
        confirmedByCustomer: order.payment.confirmedByCustomer ?? false,
        collectedBy: PaymentCollectedBy.businessOwner,
        collectedByName: widget.profile.name,
        collectedAt: DateTime.now(),
        collectionNote: order.payment.collectionNote,
        updatedAt: DateTime.now(),
      );
      await firestore.updateOrder(order.id, {'payment': payment.toMap()});
    }
  }
}
