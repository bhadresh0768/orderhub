import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart' show StateProvider;

import '../../../models/app_user.dart';
import '../../../models/business.dart';
import '../../../models/enums.dart';
import '../../../models/order.dart';
import '../../../providers.dart';
import '../orders/customer_order_detail_screen.dart';

enum _AdminBusinessDateFilter {
  all,
  today,
  thisWeek,
  thisMonth,
  thisYear,
  custom,
}

final _adminBusinessStatusFilterProvider = StateProvider.autoDispose
    .family<OrderStatus?, String>((ref, _) => null);
final _adminBusinessDateFilterProvider = StateProvider.autoDispose
    .family<_AdminBusinessDateFilter, String>(
      (ref, _) => _AdminBusinessDateFilter.all,
    );
final _adminBusinessFromDateProvider = StateProvider.autoDispose
    .family<DateTime?, String>((ref, _) => null);
final _adminBusinessToDateProvider = StateProvider.autoDispose
    .family<DateTime?, String>((ref, _) => null);

class AdminBusinessDetailScreen extends ConsumerWidget {
  const AdminBusinessDetailScreen({super.key, required this.business});

  final BusinessProfile business;

  String _statusLabel(OrderStatus status) {
    return switch (status) {
      OrderStatus.pending => 'Pending',
      OrderStatus.approved || OrderStatus.inProgress => 'Processing',
      OrderStatus.completed => 'Completed',
      OrderStatus.cancelled => 'Cancelled',
    };
  }

