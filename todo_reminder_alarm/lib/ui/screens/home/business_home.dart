import 'package:cloud_firestore/cloud_firestore.dart' hide Order;
import 'package:country_picker/country_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart' show StateProvider;
import 'package:uuid/uuid.dart';

import '../../../models/app_user.dart';
import '../../../models/business.dart';
import '../../../models/delivery_agent.dart';
import '../../../models/enums.dart';
import '../../../models/order.dart';
import '../../../models/payment.dart';
import '../../../providers.dart';
import '../profile/profile_screen.dart';
import '../profile/public_business_profile_screen.dart';
import '../orders/business_order_detail_screen.dart';
import '../orders/create_order_screen.dart';
import '../orders/order_history_report_screen.dart';
import '../catalog/business_catalog_screen.dart';
import '../catalog/customer_catalog_screen.dart';

final _businessOrdersUiProvider =
    StateProvider.autoDispose.family<_BusinessOrdersUiState, String>(
      (ref, _) => const _BusinessOrdersUiState(),
    );

class _BusinessOrdersUiState {
  const _BusinessOrdersUiState({this.searchQuery = ''});
  final String searchQuery;
  _BusinessOrdersUiState copyWith({String? searchQuery}) {
    return _BusinessOrdersUiState(searchQuery: searchQuery ?? this.searchQuery);
  }
}

final _placeOrdersUiProvider =
    StateProvider.autoDispose.family<_PlaceOrdersUiState, String>(
      (ref, _) => const _PlaceOrdersUiState(),
    );

class _PlaceOrdersUiState {
  const _PlaceOrdersUiState({this.searchQuery = '', this.categoryFilter = 'All'});
  final String searchQuery;
  final String categoryFilter;
  _PlaceOrdersUiState copyWith({String? searchQuery, String? categoryFilter}) {
    return _PlaceOrdersUiState(
      searchQuery: searchQuery ?? this.searchQuery,
      categoryFilter: categoryFilter ?? this.categoryFilter,
    );
  }
}

final _deliveryTeamUiProvider =
    StateProvider.autoDispose.family<_DeliveryTeamUiState, String>(
      (ref, _) => _DeliveryTeamUiState(selectedCountry: Country.parse('IN')),
    );

class _DeliveryTeamUiState {
  const _DeliveryTeamUiState({
    required this.selectedCountry,
    this.editingAgentId,
    this.saving = false,
    this.error,
  });
  final Country selectedCountry;
  final String? editingAgentId;
  final bool saving;
  final String? error;
  _DeliveryTeamUiState copyWith({
    Country? selectedCountry,
    Object? editingAgentId = _businessHomeUnset,
    bool? saving,
    Object? error = _businessHomeUnset,
  }) {
    return _DeliveryTeamUiState(
      selectedCountry: selectedCountry ?? this.selectedCountry,
      editingAgentId: editingAgentId == _businessHomeUnset
          ? this.editingAgentId
          : editingAgentId as String?,
      saving: saving ?? this.saving,
      error: error == _businessHomeUnset ? this.error : error as String?,
    );
  }
}

const _businessHomeUnset = Object();

class BusinessHomeScreen extends ConsumerWidget {
  const BusinessHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider).value;
    if (authState == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final profileAsync = ref.watch(userProfileProvider(authState.uid));
    return profileAsync.when(
      data: (profile) {
        if (profile == null || profile.businessId == null) {
          return const Scaffold(
            body: Center(child: Text('No business linked')),
          );
        }
        return _BusinessHomeBody(profile: profile);
      },
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (err, _) => Scaffold(body: Center(child: Text('Error: $err'))),
    );
  }
}

class _BusinessHomeBody extends ConsumerWidget {
  const _BusinessHomeBody({required this.profile});

  final AppUser profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final incomingAsync = ref.watch(
      ordersForBusinessProvider(profile.businessId!),
    );
    final outgoingAsync = ref.watch(
      ordersPlacedByBusinessOwnerProvider(profile.id),
    );
    final businessesAsync = ref.watch(businessesProvider);
    BusinessProfile? ownBusiness;
    final availableBusinesses = businessesAsync.value;
    if (availableBusinesses != null) {
      for (final business in availableBusinesses) {
        if (business.id == profile.businessId) {
          ownBusiness = business;
          break;
        }
      }
    }

