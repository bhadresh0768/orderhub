import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/app_user.dart';
import '../../../models/business.dart';
import '../../../models/enums.dart';
import '../../../models/order.dart';
import '../../../providers.dart';
import '../profile/profile_screen.dart';
import '../profile/public_business_profile_screen.dart';
import '../orders/create_order_screen.dart';
import '../orders/customer_order_detail_screen.dart';
import '../orders/order_history_report_screen.dart';

final _customerStoreSearchProvider = StateProvider.autoDispose<String>(
  (ref) => '',
);
final _customerOrderSearchProvider = StateProvider.autoDispose<String>(
  (ref) => '',
);
final _customerCategoryFilterProvider = StateProvider.autoDispose<String>(
  (ref) => 'All',
);
final _customerCityFilterProvider = StateProvider.autoDispose<String>(
  (ref) => 'All',
);
final _customerOrderFilterProvider = StateProvider.autoDispose<String>(
  (ref) => 'All',
);

class CustomerHomeScreen extends ConsumerWidget {
  const CustomerHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider).value;
    if (authState == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final profileAsync = ref.watch(userProfileProvider(authState.uid));
    return profileAsync.when(
      data: (profile) {
        if (profile == null) {
          return const Scaffold(body: Center(child: Text('No profile found')));
        }
        return _CustomerHomeBody(profile: profile);
      },
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (err, _) => Scaffold(body: Center(child: Text('Error: $err'))),
    );
  }
}

class _CustomerHomeBody extends ConsumerStatefulWidget {
  const _CustomerHomeBody({required this.profile});

  final AppUser profile;

  @override
  ConsumerState<_CustomerHomeBody> createState() => _CustomerHomeBodyState();
}

class _CustomerHomeBodyState extends ConsumerState<_CustomerHomeBody> {
  List<BusinessProfile> _applyFilters(
    List<BusinessProfile> businesses, {
    required String queryText,
    required String categoryFilter,
    required String cityFilter,
  }) {
    final query = queryText.trim().toLowerCase();
    return businesses.where((business) {
      final categoryOk =
          categoryFilter == 'All' || business.category == categoryFilter;
      final cityOk = cityFilter == 'All' || business.city == cityFilter;
      final matchesQuery =
          query.isEmpty ||
          business.name.toLowerCase().contains(query) ||
          business.category.toLowerCase().contains(query) ||
          business.city.toLowerCase().contains(query);
      return categoryOk && cityOk && matchesQuery;
    }).toList();
  }

  OrderStatus _effectiveStatus(Order order) {
    if (order.delivery.status == DeliveryStatus.delivered) {
      return OrderStatus.completed;
    }
    return order.status;
  }

  List<Order> _applyOrderFilters(
    List<Order> orders, {
    required String queryText,
    required String orderFilter,
  }) {
    final query = queryText.trim().toLowerCase();
    return orders.where((order) {
      final effectiveStatus = _effectiveStatus(order);
      final paymentPending = order.payment.status == PaymentStatus.pending;
      final matchesFilter = switch (orderFilter) {
        'Pending' => effectiveStatus == OrderStatus.pending,
        'Processing' =>
          effectiveStatus == OrderStatus.approved ||
          effectiveStatus == OrderStatus.inProgress,
        'Completed' => effectiveStatus == OrderStatus.completed,
        'Payment Pending' => paymentPending,
        _ => true,
      };
      if (!matchesFilter) return false;
      if (query.isEmpty) return true;
      return order.businessName.toLowerCase().contains(query) ||
          order.displayOrderNumber.toLowerCase().contains(query) ||
          order.items.any((item) => item.title.toLowerCase().contains(query));
    }).toList();
  }

  Widget? _buildPaymentBadge(Order order) {
    if (order.payment.status == PaymentStatus.pending) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: Colors.red.shade100,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          'Payment Pending',
          style: TextStyle(
            fontSize: 11,
            color: Colors.red.shade800,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }
    if (order.payment.status == PaymentStatus.done &&
        order.payment.collectedBy == PaymentCollectedBy.deliveryBoy) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: Colors.green.shade100,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          'Collected by Delivery',
          style: TextStyle(
            fontSize: 11,
            color: Colors.green.shade800,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }
    return null;
  }

  Color _statusColor(OrderStatus status) {
    return switch (status) {
      OrderStatus.completed => Colors.green,
      OrderStatus.pending => Colors.red,
      _ => Colors.yellow.shade800,
    };
  }