  String _dateFilterLabel(_AdminBusinessDateFilter filter) {
    return switch (filter) {
      _AdminBusinessDateFilter.all => 'All',
      _AdminBusinessDateFilter.today => 'Today',
      _AdminBusinessDateFilter.thisWeek => 'This Week',
      _AdminBusinessDateFilter.thisMonth => 'This Month',
      _AdminBusinessDateFilter.thisYear => 'This Year',
      _AdminBusinessDateFilter.custom => 'Custom Range',
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

  bool _isInDateRange(DateTime date, DateTime from, DateTime to) {
    final local = date.toLocal();
    final start = DateTime(from.year, from.month, from.day);
    final end = DateTime(to.year, to.month, to.day, 23, 59, 59, 999);
    return !local.isBefore(start) && !local.isAfter(end);
  }

  bool _matchesDateFilter(
    Order order,
    _AdminBusinessDateFilter filter,
    DateTime? from,
    DateTime? to,
  ) {
    final date = order.createdAt ?? order.updatedAt;
    if (date == null) return filter == _AdminBusinessDateFilter.all;
    final now = DateTime.now();
    final local = date.toLocal();
    switch (filter) {
      case _AdminBusinessDateFilter.all:
        return true;
      case _AdminBusinessDateFilter.today:
        return local.year == now.year &&
            local.month == now.month &&
            local.day == now.day;
      case _AdminBusinessDateFilter.thisWeek:
        final start = DateTime(
          now.year,
          now.month,
          now.day,
        ).subtract(Duration(days: now.weekday - 1));
        final end = start.add(const Duration(days: 6, hours: 23, minutes: 59));
        return !local.isBefore(start) && !local.isAfter(end);
      case _AdminBusinessDateFilter.thisMonth:
        return local.year == now.year && local.month == now.month;
      case _AdminBusinessDateFilter.thisYear:
        return local.year == now.year;
      case _AdminBusinessDateFilter.custom:
        if (from == null || to == null) return false;
        return _isInDateRange(local, from, to);
    }
  }

  Future<void> _pickCustomRange(BuildContext context, WidgetRef ref) async {
    final from = ref.read(_adminBusinessFromDateProvider(business.id));
    final to = ref.read(_adminBusinessToDateProvider(business.id));
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      initialDateRange: (from != null && to != null)
          ? DateTimeRange(start: from, end: to)
          : null,
    );
    if (picked == null) return;
    ref.read(_adminBusinessDateFilterProvider(business.id).notifier).state =
        _AdminBusinessDateFilter.custom;
    ref.read(_adminBusinessFromDateProvider(business.id).notifier).state =
        picked.start;
    ref.read(_adminBusinessToDateProvider(business.id).notifier).state =
        picked.end;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ownerAsync = ref.watch(userProfileProvider(business.ownerId));
    final statusFilter = ref.watch(
      _adminBusinessStatusFilterProvider(business.id),
    );
    final dateFilter = ref.watch(_adminBusinessDateFilterProvider(business.id));
    final fromDate = ref.watch(_adminBusinessFromDateProvider(business.id));
    final toDate = ref.watch(_adminBusinessToDateProvider(business.id));
    final ordersAsync = ref.watch(allOrdersProvider);
    final agentsAsync = ref.watch(
      deliveryAgentsForBusinessProvider(business.id),
    );

    return Scaffold(
      appBar: AppBar(title: Text('${business.name} Details')),
      body: DefaultTabController(
        length: 2,
        child: SafeArea(
          top: false,
          child: ordersAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, _) => Center(child: Text('Error: $err')),
            data: (orders) {
              final businessOrders = orders
                  .where((order) => order.businessId == business.id)
                  .toList();
              final filteredOrders = businessOrders
                  .where((order) {
                    if (statusFilter != null && order.status != statusFilter) {
                      return false;
                    }
                    return _matchesDateFilter(order, dateFilter, fromDate, toDate);
                  })
                  .toList()
                ..sort((a, b) {
                  final ad = a.createdAt ?? a.updatedAt ?? DateTime(1970);
                  final bd = b.createdAt ?? b.updatedAt ?? DateTime(1970);
                  return bd.compareTo(ad);
                });

              final pendingCount = filteredOrders
                  .where((o) => o.status == OrderStatus.pending)
                  .length;
              final processingCount = filteredOrders
                  .where(
                    (o) =>
                        o.status == OrderStatus.approved ||
                        o.status == OrderStatus.inProgress,
                  )
                  .length;
              final completedCount = filteredOrders
                  .where((o) => o.status == OrderStatus.completed)
                  .length;

              return Column(
                children: [
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      children: [
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildBusinessLogo(),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _buildBusinessInfo(
                                    context,
                                    ownerAsync,
                                    businessOrders.length,
                                    filteredOrders.length,
                                    pendingCount,
                                    processingCount,
                                    completedCount,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        const TabBar(
                          tabs: [
                            Tab(text: 'Orders'),
                            Tab(text: 'Delivery Agents'),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: TabBarView(
                      children: [
                        _buildOrdersTab(
                          context,
                          ref,
                          filteredOrders,
                          dateFilter,
                          fromDate,
                          toDate,
                        ),
                        _buildAgentsTab(agentsAsync),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildBusinessLogo() {
    final logo = business.logoUrl?.trim();
    final hasLogo = logo != null && logo.isNotEmpty;
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 72,
        height: 72,
        color: Colors.black12,
        child: hasLogo
            ? Image.network(
                logo,
                fit: BoxFit.cover,
                errorBuilder: (_, error, stackTrace) =>
                    const Icon(Icons.storefront, size: 34),
              )
            : const Icon(Icons.storefront, size: 34),
      ),
    );
  }

  Widget _buildBusinessInfo(
    BuildContext context,
    AsyncValue<AppUser?> ownerAsync,
    int totalOrders,
    int filteredOrders,
    int pendingCount,
    int processingCount,
    int completedCount,
  ) {
    final owner = ownerAsync.asData?.value;
    final ownerName =
        (owner?.name.trim().isNotEmpty ?? false) ? owner!.name.trim() : '-';
    final ownerPhone =
        (owner?.phoneNumber?.trim().isNotEmpty ?? false)
            ? owner!.phoneNumber!.trim()
            : '-';
    final ownerEmail =
        (owner?.email.trim().isNotEmpty ?? false) ? owner!.email.trim() : '-';
    final businessPhone =
        (business.phone ?? '').trim().isEmpty ? '-' : business.phone!.trim();
    final businessUnique =
        (business.gstNumber ?? '').trim().isEmpty
            ? '-'
            : business.gstNumber!.trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          business.name,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _infoTile(context, 'Owner Name', ownerName),
            _infoTile(context, 'Owner Mobile', ownerPhone),
            _infoTile(context, 'Owner Email', ownerEmail),
            _infoTile(
              context,
              'Owner Registration Date',
              owner?.createdAt == null ? '-' : _formatDateTime(owner!.createdAt!),
            ),
            _infoTile(context, 'Business Name', business.name),
            _infoTile(context, 'Category', business.category),
            _infoTile(context, 'City', business.city.isEmpty ? '-' : business.city),
            _infoTile(
              context,
              'Address',
              (business.address ?? '').trim().isEmpty ? '-' : business.address!.trim(),
            ),
            _infoTile(context, 'Business Mobile', businessPhone),
            _infoTile(context, 'Business Unique No', businessUnique),
            _infoTile(context, 'Status', _capitalize(business.status.name)),
            _infoTile(
              context,
              'Business Registration Date',
              business.createdAt == null ? '-' : _formatDateTime(business.createdAt!),
            ),
            _infoTile(context, 'Total Orders', '$totalOrders'),
            _infoTile(context, 'Filtered Orders', '$filteredOrders'),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Pending: $pendingCount • Processing: $processingCount • Completed: $completedCount',
        ),
      ],
    );
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
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.black54,
                ),
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

  Widget _buildOrdersTab(
    BuildContext context,
    WidgetRef ref,
    List<Order> filteredOrders,
    _AdminBusinessDateFilter dateFilter,
    DateTime? fromDate,
    DateTime? toDate,
  ) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      children: [
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<OrderStatus?>(
                initialValue: ref.watch(_adminBusinessStatusFilterProvider(business.id)),
                decoration: const InputDecoration(labelText: 'Status Filter'),
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
                      .read(_adminBusinessStatusFilterProvider(business.id).notifier)
                      .state = value;
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: DropdownButtonFormField<_AdminBusinessDateFilter>(
                initialValue: dateFilter,
                decoration: const InputDecoration(labelText: 'Date Filter'),
                items: _AdminBusinessDateFilter.values
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
                      .read(_adminBusinessDateFilterProvider(business.id).notifier)
                      .state = value;
                  if (value != _AdminBusinessDateFilter.custom) {
                    ref
                        .read(_adminBusinessFromDateProvider(business.id).notifier)
                        .state = null;
                    ref
                        .read(_adminBusinessToDateProvider(business.id).notifier)
                        .state = null;
                  } else if (fromDate == null || toDate == null) {
                    _pickCustomRange(context, ref);
                  }
                },
              ),
            ),
          ],
        ),
        if (dateFilter == _AdminBusinessDateFilter.custom) ...[
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
                child: const Text('Select'),
              ),
              TextButton(
                onPressed: () {
                  ref
                      .read(_adminBusinessFromDateProvider(business.id).notifier)
                      .state = null;
                  ref
                      .read(_adminBusinessToDateProvider(business.id).notifier)
                      .state = null;
                },
                child: const Text('Clear'),
              ),
            ],
          ),
        ],
        const SizedBox(height: 8),
        if (filteredOrders.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(12),
              child: Text('No orders match current filters.'),
            ),
          ),
        ...filteredOrders.map((order) {
          return Card(
            child: ListTile(
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => CustomerOrderDetailScreen(order: order),
                  ),
                );
              },
              title: Text(
                'Order ${order.displayOrderNumber} • ${_statusLabel(order.status)}',
              ),
              subtitle: Text(
                'Order by: ${order.customerName}\n'
                'Payment: ${_capitalize(order.payment.status.name)} • Delivery: ${_capitalize(order.delivery.status.name)}',
              ),
              isThreeLine: true,
              trailing: const Icon(Icons.chevron_right),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildAgentsTab(AsyncValue agentsAsync) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      children: [
        agentsAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (err, _) => Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Text('Error: $err'),
            ),
          ),
          data: (agents) {
            if (agents.isEmpty) {
              return const Card(
                child: Padding(
                  padding: EdgeInsets.all(12),
                  child: Text('No delivery agents found for this business.'),
                ),
              );
            }
            return Column(
              children: agents
                  .map(
                    (agent) => Card(
                      child: ListTile(
                        title: Text(agent.name),
                        subtitle: Text(
                          '${agent.phone}\nStatus: ${agent.isActive ? 'Active' : 'Inactive'}',
                        ),
                        isThreeLine: true,
                      ),
                    ),
                  )
                  .toList(),
            );
          },
        ),
      ],
    );
  }
}
