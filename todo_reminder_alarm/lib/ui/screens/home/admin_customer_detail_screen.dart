import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart' show StateProvider;
import 'package:android_intent_plus/android_intent.dart';

import '../../../models/app_user.dart';
import '../../../models/enums.dart';
import '../../../models/order.dart';
import '../../../providers.dart';
import '../orders/customer_order_detail_screen.dart';

enum _AdminCustomerDateFilter {
  all,
  today,
  thisWeek,
  thisMonth,
  thisYear,
  custom,
}

final _adminCustomerStatusFilterProvider =
    StateProvider.autoDispose.family<OrderStatus?, String>((ref, _) => null);
final _adminCustomerDateFilterProvider =
    StateProvider.autoDispose.family<_AdminCustomerDateFilter, String>(
      (ref, _) => _AdminCustomerDateFilter.all,
    );
final _adminCustomerFromDateProvider =
    StateProvider.autoDispose.family<DateTime?, String>((ref, _) => null);
final _adminCustomerToDateProvider =
    StateProvider.autoDispose.family<DateTime?, String>((ref, _) => null);
final _adminCustomerPageProvider =
    StateProvider.autoDispose.family<int, String>((ref, _) => 0);

class AdminCustomerDetailScreen extends ConsumerWidget {
  const AdminCustomerDetailScreen({super.key, required this.customer});

  final AppUser customer;

  static const _pageSize = 10;

  String _digitsOnly(String value) => value.replaceAll(RegExp(r'[^0-9]'), '');

