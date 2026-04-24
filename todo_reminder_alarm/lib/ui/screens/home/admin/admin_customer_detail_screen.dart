import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart' show StateProvider;

import 'package:todo_reminder_alarm/models/app_user.dart';
import 'package:todo_reminder_alarm/models/enums.dart';
import 'package:todo_reminder_alarm/models/order.dart';
import 'package:todo_reminder_alarm/providers.dart';
import 'package:todo_reminder_alarm/features/orders/presentation/common/order_shared_helpers.dart';
import 'package:todo_reminder_alarm/features/orders/presentation/customer_order_detail_screen.dart';
import 'package:todo_reminder_alarm/utils/contact_actions.dart';
import 'admin_edit_dialogs.dart';

enum _AdminCustomerDateFilter {
  all,
  today,
  thisWeek,
  thisMonth,
  thisYear,
  custom,
}

final _adminCustomerStatusFilterProvider = StateProvider.autoDispose
    .family<OrderStatus?, String>((ref, _) => null);
final _adminCustomerDateFilterProvider = StateProvider.autoDispose
    .family<_AdminCustomerDateFilter, String>(
      (ref, _) => _AdminCustomerDateFilter.all,
    );
final _adminCustomerFromDateProvider = StateProvider.autoDispose
    .family<DateTime?, String>((ref, _) => null);
final _adminCustomerToDateProvider = StateProvider.autoDispose
    .family<DateTime?, String>((ref, _) => null);
final _adminCustomerPageProvider = StateProvider.autoDispose
    .family<int, String>((ref, _) => 0);

class AdminCustomerDetailScreen extends ConsumerWidget {
  const AdminCustomerDetailScreen({super.key, required this.customer});

  final AppUser customer;

  static const _pageSize = 10;

  String _statusLabel(OrderStatus status) {
    return switch (status) {
      OrderStatus.pending => 'Pending',
      OrderStatus.approved || OrderStatus.inProgress => 'Processing',
      OrderStatus.completed => 'Completed',
      OrderStatus.cancelled => 'Cancelled',
    };
  }

  String _dateFilterLabel(_AdminCustomerDateFilter filter) {
    return switch (filter) {
      _AdminCustomerDateFilter.all => 'All',
      _AdminCustomerDateFilter.today => 'Today',
      _AdminCustomerDateFilter.thisWeek => 'This Week',
      _AdminCustomerDateFilter.thisMonth => 'This Month',
      _AdminCustomerDateFilter.thisYear => 'This Year',
      _AdminCustomerDateFilter.custom => 'Custom Range',
    };
  }

  String _capitalize(String value) {
    if (value.isEmpty) return value;
    return value[0].toUpperCase() + value.substring(1);
  }

  String _formatDate(DateTime date) {
    final d = date.toLocal();
    final month = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '${d.year}-$month-$day';
  }

  String _formatDateTime(DateTime date) {
    final d = date.toLocal();
    final month = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    final hour = d.hour.toString().padLeft(2, '0');
    final minute = d.minute.toString().padLeft(2, '0');
    return '${d.year}-$month-$day $hour:$minute';
  }

  String _display(String? value) {
    final text = value?.trim() ?? '';
    return text.isEmpty ? '-' : text;
  }

