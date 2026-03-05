import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart' show StateProvider;

import '../../../models/enums.dart';
import '../../../models/order.dart';
import 'common/order_card_shell.dart';
import 'common/order_date_range_row.dart';
import 'common/order_shared_helpers.dart';
import 'customer_order_detail_screen.dart';

final _orderHistoryUiProvider = StateProvider.autoDispose<_OrderHistoryUiState>(
  (ref) => const _OrderHistoryUiState(),
);

class _OrderHistoryUiState {
  const _OrderHistoryUiState({
    this.statusFilter,
    this.priorityFilter,
    this.dateFilter = OrderDateFilterOption.all,
    this.customFromDate,
    this.customToDate,
  });

  final OrderStatus? statusFilter;
  final OrderPriority? priorityFilter;
  final OrderDateFilterOption dateFilter;
  final DateTime? customFromDate;
  final DateTime? customToDate;

  _OrderHistoryUiState copyWith({
    Object? statusFilter = _orderHistoryUnset,
    Object? priorityFilter = _orderHistoryUnset,
    OrderDateFilterOption? dateFilter,
    Object? customFromDate = _orderHistoryUnset,
    Object? customToDate = _orderHistoryUnset,
  }) {
    return _OrderHistoryUiState(
      statusFilter: statusFilter == _orderHistoryUnset
          ? this.statusFilter
          : statusFilter as OrderStatus?,
      priorityFilter: priorityFilter == _orderHistoryUnset
          ? this.priorityFilter
          : priorityFilter as OrderPriority?,
      dateFilter: dateFilter ?? this.dateFilter,
      customFromDate: customFromDate == _orderHistoryUnset
          ? this.customFromDate
          : customFromDate as DateTime?,
      customToDate: customToDate == _orderHistoryUnset
          ? this.customToDate
          : customToDate as DateTime?,
    );
  }
}

const _orderHistoryUnset = Object();

class OrderHistoryReportScreen extends ConsumerStatefulWidget {
  const OrderHistoryReportScreen({
    super.key,
    required this.title,
    required this.orders,
  });

  final String title;
  final List<Order> orders;

  @override
  ConsumerState<OrderHistoryReportScreen> createState() =>
      _OrderHistoryReportScreenState();
}