  Future<void> _callCustomer(BuildContext context, String phone) async {
    try {
      final intent = AndroidIntent(
        action: 'android.intent.action.DIAL',
        data: 'tel:$phone',
      );
      await intent.launch();
    } catch (_) {
      await Clipboard.setData(ClipboardData(text: phone));
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Call failed. Number copied.')),
      );
    }
  }

  Future<void> _openWhatsApp(BuildContext context, String phone) async {
    final digits = _digitsOnly(phone);
    if (digits.isEmpty) return;
    try {
      final intent = AndroidIntent(
        action: 'android.intent.action.VIEW',
        data: 'https://wa.me/$digits',
      );
      await intent.launch();
    } catch (_) {
      await Clipboard.setData(ClipboardData(text: phone));
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('WhatsApp open failed. Number copied.')),
      );
    }
  }

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

  Widget _infoTile(BuildContext context, String label, String value) {
    final screenWidth = MediaQuery.of(context).size.width;
    final width = (screenWidth - 16 - 16 - 24 - 10) / 2;
    return SizedBox(
      width: width,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: Colors.black54),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
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
    final statusFilter = ref.watch(_adminCustomerStatusFilterProvider(customer.id));
    final dateFilter = ref.watch(_adminCustomerDateFilterProvider(customer.id));
    final fromDate = ref.watch(_adminCustomerFromDateProvider(customer.id));
    final toDate = ref.watch(_adminCustomerToDateProvider(customer.id));
    final pageIndex = ref.watch(_adminCustomerPageProvider(customer.id));
    final ordersAsync = ref.watch(allOrdersProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          customer.name.isEmpty
              ? 'Customer Details'
              : '${customer.name} Details',
        ),
      ),
      body: SafeArea(
        top: false,
        child: ordersAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, _) => Center(child: Text('Error: $err')),
          data: (orders) {
            final customerOrders = orders.where((o) => o.customerId == customer.id);
            final filteredOrders = customerOrders.where((order) {
              if (statusFilter != null && order.status != statusFilter) {
                return false;
              }
              return _matchesDateFilter(order, dateFilter, fromDate, toDate);
            }).toList()
              ..sort((a, b) {
                final ad = a.createdAt ?? a.updatedAt ?? DateTime(1970);
                final bd = b.createdAt ?? b.updatedAt ?? DateTime(1970);
                return bd.compareTo(ad);
              });

            final totalPages = filteredOrders.isEmpty
                ? 1
                : (filteredOrders.length / _pageSize).ceil();
            final safePage = pageIndex >= totalPages ? totalPages - 1 : pageIndex;
            if (safePage != pageIndex) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                ref.read(_adminCustomerPageProvider(customer.id).notifier).state =
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
                          children: [
                            CircleAvatar(
                              radius: 28,
                              backgroundColor: Colors.black12,
                              backgroundImage: _display(customer.photoUrl) != '-'
                                  ? NetworkImage(customer.photoUrl!.trim())
                                  : null,
                              child: _display(customer.photoUrl) == '-'
                                  ? const Icon(Icons.person_outline)
                                  : null,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _display(customer.name),
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            _infoTile(context, 'Name', _display(customer.name)),
                            _infoTile(
                              context,
                              'Mobile',
                              _display(customer.phoneNumber),
                            ),
                            _infoTile(context, 'Email', _display(customer.email)),
                            _infoTile(
                              context,
                              'Role',
                              _capitalize(customer.role.name),
                            ),
                            _infoTile(
                              context,
                              'Status',
                              customer.isActive ? 'Active' : 'Inactive',
                            ),
                            _infoTile(
                              context,
                              'Shop Name',
                              _display(customer.shopName),
                            ),
                            _infoTile(
                              context,
                              'Address',
                              _display(customer.address),
                            ),
                            _infoTile(
                              context,
                              'App Share Link',
                              _display(customer.appShareLink),
                            ),
                            _infoTile(context, 'User ID', customer.id),
                            _infoTile(
                              context,
                              'Business ID',
                              _display(customer.businessId),
                            ),
                            _infoTile(
                              context,
                              'Registration Date',
                              customer.createdAt == null
                                  ? '-'
                                  : _formatDateTime(customer.createdAt!),
                            ),
                            _infoTile(
                              context,
                              'Delete Request',
                              _display(customer.deleteRequestStatus),
                            ),
                            _infoTile(
                              context,
                              'Delete Requested At',
                              customer.deleteRequestedAt == null
                                  ? '-'
                                  : _formatDateTime(customer.deleteRequestedAt!),
                            ),
                            _infoTile(
                              context,
                              'Total Orders (Filtered)',
                              '${filteredOrders.length}',
                            ),
                          ],
                        ),
                        if (_display(customer.phoneNumber) != '-') ...[
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () => _callCustomer(
                                    context,
                                    customer.phoneNumber!.trim(),
                                  ),
                                  icon: const Icon(Icons.call_outlined),
                                  label: const Text('Call'),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () => _openWhatsApp(
                                    context,
                                    customer.phoneNumber!.trim(),
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
                                _adminCustomerStatusFilterProvider(customer.id)
                                    .notifier,
                              )
                              .state = value;
                          ref
                              .read(_adminCustomerPageProvider(customer.id).notifier)
                              .state = 0;
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<_AdminCustomerDateFilter>(
                        initialValue: dateFilter,
                        decoration: const InputDecoration(labelText: 'Date Filter'),
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
                                _adminCustomerDateFilterProvider(customer.id)
                                    .notifier,
                              )
                              .state = value;
                          ref
                              .read(_adminCustomerPageProvider(customer.id).notifier)
                              .state = 0;
                          if (value != _AdminCustomerDateFilter.custom) {
                            ref
                                .read(
                                  _adminCustomerFromDateProvider(customer.id)
                                      .notifier,
                                )
                                .state = null;
                            ref
                                .read(
                                  _adminCustomerToDateProvider(customer.id).notifier,
                                )
                                .state = null;
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
                                _adminCustomerFromDateProvider(customer.id).notifier,
                              )
                              .state = null;
                          ref
                              .read(
                                _adminCustomerToDateProvider(customer.id).notifier,
                              )
                              .state = null;
                          ref
                              .read(
                                _adminCustomerDateFilterProvider(customer.id)
                                    .notifier,
                              )
                              .state = _AdminCustomerDateFilter.all;
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
                    final payment = _capitalize(order.payment.status.name);
                    final delivery = _capitalize(order.delivery.status.name);
                    return Card(
                      child: ListTile(
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => CustomerOrderDetailScreen(order: order),
                            ),
                          );
                        },
                        title: Text('Order ${order.displayOrderNumber}'),
                        subtitle: Text(
                          'Business: ${order.businessName}\n'
                          'Status: ${_statusLabel(order.status)}\n'
                          'Payment: $payment • Delivery: $delivery\n'
                          'Created: ${created == null ? '-' : created.toLocal()}',
                        ),
                        isThreeLine: true,
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
                                    _adminCustomerPageProvider(customer.id)
                                        .notifier,
                                  )
                                  .state = safePage - 1;
                            },
                      child: const Text('Prev'),
                    ),
                    TextButton(
                      onPressed: safePage >= totalPages - 1
                          ? null
                          : () {
                              ref
                                  .read(
                                    _adminCustomerPageProvider(customer.id)
                                        .notifier,
                                  )
                                  .state = safePage + 1;
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
