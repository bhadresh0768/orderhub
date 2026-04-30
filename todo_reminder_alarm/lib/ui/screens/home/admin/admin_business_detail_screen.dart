import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart' show StateProvider;

import 'package:todo_reminder_alarm/models/app_user.dart';
import 'package:todo_reminder_alarm/models/business.dart';
import 'package:todo_reminder_alarm/models/delivery_agent.dart';
import 'package:todo_reminder_alarm/models/enums.dart';
import 'package:todo_reminder_alarm/models/order.dart';
import 'package:todo_reminder_alarm/providers.dart';
import 'package:todo_reminder_alarm/features/orders/presentation/common/order_shared_helpers.dart';
import 'package:todo_reminder_alarm/features/orders/presentation/customer_order_detail_screen.dart';
import 'package:todo_reminder_alarm/utils/contact_actions.dart';
import 'admin_edit_dialogs.dart';

part 'admin_business_detail_filters.dart';
part 'admin_business_detail_profile.dart';
part 'admin_business_detail_tabs.dart';
part 'admin_business_detail_tab_header.dart';

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
final _adminBusinessProfileExpandedProvider = StateProvider.autoDispose
    .family<bool, String>((ref, _) => false);

class _BusinessInfoField {
  const _BusinessInfoField({
    required this.label,
    required this.value,
    this.actionPhone,
  });

  final String label;
  final String value;
  final String? actionPhone;
}

class AdminBusinessDetailScreen extends ConsumerWidget {
  const AdminBusinessDetailScreen({super.key, required this.business});

  final BusinessProfile business;

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
                    return _matchesDateFilter(order, dateFilter, fromDate, toDate);
                  }).toList()
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
                            ref,
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
}
