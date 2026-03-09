import 'package:cloud_firestore/cloud_firestore.dart' hide Order;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart' show StateProvider;

import 'package:todo_reminder_alarm/models/app_user.dart';
import 'package:todo_reminder_alarm/models/business.dart';
import 'package:todo_reminder_alarm/models/enums.dart';
import 'package:todo_reminder_alarm/models/order.dart';
import 'package:todo_reminder_alarm/providers.dart';
import 'package:todo_reminder_alarm/ui/screens/profile/profile_screen.dart';
import 'package:todo_reminder_alarm/ui/screens/support/contact_us_screen.dart';
import 'package:todo_reminder_alarm/ui/screens/support/invite_friends_screen.dart';
import 'package:todo_reminder_alarm/ui/screens/support/privacy_policy_screen.dart';

enum _DeliveryDateFilter { today, week, month, year, custom }

final _deliveryBoyUiProvider = StateProvider.autoDispose<_DeliveryBoyUiState>(
  (ref) => const _DeliveryBoyUiState(),
);

class _DeliveryBoyUiState {
  const _DeliveryBoyUiState({
    this.filter = _DeliveryDateFilter.month,
    this.customFrom,
    this.customTo,
  });

  final _DeliveryDateFilter filter;
  final DateTime? customFrom;
  final DateTime? customTo;

