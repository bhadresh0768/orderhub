import 'package:cloud_firestore/cloud_firestore.dart' hide Order;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:todo_reminder_alarm/models/app_user.dart';
import 'package:todo_reminder_alarm/models/enums.dart';
import 'package:todo_reminder_alarm/models/order.dart';
import 'package:todo_reminder_alarm/providers.dart';
import 'package:todo_reminder_alarm/ui/screens/orders/common/order_shared_helpers.dart';
import 'admin_customer_detail_screen.dart';
import 'admin_home_state.dart';

class AdminOrdersTab extends ConsumerStatefulWidget {
  const AdminOrdersTab({super.key});

  @override
  ConsumerState<AdminOrdersTab> createState() => _AdminOrdersTabState();
}

class _AdminOrdersTabState extends ConsumerState<AdminOrdersTab> {
  final _searchController = TextEditingController();
  static const _searchKey = 'orders';

  String _capitalize(String value) {
    if (value.isEmpty) return value;
    return value[0].toUpperCase() + value.substring(1);
  }

  String _dateFilterLabel(AdminOrderDateFilter filter) {
    return switch (filter) {
      AdminOrderDateFilter.all => 'All',
      AdminOrderDateFilter.today => 'Today',
      AdminOrderDateFilter.thisWeek => 'This Week',
      AdminOrderDateFilter.thisMonth => 'This Month',
      AdminOrderDateFilter.thisYear => 'This Year',
      AdminOrderDateFilter.custom => 'Custom Range',
    };
  }

  String _formatDate(DateTime date) {
    final mm = date.month.toString().padLeft(2, '0');
    final dd = date.day.toString().padLeft(2, '0');
    return '${date.year}-$mm-$dd';
  }

  bool _isInDateRange(DateTime date, DateTime from, DateTime to) {
    final start = DateTime(from.year, from.month, from.day);
    final endExclusive = DateTime(
      to.year,
      to.month,
      to.day,
    ).add(const Duration(days: 1));
    return !date.isBefore(start) && date.isBefore(endExclusive);
  }

  DateTime _effectiveOrderDate(Order order) {
    return order.createdAt ?? order.updatedAt ?? DateTime.now();
  }

  bool _matchesDateFilter(
    Order order,
    AdminOrderDateFilter filter,
    DateTime now,
    DateTime? from,
    DateTime? to,
  ) {
    if (filter == AdminOrderDateFilter.all) return true;
    final effectiveDate = _effectiveOrderDate(order);
    switch (filter) {
      case AdminOrderDateFilter.all:
        return true;
      case AdminOrderDateFilter.today:
        return effectiveDate.year == now.year &&
            effectiveDate.month == now.month &&
            effectiveDate.day == now.day;
      case AdminOrderDateFilter.thisWeek:
        final startOfToday = DateTime(now.year, now.month, now.day);
        final startOfWeek = startOfToday.subtract(
          Duration(days: now.weekday - 1),
        );
        final endOfWeek = startOfWeek.add(const Duration(days: 7));
        return !effectiveDate.isBefore(startOfWeek) &&
            effectiveDate.isBefore(endOfWeek);
      case AdminOrderDateFilter.thisMonth:
        return effectiveDate.year == now.year &&
            effectiveDate.month == now.month;
      case AdminOrderDateFilter.thisYear:
        return effectiveDate.year == now.year;
      case AdminOrderDateFilter.custom:
        if (from == null || to == null) return false;
        return _isInDateRange(effectiveDate, from, to);
    }
  }