    return DefaultTabController(
      length: 6,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Dashboard'),
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: 'New Orders'),
              Tab(text: 'Processing'),
              Tab(text: 'Completed'),
              Tab(text: 'Place Orders'),
              Tab(text: 'Delivery Team'),
              Tab(text: 'Catalog'),
            ],
          ),
          actions: [
            IconButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ProfileScreen(user: profile),
                  ),
                );
              },
              icon: const Icon(Icons.person_outline),
              tooltip: 'Profile',
            ),
            OutlinedButton(
              onPressed: () {
                final orders = [
                  ...?incomingAsync.value,
                  ...?outgoingAsync.value,
                ];
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => OrderHistoryReportScreen(
                      title: 'Business History & Reports',
                      orders: orders,
                    ),
                  ),
                );
              },
              child: const Text('Reports'),
            ),
            const SizedBox(width: 8),
            IconButton(
              onPressed: () => ref.read(authServiceProvider).signOut(),
              icon: const Icon(Icons.logout),
              tooltip: 'Logout',
            ),
          ],
        ),
        body: TabBarView(
          children: [
            _BusinessOrdersTab(
              profile: profile,
              emptyMessage: 'No new incoming orders.',
              allowedStatuses: [OrderStatus.pending],
              allowActions: true,
            ),
            _BusinessOrdersTab(
              profile: profile,
              emptyMessage: 'No processing orders.',
              allowedStatuses: [OrderStatus.inProgress],
              allowActions: true,
            ),
            _BusinessOrdersTab(
              profile: profile,
              emptyMessage: 'No completed orders.',
              allowedStatuses: [OrderStatus.completed],
              allowActions: false,
            ),
            _PlaceOrdersTab(profile: profile, ownBusiness: ownBusiness),
            _DeliveryTeamTab(profile: profile),
            BusinessCatalogScreen(businessId: profile.businessId!),
          ],
        ),
      ),
    );
  }
}

class _BusinessOrdersTab extends ConsumerStatefulWidget {
  const _BusinessOrdersTab({
    required this.profile,
    required this.allowedStatuses,
    required this.emptyMessage,
    required this.allowActions,
  });

  final AppUser profile;
  final List<OrderStatus> allowedStatuses;
  final String emptyMessage;
  final bool allowActions;

  @override
  ConsumerState<_BusinessOrdersTab> createState() => _BusinessOrdersTabState();
}

class _BusinessOrdersTabState extends ConsumerState<_BusinessOrdersTab> {
  final TextEditingController _searchController = TextEditingController();
  late final String _uiKey;

  @override
  void initState() {
    super.initState();
    _uiKey =
        '${widget.profile.businessId}-${widget.allowedStatuses.map((e) => e.name).join(",")}';
    _searchController.text = ref.read(_businessOrdersUiProvider(_uiKey)).searchQuery;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _formatQuantity(double value) {
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
    final pack = item.packSize?.trim();
    if (pack != null && pack.isNotEmpty) {
      final qty = _formatQuantity(item.quantity);
      final suffix = item.quantity == 1 ? 'pack' : 'packs';
      return '${item.title} $qty $suffix ($pack)';
    }
    return '${item.title} ${_formatQuantity(item.quantity)} ${_shortUnit(item.unit)}';
  }

  String _capitalize(String value) {
    if (value.isEmpty) return value;
    return value[0].toUpperCase() + value.substring(1);
  }

  @override
  Widget build(BuildContext context) {
    final ui = ref.watch(_businessOrdersUiProvider(_uiKey));
    final ordersAsync = ref.watch(
      ordersForBusinessProvider(widget.profile.businessId!),
    );
    return ordersAsync.when(
      data: (orders) {
        final query = ui.searchQuery.trim().toLowerCase();
        final tabOrders = orders.where((order) {
          final effectiveStatus = _effectiveOrderStatus(order);
          if (!widget.allowedStatuses.contains(effectiveStatus)) return false;
          if (query.isEmpty) return true;
          final itemText = order.items
              .map(
                (item) => '${item.title} ${item.packSize ?? ''}'.toLowerCase(),
              )
              .join(' ');
          return order.customerName.toLowerCase().contains(query) ||
              (order.requesterBusinessName ?? '').toLowerCase().contains(
                query,
              ) ||
              order.displayOrderNumber.toLowerCase().contains(query) ||
              order.id.toLowerCase().contains(query) ||
              itemText.contains(query);
        }).toList();
        if (tabOrders.isEmpty) {
          return Center(child: Text(widget.emptyMessage));
        }
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                return TextField(
                  controller: _searchController,
                  decoration: const InputDecoration(
                    labelText: 'Search order/customer/item',
                    prefixIcon: Icon(Icons.search),
                  ),
                  onChanged: (value) {
                    ref
                        .read(_businessOrdersUiProvider(_uiKey).notifier)
                        .state = ui.copyWith(searchQuery: value);
                  },
                );
              },
            ),
            const SizedBox(height: 12),
            ...tabOrders.map((order) => _buildOrderCard(context, order)),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(child: Text('Error: $err')),
    );
  }