  _DeliveryBoyUiState copyWith({
    _DeliveryDateFilter? filter,
    Object? customFrom = _deliveryDateUnset,
    Object? customTo = _deliveryDateUnset,
  }) {
    return _DeliveryBoyUiState(
      filter: filter ?? this.filter,
      customFrom: customFrom == _deliveryDateUnset
          ? this.customFrom
          : customFrom as DateTime?,
      customTo: customTo == _deliveryDateUnset
          ? this.customTo
          : customTo as DateTime?,
    );
  }
}
const _deliveryDateUnset = Object();

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
            ),
            drawer: _buildDrawer(context, ref, profile),
            body: const Center(
              child: Text('Phone number missing in profile. Contact admin.'),
            ),
          );
        }
        return _DeliveryBoyBody(profile: profile, phone: phone, name: profile.name);
      },
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (_, _) => Scaffold(
        body: Center(child: Text('Something went wrong. Please retry.')),
      ),
    );
  }

  Drawer _buildDrawer(BuildContext context, WidgetRef ref, AppUser profile) {
    return Drawer(
      backgroundColor: Colors.white,
      child: SafeArea(
        child: ListView(
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Text('Menu', style: TextStyle(fontSize: 24)),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.person_outline),
              title: const Text('Profile'),
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ProfileScreen(user: profile),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.contact_phone_outlined),
              title: const Text('Contact Us'),
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ContactUsScreen(user: profile),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.group_add_outlined),
              title: const Text('Invite Friends'),
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const InviteFriendsScreen(),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.privacy_tip_outlined),
              title: const Text('Privacy Policy'),
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const PrivacyPolicyScreen(),
                  ),
                );
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Logout'),
              onTap: () {
                Navigator.of(context).pop();
                ref.read(authServiceProvider).signOut();
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _DeliveryBoyBody extends ConsumerStatefulWidget {
  const _DeliveryBoyBody({
    required this.profile,
    required this.phone,
    required this.name,
  });

  final AppUser profile;
  final String phone;
  final String name;

  @override
  ConsumerState<_DeliveryBoyBody> createState() => _DeliveryBoyBodyState();
}

class _DeliveryBoyBodyState extends ConsumerState<_DeliveryBoyBody> {
  String _capitalize(String value) {
    if (value.isEmpty) return value;
    return value[0].toUpperCase() + value.substring(1);
  }

  String _formatDate(DateTime date) {
    final mm = date.month.toString().padLeft(2, '0');
    final dd = date.day.toString().padLeft(2, '0');
    return '${date.year}-$mm-$dd';
  }

  bool _isInDateRange(DateTime date, DateTime from, DateTime to) {
    final start = DateTime(from.year, from.month, from.day);
    final endExclusive = DateTime(to.year, to.month, to.day).add(
      const Duration(days: 1),
    );
    return !date.isBefore(start) && date.isBefore(endExclusive);
  }

  Future<void> _pickCustomRange(_DeliveryBoyUiState uiState) async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year + 2),
      initialDateRange: (uiState.customFrom != null && uiState.customTo != null)
          ? DateTimeRange(start: uiState.customFrom!, end: uiState.customTo!)
          : null,
    );
    if (picked == null || !mounted) return;
    ref.read(_deliveryBoyUiProvider.notifier).state = uiState.copyWith(
      filter: _DeliveryDateFilter.custom,
      customFrom: picked.start,
      customTo: picked.end,
    );
  }

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
      case _DeliveryDateFilter.custom:
        final from = ref.read(_deliveryBoyUiProvider).customFrom;
        final to = ref.read(_deliveryBoyUiProvider).customTo;
        if (from == null || to == null) return false;
        return _isInDateRange(date, from, to);
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
      case _DeliveryDateFilter.custom:
        return 'Custom Range';
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
    final businessesAsync = ref.watch(businessesProvider);
    final businessAddressById = <String, String>{};
    final businessList = businessesAsync.asData?.value ?? const <BusinessProfile>[];
    for (final business in businessList) {
      final address = (business.address ?? '').trim();
      final city = business.city.trim();
      final text = address.isEmpty
          ? (city.isEmpty ? '-' : city)
          : (city.isEmpty ? address : '$address, $city');
      businessAddressById[business.id] = text;
    }
    return Scaffold(
      appBar: AppBar(
        title: Text('Delivery Dashboard • ${widget.name}'),
      ),
      drawer: Drawer(
        backgroundColor: Colors.white,
        child: SafeArea(
          child: ListView(
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Text('Menu', style: TextStyle(fontSize: 24)),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.person_outline),
                title: const Text('Profile'),
                onTap: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ProfileScreen(user: widget.profile),
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.contact_phone_outlined),
                title: const Text('Contact Us'),
                onTap: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ContactUsScreen(user: widget.profile),
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.group_add_outlined),
                title: const Text('Invite Friends'),
                onTap: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const InviteFriendsScreen(),
                    ),
                  );
                },
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.logout),
                title: const Text('Logout'),
                onTap: () {
                  Navigator.of(context).pop();
                  ref.read(authServiceProvider).signOut();
                },
              ),
            ],
          ),
        ),
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
                        businessAddressById: businessAddressById,
                        allowActions: true,
                        emptyText: 'No upcoming deliveries.',
                      ),
                      Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                            child: Row(
                              children: [
                                Expanded(
                                  child:
                                      DropdownButtonFormField<_DeliveryDateFilter>(
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
                                        if (value == _DeliveryDateFilter.custom &&
                                            (uiState.customFrom == null ||
                                                uiState.customTo == null)) {
                                          WidgetsBinding.instance.addPostFrameCallback((_) {
                                            if (!mounted) return;
                                            _pickCustomRange(
                                              ref.read(_deliveryBoyUiProvider),
                                            );
                                          });
                                        }
                                      }
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (uiState.filter == _DeliveryDateFilter.custom)
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      (uiState.customFrom != null &&
                                              uiState.customTo != null)
                                          ? '${_formatDate(uiState.customFrom!)} to ${_formatDate(uiState.customTo!)}'
                                          : 'No date range selected',
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: () => _pickCustomRange(uiState),
                                    child: const Text('Select'),
                                  ),
                                  TextButton(
                                    onPressed: () {
                                      ref.read(_deliveryBoyUiProvider.notifier).state =
                                          uiState.copyWith(
                                            customFrom: null,
                                            customTo: null,
                                          );
                                    },
                                    child: const Text('Clear'),
                                  ),
                                ],
                              ),
                            ),
                          Expanded(
                            child: _buildOrdersList(
                              context,
                              completedOrders,
                              businessAddressById: businessAddressById,
                              allowActions: false,
                              emptyText: 'No completed deliveries in this range.',
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) =>
            const Center(child: Text('Something went wrong. Please retry.')),
      ),
    );
  }

  Widget _buildOrdersList(
    BuildContext context,
    List<Order> orders, {
    required Map<String, String> businessAddressById,
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
        final amount = order.payment.amount;
        final amountText = amount == null
            ? 'Not set'
            : (amount == amount.truncateToDouble()
                  ? amount.toInt().toString()
                  : amount.toStringAsFixed(2));
        final directAddress = (order.deliveryAddress ?? '').trim();
        final deliveryAddress = directAddress.isNotEmpty
            ? directAddress
            : (order.requesterType == OrderRequesterType.businessOwner
                  ? businessAddressById[order.requesterBusinessId] ?? '-'
                  : '-');
        final isFast = order.priority == OrderPriority.fast;
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: isFast
                ? BorderSide(color: Colors.red.shade400, width: 1.8)
                : BorderSide.none,
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${order.businessName} → ${order.customerName}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 6),
                Text(
                  'Order ${order.displayOrderNumber} • ${_capitalize(order.delivery.status.name)}',
                ),
                const SizedBox(height: 4),
                Text(
                  'Payment: ${_capitalize(order.payment.status.name)} • Amount: $amountText',
                ),
                const SizedBox(height: 4),
                Text('Address: $deliveryAddress'),
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
