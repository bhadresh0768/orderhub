part of 'delivery_boy_home.dart';

extension _DeliveryBoyHomeActions on _DeliveryBoyBodyState {
  String _capitalize(String value) {
    if (value.isEmpty) return value;
    return value[0].toUpperCase() + value.substring(1);
  }

  String _formatDate(DateTime date) {
    final mm = date.month.toString().padLeft(2, '0');
    final dd = date.day.toString().padLeft(2, '0');
    return '${date.year}-$mm-$dd';
  }

  bool _isInDateRange(DateTime date, DateTime from, DateTime to) {
    final start = DateTime(from.year, from.month, from.day);
    final endExclusive = DateTime(to.year, to.month, to.day)
        .add(const Duration(days: 1));
    return !date.isBefore(start) && date.isBefore(endExclusive);
  }

  Future<void> _pickCustomRange(_DeliveryBoyUiState uiState) async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year + 2),
      initialDateRange: (uiState.customFrom != null && uiState.customTo != null)
          ? DateTimeRange(start: uiState.customFrom!, end: uiState.customTo!)
          : null,
    );
    if (picked == null || !mounted) return;
    ref.read(_deliveryBoyUiProvider.notifier).state = uiState.copyWith(
      filter: _DeliveryDateFilter.custom,
      customFrom: picked.start,
      customTo: picked.end,
    );
  }

  DateTime? _referenceDate(Order order, {required bool completedTab}) {
    if (completedTab) {
      return order.delivery.deliveredAt ??
          order.delivery.updatedAt ??
          order.updatedAt ??
          order.createdAt;
    }
    return order.scheduledAt ??
        order.delivery.updatedAt ??
        order.updatedAt ??
        order.createdAt;
  }

  bool _matchesRange(Order order, {required bool completedTab}) {
    final filter = ref.read(_deliveryBoyUiProvider).filter;
    final date = _referenceDate(order, completedTab: completedTab);
    if (date == null) return false;
    final now = DateTime.now();
    switch (filter) {
      case _DeliveryDateFilter.today:
        return date.year == now.year &&
            date.month == now.month &&
            date.day == now.day;
      case _DeliveryDateFilter.week:
        final weekStart = DateTime(
          now.year,
          now.month,
          now.day,
        ).subtract(Duration(days: now.weekday - 1));
        final weekEnd = weekStart.add(const Duration(days: 7));
        return !date.isBefore(weekStart) && date.isBefore(weekEnd);
      case _DeliveryDateFilter.month:
        return date.year == now.year && date.month == now.month;
      case _DeliveryDateFilter.year:
        return date.year == now.year;
      case _DeliveryDateFilter.custom:
        final from = ref.read(_deliveryBoyUiProvider).customFrom;
        final to = ref.read(_deliveryBoyUiProvider).customTo;
        if (from == null || to == null) return false;
        return _isInDateRange(date, from, to);
    }
  }

  String _filterLabel(_DeliveryDateFilter value) {
    switch (value) {
      case _DeliveryDateFilter.today:
        return 'Today';
      case _DeliveryDateFilter.week:
        return 'This Week';
      case _DeliveryDateFilter.month:
        return 'This Month';
      case _DeliveryDateFilter.year:
        return 'This Year';
      case _DeliveryDateFilter.custom:
        return 'Custom Range';
    }
  }

  String _formatQty(double value) {
    return value == value.truncateToDouble()
        ? value.toInt().toString()
        : value.toStringAsFixed(2);
  }

  String _shortUnit(OrderItem item) {
    if (item.unit == QuantityUnit.other) {
      return item.displayUnitSymbol;
    }
    final unit = item.unit;
    switch (unit) {
      case QuantityUnit.piece:
        return 'pc';
      case QuantityUnit.box:
        return 'box';
      case QuantityUnit.kilogram:
        return 'kg';
      case QuantityUnit.gram:
        return 'g';
      case QuantityUnit.liter:
        return 'L';
      case QuantityUnit.ton:
        return 't';
      case QuantityUnit.packet:
        return 'pkt';
      case QuantityUnit.bag:
        return 'bag';
      case QuantityUnit.bottle:
        return 'btl';
      case QuantityUnit.can:
        return 'can';
      case QuantityUnit.meter:
        return 'm';
      case QuantityUnit.foot:
        return 'ft';
      case QuantityUnit.carton:
        return 'ctn';
      case QuantityUnit.other:
        return item.displayUnitSymbol;
    }
  }

  String _itemSummary(OrderItem item) {
    final base = '${item.title} ${_formatQty(item.quantity)} ${_shortUnit(item)}';
    final pack = item.packSize?.trim();
    if (pack == null || pack.isEmpty) return base;
    return '$base ($pack)';
  }

  String _paymentMethodLabel(PaymentMethod method) {
    return switch (method) {
      PaymentMethod.cash => 'Cash',
      PaymentMethod.check => 'Check',
      PaymentMethod.onlineTransfer => 'Online Transfer',
    };
  }

  Future<(bool, PaymentMethod, String?)?> _askCollectionOnDelivered(
    BuildContext context,
    Order order,
  ) async {
    var collectNow = order.payment.status == PaymentStatus.done;
    var method = order.payment.method;
    final noteController = TextEditingController(
      text: order.payment.collectionNote ?? '',
    );
    final result = await showDialog<(bool, PaymentMethod, String?)>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocalState) => AlertDialog(
          title: const Text('Mark Delivered'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Was payment collected at delivery?'),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: const Text('Collect payment now'),
                value: collectNow,
                onChanged: (value) => setLocalState(() => collectNow = value),
              ),
              if (collectNow) ...[
                const SizedBox(height: 8),
                DropdownButtonFormField<PaymentMethod>(
                  initialValue: method,
                  decoration: const InputDecoration(
                    labelText: 'Payment Method',
                  ),
                  items: PaymentMethod.values
                      .map(
                        (value) => DropdownMenuItem(
                          value: value,
                          child: Text(_paymentMethodLabel(value)),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setLocalState(() => method = value);
                    }
                  },
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: noteController,
                  decoration: const InputDecoration(
                    labelText: 'Reference Note (optional)',
                    hintText: 'Receipt no / UPI ref / cheque no',
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(
                context,
              ).pop((collectNow, method, noteController.text.trim())),
              child: const Text('Confirm'),
            ),
          ],
        ),
      ),
    );
    return result;
  }

  Future<void> _updateDeliveryStatus(
    BuildContext context,
    WidgetRef ref,
    Order order,
    DeliveryStatus status,
  ) async {
    bool collectNow = false;
    PaymentMethod selectedMethod = order.payment.method;
    String? collectionNote = order.payment.collectionNote;
    if (status == DeliveryStatus.delivered) {
      final decision = await _askCollectionOnDelivered(context, order);
      if (decision == null) return;
      collectNow = decision.$1;
      selectedMethod = decision.$2;
      final note = decision.$3?.trim();
      collectionNote = note == null || note.isEmpty ? null : note;
    }
    final now = DateTime.now();
    final nextOrderStatus = status == DeliveryStatus.delivered
        ? OrderStatus.completed
        : (order.status == OrderStatus.pending ? OrderStatus.inProgress : null);
    await ref.read(firestoreServiceProvider).updateOrder(order.id, {
      'delivery': {
        ...order.delivery.toMap(),
        'status': enumToString(status),
        'updatedAt': Timestamp.fromDate(now),
        'deliveredAt': status == DeliveryStatus.delivered
            ? Timestamp.fromDate(now)
            : order.delivery.deliveredAt == null
            ? null
            : Timestamp.fromDate(order.delivery.deliveredAt!),
      },
      if (status == DeliveryStatus.delivered)
        'payment': {
          ...order.payment.toMap(),
          'status': enumToString(
            collectNow ? PaymentStatus.done : PaymentStatus.pending,
          ),
          'method': enumToString(selectedMethod),
          'collectedBy': collectNow
              ? enumToString(PaymentCollectedBy.deliveryBoy)
              : null,
          'collectedByName': collectNow ? widget.name : null,
          'collectedAt': collectNow ? Timestamp.fromDate(now) : null,
          'collectionNote': collectNow ? collectionNote : null,
          'updatedAt': Timestamp.fromDate(now),
        },
      if (nextOrderStatus != null) 'status': enumToString(nextOrderStatus),
    });
  }
}