  Widget _buildInfoGrid(
    BuildContext context,
    List<MapEntry<String, String>> fields,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 720;
        final itemWidth = isWide
            ? (constraints.maxWidth - 12) / 2
            : constraints.maxWidth;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: fields
              .map(
                (field) => SizedBox(
                  width: itemWidth,
                  child: _infoTile(context, field.key, field.value),
                ),
              )
              .toList(),
        );
      },
    );
  }

  Widget _infoTile(BuildContext context, String label, String value) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: Colors.black54),
            ),
            const SizedBox(height: 4),
            Text(value, style: Theme.of(context).textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }

  bool _isInDateRange(DateTime date, DateTime from, DateTime to) {
    final local = date.toLocal();
    final start = DateTime(from.year, from.month, from.day);
    final end = DateTime(to.year, to.month, to.day, 23, 59, 59, 999);
    return !local.isBefore(start) && !local.isAfter(end);
  }

  bool _matchesDateFilter(
    Order order,
    _AdminCustomerDateFilter filter,
    DateTime? from,
    DateTime? to,
  ) {
    final date = order.createdAt ?? order.updatedAt;
    if (date == null) return filter == _AdminCustomerDateFilter.all;
    final now = DateTime.now();
    final local = date.toLocal();
    switch (filter) {
      case _AdminCustomerDateFilter.all:
        return true;
      case _AdminCustomerDateFilter.today:
        return local.year == now.year &&
            local.month == now.month &&
            local.day == now.day;
      case _AdminCustomerDateFilter.thisWeek:
        final start = DateTime(
          now.year,
          now.month,
          now.day,
        ).subtract(Duration(days: now.weekday - 1));
        final end = start.add(const Duration(days: 6, hours: 23, minutes: 59));
        return !local.isBefore(start) && !local.isAfter(end);
      case _AdminCustomerDateFilter.thisMonth:
        return local.year == now.year && local.month == now.month;
      case _AdminCustomerDateFilter.thisYear:
        return local.year == now.year;
      case _AdminCustomerDateFilter.custom:
        if (from == null || to == null) return false;
        return _isInDateRange(local, from, to);
    }
  }

  Future<void> _pickCustomRange(BuildContext context, WidgetRef ref) async {
    final from = ref.read(_adminCustomerFromDateProvider(customer.id));
    final to = ref.read(_adminCustomerToDateProvider(customer.id));
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      initialDateRange: (from != null && to != null)
          ? DateTimeRange(start: from, end: to)
          : null,
    );
    if (picked == null) return;
    ref.read(_adminCustomerDateFilterProvider(customer.id).notifier).state =
        _AdminCustomerDateFilter.custom;
    ref.read(_adminCustomerFromDateProvider(customer.id).notifier).state =
        picked.start;
    ref.read(_adminCustomerToDateProvider(customer.id).notifier).state =
        picked.end;
    ref.read(_adminCustomerPageProvider(customer.id).notifier).state = 0;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final customerAsync = ref.watch(userProfileProvider(customer.id));
    final currentCustomer = customerAsync.value ?? customer;
    final statusFilter = ref.watch(
      _adminCustomerStatusFilterProvider(currentCustomer.id),
    );
    final dateFilter = ref.watch(
      _adminCustomerDateFilterProvider(currentCustomer.id),
    );
    final fromDate = ref.watch(
      _adminCustomerFromDateProvider(currentCustomer.id),
    );
    final toDate = ref.watch(_adminCustomerToDateProvider(currentCustomer.id));
    final pageIndex = ref.watch(_adminCustomerPageProvider(currentCustomer.id));
    final ordersAsync = ref.watch(allOrdersProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          currentCustomer.name.isEmpty
              ? 'Customer Details'
              : '${currentCustomer.name} Details',
        ),
        actions: [
          IconButton(
            onPressed: () => showAdminUserDialog(context, ref, currentCustomer),
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Edit',
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: ordersAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, _) => Center(child: Text('Error: $err')),
          data: (orders) {
            final customerOrders = orders.where(
              (o) => o.customerId == currentCustomer.id,
            );
            final filteredOrders =
                customerOrders.where((order) {
                  if (statusFilter != null && order.status != statusFilter) {
                    return false;
                  }
                  return _matchesDateFilter(
                    order,
                    dateFilter,
                    fromDate,
                    toDate,
                  );
                }).toList()..sort((a, b) {
                  final ad = a.createdAt ?? a.updatedAt ?? DateTime(1970);
                  final bd = b.createdAt ?? b.updatedAt ?? DateTime(1970);
                  return bd.compareTo(ad);
                });

            final totalPages = filteredOrders.isEmpty
                ? 1
                : (filteredOrders.length / _pageSize).ceil();
            final safePage = pageIndex >= totalPages
                ? totalPages - 1
                : pageIndex;
            if (safePage != pageIndex) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                ref
                        .read(
                          _adminCustomerPageProvider(
                            currentCustomer.id,
                          ).notifier,
                        )
                        .state =
                    safePage;
              });
            }

            final start = safePage * _pageSize;
            final end = (start + _pageSize > filteredOrders.length)
                ? filteredOrders.length
                : start + _pageSize;
            final pageItems = filteredOrders.isEmpty
                ? <Order>[]
                : filteredOrders.sublist(start, end);
            final fields = <MapEntry<String, String>>[
              MapEntry('Name', _display(currentCustomer.name)),
              MapEntry('Mobile', _display(currentCustomer.phoneNumber)),
              MapEntry('Email', _display(currentCustomer.email)),
              MapEntry('Role', _capitalize(currentCustomer.role.name)),
              MapEntry(
                'Status',
                currentCustomer.isActive ? 'Active' : 'Inactive',
              ),
              MapEntry('Shop Name', _display(currentCustomer.shopName)),
              MapEntry('Address', _display(currentCustomer.address)),
              MapEntry(
                'App Share Link',
                _display(currentCustomer.appShareLink),
              ),
              MapEntry('User ID', currentCustomer.id),
              MapEntry('Business ID', _display(currentCustomer.businessId)),
              MapEntry(
                'Registration Date',
                currentCustomer.createdAt == null
                    ? '-'
                    : _formatDateTime(currentCustomer.createdAt!),
              ),
              MapEntry(
                'Delete Request',
                _display(currentCustomer.deleteRequestStatus),
              ),
              MapEntry(
                'Delete Requested At',
                currentCustomer.deleteRequestedAt == null
                    ? '-'
                    : _formatDateTime(currentCustomer.deleteRequestedAt!),
              ),
              MapEntry('Total Orders (Filtered)', '${filteredOrders.length}'),
            ];

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CircleAvatar(
                              radius: 28,
                              backgroundColor: Colors.black12,
                              backgroundImage:
                                  _display(currentCustomer.photoUrl) != '-'
                                  ? NetworkImage(
                                      currentCustomer.photoUrl!.trim(),
                                    )
                                  : null,
                              child: _display(currentCustomer.photoUrl) == '-'
                                  ? const Icon(Icons.person_outline)
                                  : null,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _display(currentCustomer.name),
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleLarge
                                        ?.copyWith(fontWeight: FontWeight.w700),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${_capitalize(currentCustomer.role.name)} • ${currentCustomer.isActive ? 'Active' : 'Inactive'}',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodyMedium,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _buildInfoGrid(context, fields),
                        if (_display(currentCustomer.phoneNumber) != '-') ...[
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () => ContactActions.callPhone(
                                    context,
                                    currentCustomer.phoneNumber!.trim(),
                                  ),
                                  icon: const Icon(Icons.call_outlined),
                                  label: const Text('Call'),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () => ContactActions.openWhatsApp(
                                    context,
                                    currentCustomer.phoneNumber!.trim(),
                                  ),
                                  icon: const Icon(Icons.chat_bubble_outline),
                                  label: const Text('WhatsApp'),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<OrderStatus?>(
                        initialValue: statusFilter,
                        decoration: const InputDecoration(
                          labelText: 'Status Filter',
                        ),
                        items: [
                          const DropdownMenuItem<OrderStatus?>(
                            value: null,
                            child: Text('All'),
                          ),
                          ...OrderStatus.values.map(
                            (status) => DropdownMenuItem<OrderStatus?>(
                              value: status,
                              child: Text(_statusLabel(status)),
                            ),
                          ),
                        ],
                        onChanged: (value) {
                          ref
                                  .read(
                                    _adminCustomerStatusFilterProvider(
                                      currentCustomer.id,
                                    ).notifier,
                                  )
                                  .state =
                              value;
                          ref
                                  .read(
                                    _adminCustomerPageProvider(
                                      currentCustomer.id,
                                    ).notifier,
                                  )
                                  .state =
                              0;
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<_AdminCustomerDateFilter>(
                        initialValue: dateFilter,
                        decoration: const InputDecoration(
                          labelText: 'Date Filter',
                        ),
                        items: _AdminCustomerDateFilter.values
                            .map(
                              (value) => DropdownMenuItem(
                                value: value,
                                child: Text(_dateFilterLabel(value)),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          if (value == null) return;
                          ref
                                  .read(
                                    _adminCustomerDateFilterProvider(
                                      currentCustomer.id,
                                    ).notifier,
                                  )
                                  .state =
                              value;
                          ref
                                  .read(
                                    _adminCustomerPageProvider(
                                      currentCustomer.id,
                                    ).notifier,
                                  )
                                  .state =
                              0;
                          if (value != _AdminCustomerDateFilter.custom) {
                            ref
                                    .read(
                                      _adminCustomerFromDateProvider(
                                        currentCustomer.id,
                                      ).notifier,
                                    )
                                    .state =
                                null;
                            ref
                                    .read(
                                      _adminCustomerToDateProvider(
                                        currentCustomer.id,
                                      ).notifier,
                                    )
                                    .state =
                                null;
                          } else if (fromDate == null || toDate == null) {
                            _pickCustomRange(context, ref);
                          }
                        },
                      ),
                    ),
                  ],
                ),
                if (dateFilter == _AdminCustomerDateFilter.custom) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          (fromDate != null && toDate != null)
                              ? '${_formatDate(fromDate)} to ${_formatDate(toDate)}'
                              : 'No custom range selected',
                        ),
                      ),
                      TextButton(
                        onPressed: () => _pickCustomRange(context, ref),
                        child: const Text('Pick'),
                      ),
                      TextButton(
                        onPressed: () {
                          ref
                                  .read(
                                    _adminCustomerFromDateProvider(
                                      currentCustomer.id,
                                    ).notifier,
                                  )
                                  .state =
                              null;
                          ref
                                  .read(
                                    _adminCustomerToDateProvider(
                                      currentCustomer.id,
                                    ).notifier,
                                  )
                                  .state =
                              null;
                          ref
                                  .read(
                                    _adminCustomerDateFilterProvider(
                                      currentCustomer.id,
                                    ).notifier,
                                  )
                                  .state =
                              _AdminCustomerDateFilter.all;
                        },
                        child: const Text('Clear'),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 12),
                if (pageItems.isEmpty)
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('No orders found for selected filters.'),
                    ),
                  )
                else
                  ...pageItems.map((order) {
                    final created = order.createdAt ?? order.updatedAt;
                    final effectiveStatus = OrderSharedHelpers.effectiveStatus(
                      order,
                    );
                    final statusColor = OrderSharedHelpers.statusColor(
                      effectiveStatus,
                    );
                    final payment = _capitalize(order.payment.status.name);
                    final delivery = _capitalize(order.delivery.status.name);
                    return Card(
                      child: ListTile(
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) =>
                                  CustomerOrderDetailScreen(order: order),
                            ),
                          );
                        },
                        title: Text('Order ${order.displayOrderNumber}'),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Business: ${order.businessName}'),
                            Text.rich(
                              TextSpan(
                                children: [
                                  const TextSpan(text: 'Status: '),
                                  TextSpan(
                                    text: _statusLabel(effectiveStatus),
                                    style: TextStyle(
                                      color: statusColor,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Text('Payment: $payment • Delivery: $delivery'),
                            Text(
                              'Created: ${created == null ? '-' : created.toLocal()}',
                            ),
                          ],
                        ),
                        isThreeLine: false,
                        trailing: const Icon(Icons.chevron_right),
                      ),
                    );
                  }),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text('Page ${safePage + 1} / $totalPages'),
                    const Spacer(),
                    TextButton(
                      onPressed: safePage <= 0
                          ? null
                          : () {
                              ref
                                      .read(
                                        _adminCustomerPageProvider(
                                          currentCustomer.id,
                                        ).notifier,
                                      )
                                      .state =
                                  safePage - 1;
                            },
                      child: const Text('Prev'),
                    ),
                    TextButton(
                      onPressed: safePage >= totalPages - 1
                          ? null
                          : () {
                              ref
                                      .read(
                                        _adminCustomerPageProvider(
                                          currentCustomer.id,
                                        ).notifier,
                                      )
                                      .state =
                                  safePage + 1;
                            },
                      child: const Text('Next'),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