  Future<void> _pickCustomRange() async {
    final now = DateTime.now();
    final from = ref.read(adminOrderFromDateProvider);
    final to = ref.read(adminOrderToDateProvider);
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year + 2),
      initialDateRange: (from != null && to != null)
          ? DateTimeRange(start: from, end: to)
          : null,
    );
    if (picked == null || !mounted) return;
    ref.read(adminOrderDateFilterProvider.notifier).state =
        AdminOrderDateFilter.custom;
    ref.read(adminOrderFromDateProvider.notifier).state = picked.start;
    ref.read(adminOrderToDateProvider.notifier).state = picked.end;
  }

  @override
  void initState() {
    super.initState();
    _searchController.text = ref.read(adminSearchProvider(_searchKey));
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _editOrderDialog(Order order) async {
    var status = order.status;
    var delivery = order.delivery.status;
    var paymentStatus = order.payment.status;
    var paymentMethod = order.payment.method;
    final amount = TextEditingController(
      text: order.payment.amount?.toStringAsFixed(2) ?? '',
    );
    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: Text('Edit Order ${order.displayOrderNumber}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<OrderStatus>(
                  initialValue: status,
                  items: OrderStatus.values
                      .map(
                        (e) => DropdownMenuItem(
                          value: e,
                          child: Text(_capitalize(e.name)),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setLocal(() => status = v ?? status),
                  decoration: const InputDecoration(labelText: 'Order Status'),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<DeliveryStatus>(
                  initialValue: delivery,
                  items: DeliveryStatus.values
                      .map(
                        (e) => DropdownMenuItem(
                          value: e,
                          child: Text(_capitalize(e.name)),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setLocal(() => delivery = v ?? delivery),
                  decoration: const InputDecoration(
                    labelText: 'Delivery Status',
                  ),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<PaymentStatus>(
                  initialValue: paymentStatus,
                  items: PaymentStatus.values
                      .map(
                        (e) => DropdownMenuItem(
                          value: e,
                          child: Text(_capitalize(e.name)),
                        ),
                      )
                      .toList(),
                  onChanged: (v) =>
                      setLocal(() => paymentStatus = v ?? paymentStatus),
                  decoration: const InputDecoration(
                    labelText: 'Payment Status',
                  ),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<PaymentMethod>(
                  initialValue: paymentMethod,
                  items: PaymentMethod.values
                      .map(
                        (e) => DropdownMenuItem(
                          value: e,
                          child: Text(_capitalize(e.name)),
                        ),
                      )
                      .toList(),
                  onChanged: (v) =>
                      setLocal(() => paymentMethod = v ?? paymentMethod),
                  decoration: const InputDecoration(
                    labelText: 'Payment Method',
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: amount,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Payment Amount',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                await ref.read(firestoreServiceProvider).updateOrder(order.id, {
                  'status': enumToString(status),
                  'delivery': {
                    ...order.delivery.toMap(),
                    'status': enumToString(delivery),
                    'updatedAt': Timestamp.fromDate(DateTime.now()),
                  },
                  'payment': {
                    ...order.payment.toMap(),
                    'status': enumToString(paymentStatus),
                    'method': enumToString(paymentMethod),
                    'amount': double.tryParse(amount.text.trim()),
                    'updatedAt': Timestamp.fromDate(DateTime.now()),
                  },
                });
                if (!mounted) return;
                Navigator.of(this.context).pop();
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    amount.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final search = ref.watch(adminSearchProvider(_searchKey));
    final dateFilter = ref.watch(adminOrderDateFilterProvider);
    final fromDate = ref.watch(adminOrderFromDateProvider);
    final toDate = ref.watch(adminOrderToDateProvider);
    final usersById = {
      for (final user in (ref.watch(allUsersProvider).value ?? <AppUser>[]))
        user.id: user,
    };
    final ordersAsync = ref.watch(allOrdersProvider);
    return ordersAsync.when(
      data: (orders) {
        final query = search.trim().toLowerCase();
        final now = DateTime.now();
        final filtered = orders.where((o) {
          if (!_matchesDateFilter(o, dateFilter, now, fromDate, toDate)) {
            return false;
          }
          if (query.isEmpty) return true;
          return o.displayOrderNumber.toLowerCase().contains(query) ||
              o.businessName.toLowerCase().contains(query) ||
              o.customerName.toLowerCase().contains(query);
        }).toList();
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                labelText: 'Search orders',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (value) {
                ref.read(adminSearchProvider(_searchKey).notifier).state =
                    value;
              },
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<AdminOrderDateFilter>(
              initialValue: dateFilter,
              decoration: const InputDecoration(labelText: 'Date Filter'),
              items: AdminOrderDateFilter.values
                  .map(
                    (value) => DropdownMenuItem(
                      value: value,
                      child: Text(_dateFilterLabel(value)),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value == null) return;
                ref.read(adminOrderDateFilterProvider.notifier).state = value;
                if (value == AdminOrderDateFilter.custom &&
                    (fromDate == null || toDate == null)) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (!mounted) return;
                    _pickCustomRange();
                  });
                }
              },
            ),
            if (dateFilter == AdminOrderDateFilter.custom) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      (fromDate != null && toDate != null)
                          ? '${_formatDate(fromDate)} to ${_formatDate(toDate)}'
                          : 'No date range selected',
                    ),
                  ),
                  TextButton(
                    onPressed: _pickCustomRange,
                    child: const Text('Select'),
                  ),
                  TextButton(
                    onPressed: () {
                      ref.read(adminOrderFromDateProvider.notifier).state =
                          null;
                      ref.read(adminOrderToDateProvider.notifier).state = null;
                    },
                    child: const Text('Clear'),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            if (filtered.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.only(top: 24),
                  child: Text('No orders match current filters.'),
                ),
              ),
            ...filtered.map((order) {
              return Card(
                child: ListTile(
                  title: Text(
                    'Order ${order.displayOrderNumber} • ${order.businessName}',
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text('Customer: '),
                          Flexible(
                            child: InkWell(
                              onTap: () {
                                final customer = usersById[order.customerId];
                                if (customer == null) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Customer details not found.',
                                      ),
                                    ),
                                  );
                                  return;
                                }
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => AdminCustomerDetailScreen(
                                      customer: customer,
                                    ),
                                  ),
                                );
                              },
                              child: Text(
                                order.customerName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  decoration: TextDecoration.underline,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      Text.rich(
                        TextSpan(
                          children: [
                            const TextSpan(text: 'Status: '),
                            TextSpan(
                              text: OrderSharedHelpers.statusLabel(
                                OrderSharedHelpers.effectiveStatus(order),
                              ),
                              style: TextStyle(
                                color: OrderSharedHelpers.statusColor(
                                  OrderSharedHelpers.effectiveStatus(order),
                                ),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            TextSpan(
                              text:
                                  ' • Payment: ${_capitalize(order.payment.status.name)} • Delivery: ${_capitalize(order.delivery.status.name)}',
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  isThreeLine: true,
                  trailing: PopupMenuButton<String>(
                    onSelected: (value) async {
                      if (value == 'edit') {
                        await _editOrderDialog(order);
                      } else if (value == 'delete') {
                        await ref
                            .read(firestoreServiceProvider)
                            .deleteOrder(order.id);
                      }
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'edit', child: Text('Edit')),
                      PopupMenuItem(value: 'delete', child: Text('Delete')),
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
