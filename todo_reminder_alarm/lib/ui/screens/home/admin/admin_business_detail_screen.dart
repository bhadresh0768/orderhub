import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart' show StateProvider;

import 'package:todo_reminder_alarm/models/app_user.dart';
import 'package:todo_reminder_alarm/models/business.dart';
import 'package:todo_reminder_alarm/models/delivery_agent.dart';
import 'package:todo_reminder_alarm/models/enums.dart';
import 'package:todo_reminder_alarm/models/order.dart';
import 'package:todo_reminder_alarm/providers.dart';
import 'package:todo_reminder_alarm/ui/screens/orders/common/order_shared_helpers.dart';
import 'package:todo_reminder_alarm/ui/screens/orders/customer_order_detail_screen.dart';
import 'admin_edit_dialogs.dart';

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
    final businessAsync = ref.watch(businessByIdProvider(business.id));
    final currentBusiness = businessAsync.value ?? business;
    final ownerAsync = ref.watch(userProfileProvider(currentBusiness.ownerId));
    final statusFilter = ref.watch(
      _adminBusinessStatusFilterProvider(currentBusiness.id),
    );
    final dateFilter = ref.watch(
      _adminBusinessDateFilterProvider(currentBusiness.id),
    );
    final fromDate = ref.watch(
      _adminBusinessFromDateProvider(currentBusiness.id),
    );
    final toDate = ref.watch(_adminBusinessToDateProvider(currentBusiness.id));
    final ordersAsync = ref.watch(allOrdersProvider);
    final agentsAsync = ref.watch(
      deliveryAgentsForBusinessProvider(currentBusiness.id),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text('${currentBusiness.name} Details'),
        actions: [
          IconButton(
            onPressed: () => showAdminBusinessDialog(
              context,
              ref,
              business: currentBusiness,
            ),
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Edit',
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: DefaultTabController(
          length: 2,
          child: ordersAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, _) => Center(child: Text('Error: $err')),
            data: (orders) {
              final businessOrders = orders
                  .where((order) => order.businessId == currentBusiness.id)
                  .toList();
              final filteredOrders =
                  businessOrders.where((order) {
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

              return NestedScrollView(
                headerSliverBuilder: (context, innerBoxIsScrolled) => [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: _buildBusinessProfileCard(
                            context,
                            currentBusiness,
                            ownerAsync,
                            businessOrders.length,
                            filteredOrders.length,
                            pendingCount,
                            processingCount,
                            completedCount,
                          ),
                        ),
                      ),
                    ),
                  ),
                  SliverPersistentHeader(
                    pinned: true,
                    delegate: _AdminTabBarHeaderDelegate(
                      child: Container(
                        color: Theme.of(context).scaffoldBackgroundColor,
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                        child: const TabBar(
                          tabs: [
                            Tab(text: 'Orders'),
                            Tab(text: 'Delivery Agents'),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
                body: TabBarView(
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
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildBusinessProfileCard(
    BuildContext context,
    BusinessProfile business,
    AsyncValue<AppUser?> ownerAsync,
    int totalOrders,
    int filteredOrders,
    int pendingCount,
    int processingCount,
    int completedCount,
  ) {
    final owner = ownerAsync.asData?.value;
    final ownerName = (owner?.name.trim().isNotEmpty ?? false)
        ? owner!.name.trim()
        : '-';
    final ownerPhone = (owner?.phoneNumber?.trim().isNotEmpty ?? false)
        ? owner!.phoneNumber!.trim()
        : '-';
    final ownerEmail = (owner?.email.trim().isNotEmpty ?? false)
        ? owner!.email.trim()
        : '-';
    final businessPhone = (business.phone ?? '').trim().isEmpty
        ? '-'
        : business.phone!.trim();
    final businessUnique = (business.gstNumber ?? '').trim().isEmpty
        ? '-'
        : business.gstNumber!.trim();
    final fields = <MapEntry<String, String>>[
      MapEntry('Owner Name', ownerName),
      MapEntry('Owner Mobile', ownerPhone),
      MapEntry('Owner Email', ownerEmail),
      MapEntry(
        'Owner Registration Date',
        owner?.createdAt == null ? '-' : _formatDateTime(owner!.createdAt!),
      ),
      MapEntry('Business Name', business.name),
      MapEntry('Category', business.category),
      MapEntry('City', business.city.isEmpty ? '-' : business.city),
      MapEntry(
        'Address',
        (business.address ?? '').trim().isEmpty ? '-' : business.address!.trim(),
      ),
      MapEntry('Business Mobile', businessPhone),
      MapEntry('Business Unique No', businessUnique),
      MapEntry('Status', _capitalize(business.status.name)),
      MapEntry(
        'Business Registration Date',
        business.createdAt == null ? '-' : _formatDateTime(business.createdAt!),
      ),
      MapEntry('Total Orders', '$totalOrders'),
      MapEntry('Filtered Orders', '$filteredOrders'),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildBusinessLogoFor(business),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    business.name,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${business.category} • ${business.city}',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Pending: $pendingCount • Processing: $processingCount • Completed: $completedCount',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _buildInfoGrid(context, fields),
      ],
    );
  }

  Widget _buildBusinessLogoFor(BusinessProfile business) {
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

  Widget _buildOrdersTab(
    BuildContext context,
    WidgetRef ref,
    List<Order> filteredOrders,
    _AdminBusinessDateFilter dateFilter,
    DateTime? fromDate,
    DateTime? toDate,
  ) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      children: [
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<OrderStatus?>(
                initialValue: ref.watch(
                  _adminBusinessStatusFilterProvider(business.id),
                ),
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
                          .read(
                            _adminBusinessStatusFilterProvider(
                              business.id,
                            ).notifier,
                          )
                          .state =
                      value;
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
                          .read(
                            _adminBusinessDateFilterProvider(
                              business.id,
                            ).notifier,
                          )
                          .state =
                      value;
                  if (value != _AdminBusinessDateFilter.custom) {
                    ref
                            .read(
                              _adminBusinessFromDateProvider(
                                business.id,
                              ).notifier,
                            )
                            .state =
                        null;
                    ref
                            .read(
                              _adminBusinessToDateProvider(
                                business.id,
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
                          .read(
                            _adminBusinessFromDateProvider(
                              business.id,
                            ).notifier,
                          )
                          .state =
                      null;
                  ref
                          .read(
                            _adminBusinessToDateProvider(business.id).notifier,
                          )
                          .state =
                      null;
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
          final effectiveStatus = OrderSharedHelpers.effectiveStatus(order);
          final statusColor = OrderSharedHelpers.statusColor(effectiveStatus);
          return Card(
            child: ListTile(
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => CustomerOrderDetailScreen(order: order),
                  ),
                );
              },
              title: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(text: 'Order ${order.displayOrderNumber} • '),
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

  Widget _buildAgentsTab(AsyncValue<List<DeliveryAgent>> agentsAsync) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
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
                  .map<Widget>(
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

class _AdminTabBarHeaderDelegate extends SliverPersistentHeaderDelegate {
  const _AdminTabBarHeaderDelegate({required this.child});

  final Widget child;

  @override
  double get minExtent => 56;

  @override
  double get maxExtent => 56;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return child;
  }

  @override
  bool shouldRebuild(covariant _AdminTabBarHeaderDelegate oldDelegate) {
    return oldDelegate.child != child;
  }
}
