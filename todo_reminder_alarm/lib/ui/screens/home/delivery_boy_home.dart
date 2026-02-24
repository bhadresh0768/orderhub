import 'package:cloud_firestore/cloud_firestore.dart' hide Order;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart' show StateProvider;

import '../../../models/enums.dart';
import '../../../models/order.dart';
import '../../../providers.dart';

enum _DeliveryDateFilter { today, week, month, year }

final _deliveryBoyUiProvider = StateProvider.autoDispose<_DeliveryBoyUiState>(
  (ref) => const _DeliveryBoyUiState(),
);

class _DeliveryBoyUiState {
  const _DeliveryBoyUiState({this.filter = _DeliveryDateFilter.month});

  final _DeliveryDateFilter filter;

  _DeliveryBoyUiState copyWith({_DeliveryDateFilter? filter}) {
    return _DeliveryBoyUiState(filter: filter ?? this.filter);
  }
}

class DeliveryBoyHomeScreen extends ConsumerWidget {
  const DeliveryBoyHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authUser = ref.watch(authStateProvider).value;
    if (authUser == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final profileAsync = ref.watch(userProfileProvider(authUser.uid));
    return profileAsync.when(
      data: (profile) {
        if (profile == null) {
          return const Scaffold(body: Center(child: Text('No profile found')));
        }
        final phone = (profile.phoneNumber ?? '').trim();
        if (phone.isEmpty) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('Delivery Dashboard'),
              actions: [
                IconButton(
                  onPressed: () => ref.read(authServiceProvider).signOut(),
                  icon: const Icon(Icons.logout),
                  tooltip: 'Logout',
                ),
              ],
            ),
            body: const Center(
              child: Text('Phone number missing in profile. Contact admin.'),
            ),
          );
        }
        return _DeliveryBoyBody(phone: phone, name: profile.name);
      },
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (err, _) => Scaffold(body: Center(child: Text('Error: $err'))),
    );
  }
}

class _DeliveryBoyBody extends ConsumerStatefulWidget {
  const _DeliveryBoyBody({required this.phone, required this.name});

  final String phone;
  final String name;

  @override
  ConsumerState<_DeliveryBoyBody> createState() => _DeliveryBoyBodyState();
}

class _DeliveryBoyBodyState extends ConsumerState<_DeliveryBoyBody> {
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
    }
  }

  String _formatQty(double value) {
    return value == value.truncateToDouble()
        ? value.toInt().toString()
        : value.toStringAsFixed(2);
  }

  String _shortUnit(QuantityUnit unit) {
    switch (unit) {
      case QuantityUnit.piece:
        return 'pc';
      case QuantityUnit.kilogram:
        return 'kg';
      case QuantityUnit.gram:
        return 'g';
      case QuantityUnit.liter:
        return 'L';
    }
  }

  String _itemSummary(OrderItem item) {
    final base =
        '${item.title} ${_formatQty(item.quantity)} ${_shortUnit(item.unit)}';
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
                  decoration: const InputDecoration(labelText: 'Payment Method'),
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
    // Do not dispose immediately after Navigator.pop; dialog widgets may still
    // be in transition and attached for one frame.
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

  @override
  Widget build(BuildContext context) {
    final uiState = ref.watch(_deliveryBoyUiProvider);
    final ordersAsync = ref.watch(
      ordersForDeliveryAgentByPhoneProvider(widget.phone),
    );
    return Scaffold(
      appBar: AppBar(
        title: Text('Delivery Dashboard • ${widget.name}'),
        actions: [
          IconButton(
            onPressed: () => ref.read(authServiceProvider).signOut(),
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
          ),
        ],
      ),
      body: ordersAsync.when(
        data: (orders) {
          if (orders.isEmpty) {
            return const Center(child: Text('No deliveries assigned.'));
          }

          final upcomingOrders = orders
              .where(
                (order) => order.delivery.status != DeliveryStatus.delivered,
              )
              .where((order) => _matchesRange(order, completedTab: false))
              .toList();
          final completedOrders = orders
              .where(
                (order) => order.delivery.status == DeliveryStatus.delivered,
              )
              .where((order) => _matchesRange(order, completedTab: true))
              .toList();

          return DefaultTabController(
            length: 2,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<_DeliveryDateFilter>(
                          initialValue: uiState.filter,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Filter',
                          ),
                          items: _DeliveryDateFilter.values
                              .map(
                                (value) => DropdownMenuItem(
                                  value: value,
                                  child: Text(_filterLabel(value)),
                                ),
                              )
                              .toList(),
                          onChanged: (value) {
                            if (value != null) {
                              ref.read(_deliveryBoyUiProvider.notifier).state =
                                  uiState.copyWith(filter: value);
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                const TabBar(
                  tabs: [
                    Tab(text: 'Upcoming Delivery'),
                    Tab(text: 'Completed Delivery'),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      _buildOrdersList(
                        context,
                        upcomingOrders,
                        allowActions: true,
                        emptyText: 'No upcoming deliveries in this range.',
                      ),
                      _buildOrdersList(
                        context,
                        completedOrders,
                        allowActions: false,
                        emptyText: 'No completed deliveries in this range.',
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error: $err')),
      ),
    );
  }

  Widget _buildOrdersList(
    BuildContext context,
    List<Order> orders, {
    required bool allowActions,
    required String emptyText,
  }) {
    if (orders.isEmpty) {
      return Center(child: Text(emptyText));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: orders.length,
      itemBuilder: (context, index) {
        final order = orders[index];
        final items = order.items.map(_itemSummary).join(', ');
        final paymentPending = order.payment.status == PaymentStatus.pending;
        final amount = order.payment.amount;
        final amountText = amount == null
            ? 'Not set'
            : (amount == amount.truncateToDouble()
                  ? amount.toInt().toString()
                  : amount.toStringAsFixed(2));
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (paymentPending)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 6),
                    child: Row(
                      children: [
                        Icon(
                          Icons.warning_amber_rounded,
                          color: Colors.deepOrange,
                          size: 16,
                        ),
                        SizedBox(width: 6),
                        Text('Payment Remaining'),
                      ],
                    ),
                  ),
                Text(
                  '${order.businessName} → ${order.customerName}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 6),
                Text(
                  'Order ${order.displayOrderNumber} • ${order.delivery.status.name}',
                ),
                const SizedBox(height: 4),
                Text(
                  'Payment: ${order.payment.status.name} • Amount: $amountText',
                ),
                if (order.payment.collectedBy != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      'Collected by: ${order.payment.collectedBy == PaymentCollectedBy.deliveryBoy ? 'Delivery Boy' : 'Business'}'
                      '${(order.payment.collectedByName ?? '').trim().isEmpty ? '' : ' (${order.payment.collectedByName})'}',
                    ),
                  ),
                const SizedBox(height: 4),
                Text('Items: $items'),
                if (allowActions) ...[
                  const SizedBox(height: 10),
                  FilledButton(
                    onPressed: () => _updateDeliveryStatus(
                      context,
                      ref,
                      order,
                      DeliveryStatus.delivered,
                    ),
                    child: const Text('Delivered'),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