class _OrderHistoryReportScreenState
    extends ConsumerState<OrderHistoryReportScreen> {
  Future<void> _pickCustomRange(_OrderHistoryUiState ui) async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year + 2),
      initialDateRange: (ui.customFromDate != null && ui.customToDate != null)
          ? DateTimeRange(start: ui.customFromDate!, end: ui.customToDate!)
          : null,
    );
    if (picked == null || !mounted) return;
    ref.read(_orderHistoryUiProvider.notifier).state = ui.copyWith(
      dateFilter: OrderDateFilterOption.custom,
      customFromDate: picked.start,
      customToDate: picked.end,
    );
  }

  List<Order> get _filtered {
    final ui = ref.read(_orderHistoryUiProvider);
    final now = DateTime.now();
    return widget.orders.where((order) {
      if (ui.statusFilter != null && order.status != ui.statusFilter) {
        return false;
      }
      if (ui.priorityFilter != null && order.priority != ui.priorityFilter) {
        return false;
      }
      final created = order.createdAt ?? now;
      if (!OrderSharedHelpers.matchesDateFilter(
        created,
        ui.dateFilter,
        now,
        customFrom: ui.customFromDate,
        customTo: ui.customToDate,
      )) {
        return false;
      }
      return true;
    }).toList();
  }

  String _buildCsv(List<Order> orders) {
    final buffer = StringBuffer();
    buffer.writeln(
      'order_number,business_name,customer_name,priority,status,payment_status,delivery_status,created_at',
    );
    for (final order in orders) {
      final created = order.createdAt?.toIso8601String() ?? '';
      buffer.writeln(
        '${order.displayOrderNumber},${_escape(order.businessName)},${_escape(order.customerName)},'
        '${OrderSharedHelpers.capitalize(order.priority.name)},${OrderSharedHelpers.capitalize(order.status.name)},${OrderSharedHelpers.capitalize(order.payment.status.name)},'
        '${OrderSharedHelpers.capitalize(order.delivery.status.name)},$created',
      );
    }
    return buffer.toString();
  }

  String _escape(String value) {
    final safe = value.replaceAll('"', '""');
    return '"$safe"';
  }

  @override
  Widget build(BuildContext context) {
    final ui = ref.watch(_orderHistoryUiProvider);
    final filtered = _filtered;
    final total = filtered.length;
    final completed = filtered
        .where((e) => e.status == OrderStatus.completed)
        .length;
    final pending = filtered
        .where((e) => e.status == OrderStatus.pending)
        .length;
    final paid = filtered
        .where((e) => e.payment.status == PaymentStatus.done)
        .length;
    final deliveryDone = filtered
        .where((e) => e.delivery.status == DeliveryStatus.delivered)
        .length;
    final fastOrders = filtered
        .where((e) => e.priority == OrderPriority.fast)
        .length;
    final avgItems = filtered.isEmpty
        ? 0.0
        : filtered.map((e) => e.items.length).reduce((a, b) => a + b) /
              filtered.length;
    final completionDurations = filtered
        .where(
          (e) =>
              e.status == OrderStatus.completed &&
              e.createdAt != null &&
              e.updatedAt != null,
        )
        .map((e) => e.updatedAt!.difference(e.createdAt!).inMinutes / 60)
        .toList();
    final avgCompletionHours = completionDurations.isEmpty
        ? 0.0
        : completionDurations.reduce((a, b) => a + b) /
              completionDurations.length;

    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                SizedBox(
                  width: 180,
                  child: DropdownButtonFormField<OrderStatus?>(
                    initialValue: ui.statusFilter,
                    decoration: const InputDecoration(
                      labelText: 'Status Filter',
                    ),
                    items: [
                      const DropdownMenuItem<OrderStatus?>(
                        value: null,
                        child: Text('All'),
                      ),
                      ...OrderStatus.values.map(
                        (value) => DropdownMenuItem<OrderStatus?>(
                          value: value,
                          child: Text(
                            OrderSharedHelpers.capitalize(value.name),
                          ),
                        ),
                      ),
                    ],
                    onChanged: (value) {
                      ref.read(_orderHistoryUiProvider.notifier).state = ui
                          .copyWith(statusFilter: value);
                    },
                  ),
                ),
                SizedBox(
                  width: 180,
                  child: DropdownButtonFormField<OrderPriority?>(
                    initialValue: ui.priorityFilter,
                    decoration: const InputDecoration(
                      labelText: 'Priority Filter',
                    ),
                    items: [
                      const DropdownMenuItem<OrderPriority?>(
                        value: null,
                        child: Text('All'),
                      ),
                      ...OrderPriority.values.map(
                        (value) => DropdownMenuItem<OrderPriority?>(
                          value: value,
                          child: Text(
                            OrderSharedHelpers.capitalize(value.name),
                          ),
                        ),
                      ),
                    ],
                    onChanged: (value) {
                      ref.read(_orderHistoryUiProvider.notifier).state = ui
                          .copyWith(priorityFilter: value);
                    },
                  ),
                ),
                SizedBox(
                  width: 180,
                  child: DropdownButtonFormField<OrderDateFilterOption>(
                    initialValue: ui.dateFilter,
                    decoration: const InputDecoration(labelText: 'Time Window'),
                    items: OrderDateFilterOption.values
                        .map(
                          (value) => DropdownMenuItem<OrderDateFilterOption>(
                            value: value,
                            child: Text(
                              OrderSharedHelpers.dateFilterLabel(value),
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      ref.read(_orderHistoryUiProvider.notifier).state = ui
                          .copyWith(
                            dateFilter: value ?? OrderDateFilterOption.all,
                          );
                      if (value == OrderDateFilterOption.custom &&
                          (ui.customFromDate == null ||
                              ui.customToDate == null)) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (!mounted) return;
                          _pickCustomRange(ref.read(_orderHistoryUiProvider));
                        });
                      }
                    },
                  ),
                ),
                if (ui.dateFilter == OrderDateFilterOption.custom)
                  SizedBox(
                    width: 360,
                    child: OrderDateRangeRow(
                      fromDate: ui.customFromDate,
                      toDate: ui.customToDate,
                      onSelect: () => _pickCustomRange(ui),
                      onClear: () {
                        ref.read(_orderHistoryUiProvider.notifier).state = ui
                            .copyWith(customFromDate: null, customToDate: null);
                      },
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                FilledButton.icon(
                  onPressed: filtered.isEmpty
                      ? null
                      : () async {
                          final csv = _buildCsv(filtered);
                          await Clipboard.setData(ClipboardData(text: csv));
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('CSV copied to clipboard'),
                            ),
                          );
                        },
                  icon: const Icon(Icons.copy_all),
                  label: const Text('Copy CSV'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _KpiCard(title: 'Total', value: '$total'),
                _KpiCard(title: 'Pending', value: '$pending'),
                _KpiCard(title: 'Completed', value: '$completed'),
                _KpiCard(title: 'Paid', value: '$paid'),
                _KpiCard(title: 'Delivered', value: '$deliveryDone'),
                _KpiCard(title: 'Fast Orders', value: '$fastOrders'),
                _KpiCard(
                  title: 'Avg Items/Order',
                  value: avgItems.toStringAsFixed(1),
                ),
                _KpiCard(
                  title: 'Avg Completion (hrs)',
                  value: avgCompletionHours.toStringAsFixed(1),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (filtered.isEmpty)
              const Text('No orders match current filters.'),
            ...filtered.map(
              (order) => OrderCardShell(
                margin: EdgeInsets.zero,
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => CustomerOrderDetailScreen(order: order),
                    ),
                  );
                },
                child: ListTile(
                  title: Text(
                    '${order.businessName} • ${OrderSharedHelpers.capitalize(order.status.name)}',
                  ),
                  subtitle: Text(
                    'Priority: ${OrderSharedHelpers.capitalize(order.priority.name)} | Items: ${order.items.length} | '
                    'Payment: ${OrderSharedHelpers.capitalize(order.payment.status.name)} | Delivery: ${OrderSharedHelpers.capitalize(order.delivery.status.name)}',
                  ),
                  trailing: Text(
                    order.createdAt == null
                        ? '-'
                        : order.createdAt!
                              .toLocal()
                              .toString()
                              .split('.')
                              .first,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({required this.title, required this.value});

  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 160,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 8),
              Text(value, style: Theme.of(context).textTheme.headlineSmall),
            ],
          ),
        ),
      ),
    );
  }
}