  OrderStatus _effectiveOrderStatus(Order order) {
    if (order.delivery.status == DeliveryStatus.delivered) {
      return OrderStatus.completed;
    }
    if (order.status == OrderStatus.approved) {
      return OrderStatus.inProgress;
    }
    return order.status;
  }

  String _statusLabel(OrderStatus status) {
    return switch (status) {
      OrderStatus.pending => 'New',
      OrderStatus.inProgress || OrderStatus.approved => 'Processing',
      OrderStatus.completed => 'Completed',
      OrderStatus.cancelled => 'Cancelled',
    };
  }

  String _paymentStatusLabel(PaymentStatus status) {
    return status == PaymentStatus.done ? 'Done' : 'Remaining';
  }

  String _paymentAmountLabel(double? value) {
    if (value == null) return 'Not set';
    return value == value.truncateToDouble()
        ? value.toInt().toString()
        : value.toStringAsFixed(2);
  }

  Color _statusColor(OrderStatus status) {
    return switch (status) {
      OrderStatus.completed => Colors.green,
      OrderStatus.pending => Colors.red,
      _ => Colors.yellow.shade800,
    };
  }

  String? _paymentCollectorLabel(Order order) {
    final collectedBy = order.payment.collectedBy;
    if (collectedBy == null || order.payment.status != PaymentStatus.done) {
      return null;
    }
    final who = collectedBy == PaymentCollectedBy.deliveryBoy
        ? 'Delivery Boy'
        : 'Business';
    final whoName = (order.payment.collectedByName ?? '').trim();
    if (whoName.isEmpty) return who;
    return '$who ($whoName)';
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

  Widget _buildOrderCard(BuildContext context, Order order) {
    final effectiveStatus = _effectiveOrderStatus(order);
    final isBusinessOrder =
        order.requesterType == OrderRequesterType.businessOwner;
    final sourceLabel = isBusinessOrder ? 'Business Order' : 'Customer Order';
    final requestedBy = isBusinessOrder
        ? (order.requesterBusinessName ?? order.customerName)
        : order.customerName;
    final includedItems = order.items.where((item) => item.isIncluded ?? true).toList();
    final unavailableItems = order.items.where((item) => !(item.isIncluded ?? true)).toList();
    final previewItems = includedItems.take(3).map(_itemSummary).join(', ');
    final itemsSummary = includedItems.length > 3
        ? '$previewItems +${includedItems.length - 3} more'
        : (previewItems.isEmpty ? '-' : previewItems);
    final unavailableSummary = unavailableItems.isEmpty
        ? ''
        : ' | Unavailable: ${unavailableItems.map((e) => e.title).join(', ')}';
    final paymentCollector = _paymentCollectorLabel(order);
    final statusColor = _statusColor(effectiveStatus);
    final paymentColor = order.payment.status == PaymentStatus.done
        ? Colors.green
        : Colors.red;
    final imageAttachments = _imageAttachments(order);
    final lineStyle = Theme.of(
      context,
    ).textTheme.bodyLarge?.copyWith(fontSize: 16);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => BusinessOrderDetailScreen(order: order),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      'Order ${order.displayOrderNumber} • $sourceLabel',
                      style: Theme.of(
                        context,
                      ).textTheme.titleMedium?.copyWith(fontSize: 18),
                    ),
                  ),
                  const SizedBox(width: 8),
                  widget.allowActions
                      ? PopupMenuButton<String>(
                          onSelected: (value) =>
                              _handleOrderAction(context, order, value),
                          itemBuilder: (context) => [
                            const PopupMenuItem(
                              value: 'approve',
                              child: Text('Approve Order'),
                            ),
                            const PopupMenuItem(
                              value: 'mark_delivered',
                              child: Text('Mark Delivered'),
                            ),
                            if (order.payment.status != PaymentStatus.done)
                              const PopupMenuItem(
                                value: 'payment_done',
                                child: Text('Set Payment Done'),
                              ),
                          ],
                        )
                      : const Icon(Icons.chevron_right),
                ],
              ),
              const SizedBox(height: 4),
              Text('Requested by: $requestedBy', style: lineStyle),
              const SizedBox(height: 4),
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: 'Priority: ${_capitalize(order.priority.name)} | Status: ',
                    ),
                    TextSpan(
                      text: _statusLabel(effectiveStatus),
                      style: TextStyle(
                        color: statusColor,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    TextSpan(
                      text: ' | Delivery: ${_capitalize(order.delivery.status.name)}',
                    ),
                  ],
                ),
                style: lineStyle,
              ),
              const SizedBox(height: 2),
              Text.rich(
                TextSpan(
                  children: [
                    const TextSpan(text: 'Payment: '),
                    TextSpan(
                      text: _paymentStatusLabel(order.payment.status),
                      style: TextStyle(
                        color: paymentColor,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const TextSpan(text: ' | Amount: '),
                    TextSpan(
                      text: _paymentAmountLabel(order.payment.amount),
                      style: TextStyle(
                        color: paymentColor,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                style: lineStyle,
              ),
              if (paymentCollector != null)
                Text('Collected by: $paymentCollector', style: lineStyle),
              const SizedBox(height: 2),
              Text('Items: $itemsSummary$unavailableSummary', style: lineStyle),
              if (imageAttachments.isNotEmpty)
                Text('Item Images: ${imageAttachments.length}', style: lineStyle),
            ],
          ),
        ),
      ),
    );
  }

  String _paymentMethodLabel(PaymentMethod method) {
    return switch (method) {
      PaymentMethod.cash => 'Cash',
      PaymentMethod.check => 'Check',
      PaymentMethod.onlineTransfer => 'Online Transfer',
    };
  }

  Future<(PaymentStatus, PaymentMethod)?> _askPaymentOnDelivery(
    BuildContext context,
    Order order,
  ) async {
    var selectedStatus = order.payment.status;
    var selectedMethod = order.payment.method;
    return showDialog<(PaymentStatus, PaymentMethod)>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocalState) => AlertDialog(
          title: const Text('Mark Delivered'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Payment confirmation'),
              const SizedBox(height: 8),
              DropdownButtonFormField<PaymentStatus>(
                initialValue: selectedStatus,
                items: const [
                  DropdownMenuItem(
                    value: PaymentStatus.done,
                    child: Text('Done'),
                  ),
                  DropdownMenuItem(
                    value: PaymentStatus.pending,
                    child: Text('Remaining'),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setLocalState(() => selectedStatus = value);
                  }
                },
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<PaymentMethod>(
                initialValue: selectedMethod,
                items: PaymentMethod.values
                    .map(
                      (method) => DropdownMenuItem(
                        value: method,
                        child: Text(_paymentMethodLabel(method)),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) {
                    setLocalState(() => selectedMethod = value);
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.of(context).pop((selectedStatus, selectedMethod)),
              child: const Text('Confirm'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleOrderAction(
    BuildContext context,
    Order order,
    String value,
  ) async {
    final firestore = ref.read(firestoreServiceProvider);
    if (value == 'approve') {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => BusinessOrderDetailScreen(order: order),
        ),
      );
    } else if (value == 'mark_delivered') {
      final paymentChoice = await _askPaymentOnDelivery(context, order);
      if (paymentChoice == null) return;
      await firestore.updateOrder(order.id, {
        'status': enumToString(OrderStatus.completed),
        'delivery': {
          ...order.delivery.toMap(),
          'status': enumToString(DeliveryStatus.delivered),
          'updatedAt': Timestamp.fromDate(DateTime.now()),
          'deliveredAt': Timestamp.fromDate(DateTime.now()),
        },
        'payment': {
          ...order.payment.toMap(),
          'status': enumToString(paymentChoice.$1),
          'method': enumToString(paymentChoice.$2),
          'collectedBy': paymentChoice.$1 == PaymentStatus.done
              ? enumToString(PaymentCollectedBy.businessOwner)
              : null,
          'collectedByName': paymentChoice.$1 == PaymentStatus.done
              ? widget.profile.name
              : null,
          'collectedAt': paymentChoice.$1 == PaymentStatus.done
              ? Timestamp.fromDate(DateTime.now())
              : null,
          'collectionNote': paymentChoice.$1 == PaymentStatus.done
              ? order.payment.collectionNote
              : null,
          'updatedAt': Timestamp.fromDate(DateTime.now()),
        },
      });
    } else if (value == 'payment_done') {
      final payment = PaymentInfo(
        status: PaymentStatus.done,
        method: order.payment.method,
        amount: order.payment.amount,
        remark: order.payment.remark,
        confirmedByCustomer: order.payment.confirmedByCustomer ?? false,
        collectedBy: PaymentCollectedBy.businessOwner,
        collectedByName: widget.profile.name,
        collectedAt: DateTime.now(),
        collectionNote: order.payment.collectionNote,
        updatedAt: DateTime.now(),
      );
      await firestore.updateOrder(order.id, {'payment': payment.toMap()});
    }
  }
}

class _PlaceOrdersTab extends ConsumerWidget {
  const _PlaceOrdersTab({required this.profile, required this.ownBusiness});

  final AppUser profile;
  final BusinessProfile? ownBusiness;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _PlaceOrdersBody(profile: profile, ownBusiness: ownBusiness);
  }
}

class _PlaceOrdersBody extends ConsumerStatefulWidget {
  const _PlaceOrdersBody({required this.profile, required this.ownBusiness});

  final AppUser profile;
  final BusinessProfile? ownBusiness;

  @override
  ConsumerState<_PlaceOrdersBody> createState() => _PlaceOrdersBodyState();
}

class _PlaceOrdersBodyState extends ConsumerState<_PlaceOrdersBody> {
  final TextEditingController _searchController = TextEditingController();
  late final String _uiKey;

  @override
  void initState() {
    super.initState();
    _uiKey = widget.profile.id;
    _searchController.text = ref.read(_placeOrdersUiProvider(_uiKey)).searchQuery;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<BusinessProfile> _filterBusinesses(List<BusinessProfile> businesses) {
    final ui = ref.read(_placeOrdersUiProvider(_uiKey));
    final query = ui.searchQuery.trim().toLowerCase();
    return businesses.where((business) {
      final categoryOk =
          ui.categoryFilter == 'All' || business.category == ui.categoryFilter;
      final matchesQuery =
          query.isEmpty ||
          business.name.toLowerCase().contains(query) ||
          business.category.toLowerCase().contains(query) ||
          (business.address ?? '').toLowerCase().contains(query) ||
          business.city.toLowerCase().contains(query);
      return categoryOk && matchesQuery;
    }).toList();
  }

  String _capitalize(String value) {
    if (value.isEmpty) return value;
    return value[0].toUpperCase() + value.substring(1);
  }

  @override
  Widget build(BuildContext context) {
    final ui = ref.watch(_placeOrdersUiProvider(_uiKey));
    final businessesAsync = ref.watch(businessesProvider);
    final outgoingAsync = ref.watch(
      ordersPlacedByBusinessOwnerProvider(widget.profile.id),
    );

    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          const SizedBox(height: 8),
          const TabBar(
            tabs: [
              Tab(text: 'Businesses'),
              Tab(text: 'Orders Placed'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                businessesAsync.when(
                  data: (businesses) {
                    final options = businesses
                        .where(
                          (business) =>
                              business.id != widget.profile.businessId &&
                              business.status != BusinessStatus.suspended,
                        )
                        .toList();
                    final categories = <String>{
                      'All',
                      ...options.map((e) => e.category),
                    };
                    final filtered = _filterBusinesses(options);
                    if (options.isEmpty) {
                      return const Center(
                        child: Text('No other businesses available.'),
                      );
                    }
                    return ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        Text(
                          'Order from Other Businesses',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 12),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final isNarrow = constraints.maxWidth < 700;
                            if (isNarrow) {
                              return Column(
                                children: [
                                  TextField(
                                    controller: _searchController,
                                    decoration: const InputDecoration(
                                      labelText:
                                          'Search business/category/address/city',
                                      prefixIcon: Icon(Icons.search),
                                    ),
                                    onChanged: (value) {
                                      ref
                                              .read(
                                                _placeOrdersUiProvider(_uiKey)
                                                    .notifier,
                                              )
                                              .state =
                                          ui.copyWith(searchQuery: value);
                                    },
                                  ),
                                  const SizedBox(height: 10),
                                  DropdownButtonFormField<String>(
                                    isExpanded: true,
                                    initialValue: ui.categoryFilter,
                                    decoration: const InputDecoration(
                                      labelText: 'Category',
                                    ),
                                    items: categories
                                        .map(
                                          (value) => DropdownMenuItem(
                                            value: value,
                                            child: Text(value),
                                          ),
                                        )
                                        .toList(),
                                    onChanged: (value) {
                                      ref
                                              .read(
                                                _placeOrdersUiProvider(_uiKey)
                                                    .notifier,
                                              )
                                              .state =
                                          ui.copyWith(
                                            categoryFilter: value ?? 'All',
                                          );
                                    },
                                  ),
                                ],
                              );
                            }
                            return Row(
                              children: [
                                Expanded(
                                  flex: 3,
                                  child: TextField(
                                    controller: _searchController,
                                    decoration: const InputDecoration(
                                      labelText:
                                          'Search business/category/address/city',
                                      prefixIcon: Icon(Icons.search),
                                    ),
                                    onChanged: (value) {
                                      ref
                                              .read(
                                                _placeOrdersUiProvider(_uiKey)
                                                    .notifier,
                                              )
                                              .state =
                                          ui.copyWith(searchQuery: value);
                                    },
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: DropdownButtonFormField<String>(
                                    isExpanded: true,
                                    initialValue: ui.categoryFilter,
                                    decoration: const InputDecoration(
                                      labelText: 'Category',
                                    ),
                                    items: categories
                                        .map(
                                          (value) => DropdownMenuItem(
                                            value: value,
                                            child: Text(value),
                                          ),
                                        )
                                        .toList(),
                                    onChanged: (value) {
                                      ref
                                              .read(
                                                _placeOrdersUiProvider(_uiKey)
                                                    .notifier,
                                              )
                                              .state =
                                          ui.copyWith(
                                            categoryFilter: value ?? 'All',
                                          );
                                    },
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 12),
                        if (filtered.isEmpty)
                          const Align(
                            alignment: Alignment.centerLeft,
                            child: Text('No businesses match current filters.'),
                          ),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final isWide = constraints.maxWidth >= 900;
                            final crossAxisCount = isWide ? 2 : 1;
                            return GridView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: filtered.length,
                              gridDelegate:
                                  SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: crossAxisCount,
                                    crossAxisSpacing: 12,
                                    mainAxisSpacing: 12,
                                    mainAxisExtent: 190,
                                  ),
                              itemBuilder: (context, index) {
                                final business = filtered[index];
                                return Card(
                                  child: Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          business.name,
                                          style: Theme.of(
                                            context,
                                          ).textTheme.titleLarge,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 4),
                                        Wrap(
                                          spacing: 8,
                                          children: [
                                            Chip(
                                              label: Text(business.category),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          '${(business.address ?? '').trim().isEmpty ? '-' : business.address!.trim()}, ${business.city}',
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const Spacer(),
                                        Row(
                                          children: [
                                            Expanded(
                                              child: FilledButton(
                                                onPressed:
                                                    widget.ownBusiness == null
                                                    ? null
                                                    : () {
                                                        Navigator.of(
                                                          context,
                                                        ).push(
                                                          MaterialPageRoute(
                                                            builder: (_) =>
                                                                CreateOrderScreen(
                                                                  business:
                                                                      business,
                                                                  customer: widget
                                                                      .profile,
                                                                  requesterBusiness:
                                                                      widget
                                                                          .ownBusiness,
                                                                ),
                                                          ),
                                                        );
                                                      },
                                                child: const Text(
                                                  'Place Order',
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: OutlinedButton(
                                                onPressed: () {
                                                  Navigator.of(context).push(
                                                    MaterialPageRoute(
                                                      builder: (_) =>
                                                          CustomerCatalogScreen(
                                                            business: business,
                                                            customer:
                                                                widget.profile,
                                                            requesterBusiness:
                                                                widget
                                                                    .ownBusiness,
                                                          ),
                                                    ),
                                                  );
                                                },
                                                child: const Text('Catalog'),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            SizedBox(
                                              width: 52,
                                              child: IconButton(
                                                onPressed: () {
                                                  Navigator.of(context).push(
                                                    MaterialPageRoute(
                                                      builder: (_) =>
                                                          PublicBusinessProfileScreen(
                                                            business: business,
                                                          ),
                                                    ),
                                                  );
                                                },
                                                iconSize: 30,
                                                icon: const Icon(
                                                  Icons.storefront_outlined,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            );
                          },
                        ),
                      ],
                    );
                  },
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (err, _) =>
                      Center(child: Text('Error loading businesses: $err')),
                ),
                outgoingAsync.when(
                  data: (orders) {
                    if (orders.isEmpty) {
                      return const Center(
                        child: Text('No outgoing orders yet.'),
                      );
                    }
                    return ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        Text(
                          'Orders I Placed',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 12),
                        ...orders.map((order) {
                          final effectiveStatus =
                              order.delivery.status == DeliveryStatus.delivered
                              ? OrderStatus.completed
                              : order.status;
                          final statusColor = switch (effectiveStatus) {
                            OrderStatus.completed => Colors.green,
                            OrderStatus.approved ||
                            OrderStatus.inProgress => Colors.yellow.shade700,
                            _ => Colors.red,
                          };
                          final paymentPending =
                              order.payment.status == PaymentStatus.pending;
                          return Card(
                            margin: const EdgeInsets.only(bottom: 10),
                            child: ListTile(
                              title: Text(
                                '${order.businessName} • ${effectiveStatus.name}',
                              ),
                              subtitle: Text(
                                'Order ${order.displayOrderNumber}\n'
                                'Priority: ${_capitalize(order.priority.name)} | Payment: ${order.payment.status.name} | '
                                'Delivery: ${_capitalize(order.delivery.status.name)}',
                              ),
                              isThreeLine: true,
                              trailing: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (paymentPending)
                                    const Icon(
                                      Icons.warning_amber_rounded,
                                      color: Colors.deepOrange,
                                      size: 16,
                                    ),
                                  if (paymentPending) const SizedBox(height: 6),
                                  Container(
                                    width: 14,
                                    height: 14,
                                    decoration: BoxDecoration(
                                      color: statusColor,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }),
                      ],
                    );
                  },
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (err, _) => Center(
                    child: Text('Error loading outgoing orders: $err'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DeliveryTeamTab extends ConsumerStatefulWidget {
  const _DeliveryTeamTab({required this.profile});

  final AppUser profile;

  @override
  ConsumerState<_DeliveryTeamTab> createState() => _DeliveryTeamTabState();
}

class _DeliveryTeamTabState extends ConsumerState<_DeliveryTeamTab> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  late final String _uiKey;

  _DeliveryTeamUiState get _ui => ref.read(_deliveryTeamUiProvider(_uiKey));
  void _updateUi(
    _DeliveryTeamUiState Function(_DeliveryTeamUiState state) update,
  ) {
    final notifier = ref.read(_deliveryTeamUiProvider(_uiKey).notifier);
    notifier.state = update(notifier.state);
  }

  @override
  void initState() {
    super.initState();
    _uiKey = widget.profile.businessId!;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _submitAgent() async {
    if (_ui.saving) return;
    final name = _nameController.text.trim();
    final phone = _normalizePhoneNumber(_phoneController.text);
    if (name.isEmpty || phone.isEmpty) {
      _updateUi((state) => state.copyWith(error: 'Enter delivery boy name and phone'));
      return;
    }
    _updateUi((state) => state.copyWith(saving: true, error: null));
    try {
      if (_ui.editingAgentId == null) {
        final agent = DeliveryAgent(
          id: const Uuid().v4(),
          businessId: widget.profile.businessId!,
          name: name,
          phone: phone,
          isActive: true,
        );
        await ref.read(firestoreServiceProvider).createDeliveryAgent(agent);
      } else {
        await ref.read(firestoreServiceProvider).updateDeliveryAgent(
          _ui.editingAgentId!,
          {'name': name, 'phone': phone, 'isActive': true},
        );
      }
      _nameController.clear();
      _phoneController.clear();
      _updateUi((state) => state.copyWith(editingAgentId: null, error: null));
    } catch (err) {
      _updateUi(
        (state) => state.copyWith(error: 'Failed to save delivery boy: $err'),
      );
    } finally {
      if (mounted) {
        _updateUi((state) => state.copyWith(saving: false));
      }
    }
  }

  String _normalizePhoneNumber(String value) {
    final raw = value.trim().replaceAll(RegExp(r'[\s-]'), '');
    if (raw.isEmpty) return '';
    if (raw.startsWith('+')) return raw;
    if (RegExp(r'^\d+$').hasMatch(raw)) {
      return '+${_ui.selectedCountry.phoneCode}$raw';
    }
    return value.trim();
  }

  void _editAgent(DeliveryAgent agent) {
    _nameController.text = agent.name;
    _phoneController.text = agent.phone;
    _updateUi((state) => state.copyWith(editingAgentId: agent.id, error: null));
  }

  Future<void> _setAgentActive(DeliveryAgent agent, bool isActive) async {
    await ref.read(firestoreServiceProvider).updateDeliveryAgent(agent.id, {
      'isActive': isActive,
    });
  }

  @override
  Widget build(BuildContext context) {
    final ui = ref.watch(_deliveryTeamUiProvider(_uiKey));
    final agentsAsync = ref.watch(
      deliveryAgentsForBusinessProvider(widget.profile.businessId!),
    );
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Delivery Team', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Delivery Boy Name',
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    SizedBox(
                      width: 132,
                      child: InkWell(
                        onTap: () {
                          showCountryPicker(
                            context: context,
                            showPhoneCode: true,
                            onSelect: (country) {
                              _updateUi(
                                (state) => state.copyWith(
                                  selectedCountry: country,
                                ),
                              );
                            },
                          );
                        },
                        child: InputDecorator(
                          decoration: const InputDecoration(labelText: 'Code'),
                          child: Text(
                            '${ui.selectedCountry.flagEmoji} +${ui.selectedCountry.phoneCode}',
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextFormField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(
                          labelText: 'Phone Number',
                          hintText: '9876543210',
                        ),
                      ),
                    ),
                  ],
                ),
                if (ui.error != null) ...[
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      ui.error!,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton(
                        onPressed: ui.saving ? null : _submitAgent,
                        child: Text(
                          ui.editingAgentId == null
                              ? 'Add Delivery Boy'
                              : 'Update Delivery Boy',
                        ),
                      ),
                    ),
                    if (ui.editingAgentId != null) ...[
                      const SizedBox(width: 8),
                      OutlinedButton(
                        onPressed: ui.saving
                            ? null
                            : () {
                                _nameController.clear();
                                _phoneController.clear();
                                _updateUi(
                                  (state) => state.copyWith(
                                    editingAgentId: null,
                                    error: null,
                                  ),
                                );
                              },
                        child: const Text('Cancel'),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        agentsAsync.when(
          data: (agents) {
            if (agents.isEmpty) {
              return const Text('No delivery boys yet.');
            }
            return Column(
              children: agents.map((agent) {
                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    title: Text(agent.name),
                    subtitle: Text(
                      '${agent.phone} • ${agent.isActive ? 'Active' : 'Inactive'}',
                    ),
                    trailing: Wrap(
                      spacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        IconButton(
                          onPressed: () => _editAgent(agent),
                          icon: const Icon(Icons.edit_outlined),
                        ),
                        Switch(
                          value: agent.isActive,
                          onChanged: (value) => _setAgentActive(agent, value),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, _) => Text('Error loading delivery team: $err'),
        ),
      ],
    );
  }
}