  bool _looksLikeImage(String value) {
    final normalized = value.toLowerCase();
    return normalized.contains('.jpg') ||
        normalized.contains('.jpeg') ||
        normalized.contains('.png') ||
        normalized.contains('.webp') ||
        normalized.contains('.gif');
  }

  List<OrderAttachment> _imageAttachments(Order order) {
    final itemLevel = order.items.expand((item) => item.attachments);
    return [...order.attachments, ...itemLevel]
        .where(
          (attachment) =>
              _looksLikeImage(attachment.name) ||
              _looksLikeImage(attachment.url),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    // Show all stores by default; search/filters are applied client-side.
    final businessesAsync = ref.watch(businessesProvider);
    final ordersAsync = ref.watch(ordersForCustomerProvider(widget.profile.id));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          IconButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ProfileScreen(user: widget.profile),
                ),
              );
            },
            icon: const Icon(Icons.person_outline),
            tooltip: 'Profile',
          ),
          IconButton(
            onPressed: () => ref.read(authServiceProvider).signOut(),
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
          ),
        ],
      ),
      body: DefaultTabController(
        length: 2,
        child: Column(
          children: [
            const TabBar(
              tabs: [
                Tab(text: 'Stores'),
                Tab(text: 'My Orders'),
              ],
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _buildStoresTab(businessesAsync),
                  _buildOrdersTab(ordersAsync),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStoresTab(AsyncValue<List<BusinessProfile>> businessesAsync) {
    final storeSearch = ref.watch(_customerStoreSearchProvider);
    final categoryFilter = ref.watch(_customerCategoryFilterProvider);
    final cityFilter = ref.watch(_customerCityFilterProvider);
    return businessesAsync.when(
      data: (businesses) {
        final categories = <String>{'All', ...businesses.map((e) => e.category)};
        final cities = <String>{'All', ...businesses.map((e) => e.city)};
        final filtered = _applyFilters(
          businesses,
          queryText: storeSearch,
          categoryFilter: categoryFilter,
          cityFilter: cityFilter,
        );
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('Find Businesses', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, constraints) {
                final isNarrow = constraints.maxWidth < 700;
                if (isNarrow) {
                  return Column(
                    children: [
                      TextField(
                        decoration: const InputDecoration(
                          labelText: 'Search by business/category/city',
                          prefixIcon: Icon(Icons.search),
                        ),
                        onChanged: (value) => ref
                            .read(_customerStoreSearchProvider.notifier)
                            .state = value,
                      ),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<String>(
                        isExpanded: true,
                        initialValue: categoryFilter,
                        decoration: const InputDecoration(labelText: 'Category'),
                        items: categories
                            .map((value) => DropdownMenuItem(value: value, child: Text(value)))
                            .toList(),
                        onChanged: (value) => ref
                            .read(_customerCategoryFilterProvider.notifier)
                            .state = value ?? 'All',
                      ),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<String>(
                        isExpanded: true,
                        initialValue: cityFilter,
                        decoration: const InputDecoration(labelText: 'City'),
                        items: cities
                            .map((value) => DropdownMenuItem(value: value, child: Text(value)))
                            .toList(),
                        onChanged: (value) => ref
                            .read(_customerCityFilterProvider.notifier)
                            .state = value ?? 'All',
                      ),
                    ],
                  );
                }
                return Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: TextField(
                        decoration: const InputDecoration(
                          labelText: 'Search by business/category/city',
                          prefixIcon: Icon(Icons.search),
                        ),
                        onChanged: (value) => ref
                            .read(_customerStoreSearchProvider.notifier)
                            .state = value,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        isExpanded: true,
                        initialValue: categoryFilter,
                        decoration: const InputDecoration(labelText: 'Category'),
                        items: categories
                            .map((value) => DropdownMenuItem(value: value, child: Text(value)))
                            .toList(),
                        onChanged: (value) => ref
                            .read(_customerCategoryFilterProvider.notifier)
                            .state = value ?? 'All',
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        isExpanded: true,
                        initialValue: cityFilter,
                        decoration: const InputDecoration(labelText: 'City'),
                        items: cities
                            .map((value) => DropdownMenuItem(value: value, child: Text(value)))
                            .toList(),
                        onChanged: (value) => ref
                            .read(_customerCityFilterProvider.notifier)
                            .state = value ?? 'All',
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 12),
            if (filtered.isEmpty) const Text('No businesses match your filters.'),
            ...filtered.map((business) {
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(business.name, style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 4),
                      Text('${business.category} • ${business.city}'),
                      const SizedBox(height: 6),
                      Text(
                        (business.address ?? '').trim().isEmpty ? '-' : business.address!.trim(),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: FilledButton(
                              onPressed: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => CreateOrderScreen(
                                      business: business,
                                      customer: widget.profile,
                                    ),
                                  ),
                                );
                              },
                              child: const Text('Create Order'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => PublicBusinessProfileScreen(
                                      business: business,
                                    ),
                                  ),
                                );
                              },
                              child: const Text('View Profile'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(child: Text('Error loading businesses: $err')),
    );
  }

  Widget _buildOrdersTab(AsyncValue<List<Order>> ordersAsync) {
    final orderSearch = ref.watch(_customerOrderSearchProvider);
    final orderFilter = ref.watch(_customerOrderFilterProvider);
    return ordersAsync.when(
      data: (orders) {
        final filteredOrders = _applyOrderFilters(
          orders,
          queryText: orderSearch,
          orderFilter: orderFilter,
        );
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('My Orders', style: Theme.of(context).textTheme.headlineSmall),
                OutlinedButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => OrderHistoryReportScreen(
                          title: 'Customer History & Reports',
                          orders: orders,
                        ),
                      ),
                    );
                  },
                  child: const Text('History & Reports'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              decoration: const InputDecoration(
                labelText: 'Search by store/order/item',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (value) =>
                  ref.read(_customerOrderSearchProvider.notifier).state = value,
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              initialValue: orderFilter,
              decoration: const InputDecoration(labelText: 'Order Filter'),
              items: const [
                DropdownMenuItem(value: 'All', child: Text('All')),
                DropdownMenuItem(value: 'Pending', child: Text('Pending')),
                DropdownMenuItem(value: 'Processing', child: Text('Processing')),
                DropdownMenuItem(value: 'Completed', child: Text('Completed')),
                DropdownMenuItem(
                  value: 'Payment Pending',
                  child: Text('Payment Pending'),
                ),
              ],
              onChanged: (value) =>
                  ref.read(_customerOrderFilterProvider.notifier).state =
                      value ?? 'All',
            ),
            const SizedBox(height: 12),
            if (filteredOrders.isEmpty)
              const Text('No orders match current filters.'),
            ...filteredOrders.map((order) {
              final effectiveStatus = _effectiveStatus(order);
              final statusColor = _statusColor(effectiveStatus);
              final showAmountToCustomer = effectiveStatus != OrderStatus.pending;
              final amount = order.payment.amount;
              final amountText = amount == null
                  ? 'Not set'
                  : (amount == amount.truncateToDouble()
                        ? amount.toInt().toString()
                        : amount.toStringAsFixed(2));
              final collectedBy = order.payment.collectedBy;
              final collectedByText =
                  collectedBy == null || order.payment.status != PaymentStatus.done
                  ? null
                  : (collectedBy == PaymentCollectedBy.deliveryBoy
                        ? 'Delivery Boy'
                        : 'Business');
              final badge = _buildPaymentBadge(order);
              final unavailableItems = order.items
                  .where((item) => !(item.isIncluded ?? true))
                  .map((item) => item.title)
                  .toList();
              final imageAttachments = _imageAttachments(order);
              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  dense: true,
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => CustomerOrderDetailScreen(order: order),
                      ),
                    );
                  },
                  title: Row(
                    children: [
                      Expanded(
                        child: Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(text: '${order.businessName} • '),
                              TextSpan(
                                text: effectiveStatus.name,
                                style: TextStyle(
                                  color: statusColor,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (badge != null) ...[
                        const SizedBox(width: 8),
                        badge,
                      ],
                    ],
                  ),
                  subtitle: Text(
                    'Order ${order.displayOrderNumber}'
                    '${showAmountToCustomer ? ' • Amount: $amountText' : ''}\n'
                    'Payment: ${order.payment.status.name}'
                    '${collectedByText == null ? '' : ' ($collectedByText)'}'
                    ' | Delivery: ${order.delivery.status.name}'
                    '${unavailableItems.isEmpty ? '' : '\nUnavailable: ${unavailableItems.join(', ')}'}'
                    '${imageAttachments.isEmpty ? '' : '\nItem Images: ${imageAttachments.length}'}',
                  ),
                  isThreeLine: true,
                ),
              );
            }),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(child: Text('Error loading orders: $err')),
    );
  }
}
