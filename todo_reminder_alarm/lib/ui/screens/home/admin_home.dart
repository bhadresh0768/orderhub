import 'package:cloud_firestore/cloud_firestore.dart' hide Order;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/app_user.dart';
import '../../../models/business.dart';
import '../../../models/delivery_agent.dart';
import '../../../models/enums.dart';
import '../../../models/order.dart';
import '../../../providers.dart';
import '../orders/order_history_report_screen.dart';

class AdminHomeScreen extends ConsumerWidget {
  const AdminHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Admin Panel'),
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: 'Users'),
              Tab(text: 'Businesses'),
              Tab(text: 'Orders'),
              Tab(text: 'Delivery Team'),
            ],
          ),
          actions: [
            OutlinedButton(
              onPressed: () {
                final orders = ref.read(allOrdersProvider).value ?? [];
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => OrderHistoryReportScreen(
                      title: 'Admin History & Reports',
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
        body: const TabBarView(
          children: [
            _UsersTab(),
            _BusinessesTab(),
            _OrdersTab(),
            _DeliveryAgentsTab(),
          ],
        ),
      ),
    );
  }
}

class _UsersTab extends ConsumerStatefulWidget {
  const _UsersTab();

  @override
  ConsumerState<_UsersTab> createState() => _UsersTabState();
}

class _UsersTabState extends ConsumerState<_UsersTab> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _editUserDialog(AppUser user) async {
    final name = TextEditingController(text: user.name);
    final email = TextEditingController(text: user.email);
    final phone = TextEditingController(text: user.phoneNumber ?? '');
    final address = TextEditingController(text: user.address ?? '');
    final shop = TextEditingController(text: user.shopName ?? '');
    var role = user.role;
    var isActive = user.isActive;

    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: const Text('Edit User'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: name, decoration: const InputDecoration(labelText: 'Name')),
                const SizedBox(height: 8),
                TextField(controller: email, decoration: const InputDecoration(labelText: 'Email')),
                const SizedBox(height: 8),
                TextField(controller: phone, decoration: const InputDecoration(labelText: 'Phone')),
                const SizedBox(height: 8),
                TextField(controller: shop, decoration: const InputDecoration(labelText: 'Shop Name')),
                const SizedBox(height: 8),
                TextField(controller: address, decoration: const InputDecoration(labelText: 'Address')),
                const SizedBox(height: 8),
                DropdownButtonFormField<UserRole>(
                  initialValue: role,
                  items: UserRole.values
                      .map((e) => DropdownMenuItem(value: e, child: Text(e.name)))
                      .toList(),
                  onChanged: (value) => setLocal(() => role = value ?? role),
                  decoration: const InputDecoration(labelText: 'Role'),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Active'),
                  value: isActive,
                  onChanged: (v) => setLocal(() => isActive = v),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            FilledButton(
              onPressed: () async {
                await ref.read(firestoreServiceProvider).updateUser(user.id, {
                  'name': name.text.trim(),
                  'email': email.text.trim(),
                  'phoneNumber': phone.text.trim(),
                  'shopName': shop.text.trim().isEmpty ? null : shop.text.trim(),
                  'address': address.text.trim().isEmpty ? null : address.text.trim(),
                  'role': enumToString(role),
                  'isActive': isActive,
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
    name.dispose();
    email.dispose();
    phone.dispose();
    address.dispose();
    shop.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final usersAsync = ref.watch(allUsersProvider);
    return usersAsync.when(
      data: (users) {
        final query = _searchController.text.trim().toLowerCase();
        final filtered = users.where((u) {
          if (query.isEmpty) return true;
          return u.name.toLowerCase().contains(query) ||
              u.email.toLowerCase().contains(query) ||
              (u.phoneNumber ?? '').toLowerCase().contains(query) ||
              u.role.name.toLowerCase().contains(query);
        }).toList();
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'Note: Admin can edit/delete user profiles. Authentication account creation is still done by signup/login flow.',
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                labelText: 'Search users',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            ...filtered.map((user) {
              return Card(
                child: ListTile(
                  title: Text(user.name.isEmpty ? 'Unknown' : user.name),
                  subtitle: Text(
                    '${user.email.isEmpty ? (user.phoneNumber ?? '-') : user.email}\nRole: ${user.role.name} • ${user.isActive ? 'Active' : 'Inactive'}',
                  ),
                  isThreeLine: true,
                  trailing: PopupMenuButton<String>(
                    onSelected: (value) async {
                      if (value == 'edit') {
                        await _editUserDialog(user);
                      } else if (value == 'delete') {
                        await ref.read(firestoreServiceProvider).deleteUser(user.id);
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
      error: (err, _) => Center(child: Text('Error: $err')),
    );
  }
}

class _BusinessesTab extends ConsumerStatefulWidget {
  const _BusinessesTab();

  @override
  ConsumerState<_BusinessesTab> createState() => _BusinessesTabState();
}

class _BusinessesTabState extends ConsumerState<_BusinessesTab> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _showBusinessDialog({BusinessProfile? business}) async {
    final name = TextEditingController(text: business?.name ?? '');
    final category = TextEditingController(text: business?.category ?? '');
    final city = TextEditingController(text: business?.city ?? '');
    final address = TextEditingController(text: business?.address ?? '');
    final phone = TextEditingController(text: business?.phone ?? '');
    final gst = TextEditingController(text: business?.gstNumber ?? '');
    final owner = TextEditingController(text: business?.ownerId ?? '');
    var status = business?.status ?? BusinessStatus.pending;

    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: Text(business == null ? 'Add Business' : 'Edit Business'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: name, decoration: const InputDecoration(labelText: 'Business Name')),
                const SizedBox(height: 8),
                TextField(controller: category, decoration: const InputDecoration(labelText: 'Category')),
                const SizedBox(height: 8),
                TextField(controller: city, decoration: const InputDecoration(labelText: 'City')),
                const SizedBox(height: 8),
                TextField(controller: address, decoration: const InputDecoration(labelText: 'Address')),
                const SizedBox(height: 8),
                TextField(controller: phone, decoration: const InputDecoration(labelText: 'Phone')),
                const SizedBox(height: 8),
                TextField(controller: gst, decoration: const InputDecoration(labelText: 'Business Unique No')),
                const SizedBox(height: 8),
                TextField(controller: owner, decoration: const InputDecoration(labelText: 'Owner UID')),
                const SizedBox(height: 8),
                DropdownButtonFormField<BusinessStatus>(
                  initialValue: status,
                  items: BusinessStatus.values
                      .map((e) => DropdownMenuItem(value: e, child: Text(e.name)))
                      .toList(),
                  onChanged: (v) => setLocal(() => status = v ?? status),
                  decoration: const InputDecoration(labelText: 'Status'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            FilledButton(
              onPressed: () async {
                final nameText = name.text.trim();
                final categoryText = category.text.trim();
                final cityText = city.text.trim();
                final ownerText = owner.text.trim();
                final addressText = address.text.trim();
                final phoneText = phone.text.trim();
                final gstText = gst.text.trim();
                final data = {
                  'name': nameText,
                  'category': categoryText,
                  'city': cityText,
                  'address': addressText.isEmpty ? null : addressText,
                  'phone': phoneText.isEmpty ? null : phoneText,
                  'gstNumber': gstText.isEmpty ? null : gstText,
                  'ownerId': ownerText,
                  'status': enumToString(status),
                };
                if (business == null) {
                  final id = ref.read(firestoreProvider).collection('businesses').doc().id;
                  await ref.read(firestoreServiceProvider).createBusiness(
                        BusinessProfile(
                          id: id,
                          name: nameText,
                          category: categoryText,
                          ownerId: ownerText,
                          city: cityText,
                          address: addressText.isEmpty ? null : addressText,
                          phone: phoneText.isEmpty ? null : phoneText,
                          gstNumber: gstText.isEmpty ? null : gstText,
                          status: status,
                          createdAt: DateTime.now(),
                        ),
                      );
                } else {
                  await ref.read(firestoreServiceProvider).updateBusiness(business.id, data);
                }
                if (!mounted) return;
                Navigator.of(this.context).pop();
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    name.dispose();
    category.dispose();
    city.dispose();
    address.dispose();
    phone.dispose();
    gst.dispose();
    owner.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final businessesAsync = ref.watch(businessesProvider);
    final ordersAsync = ref.watch(allOrdersProvider);
    return businessesAsync.when(
      data: (businesses) {
        return ordersAsync.when(
          data: (orders) {
            final totalByBusiness = <String, int>{};
            final completedByBusiness = <String, int>{};
            final userCreatedByBusiness = <String, int>{};
            for (final order in orders) {
              totalByBusiness[order.businessId] =
                  (totalByBusiness[order.businessId] ?? 0) + 1;
              final isCompleted =
                  order.delivery.status == DeliveryStatus.delivered ||
                  order.status == OrderStatus.completed;
              if (isCompleted) {
                completedByBusiness[order.businessId] =
                    (completedByBusiness[order.businessId] ?? 0) + 1;
              }
              if (order.requesterType == OrderRequesterType.customer) {
                userCreatedByBusiness[order.businessId] =
                    (userCreatedByBusiness[order.businessId] ?? 0) + 1;
              }
            }

            final query = _searchController.text.trim().toLowerCase();
            final filtered = businesses.where((b) {
              if (query.isEmpty) return true;
              return b.name.toLowerCase().contains(query) ||
                  b.category.toLowerCase().contains(query) ||
                  b.city.toLowerCase().contains(query) ||
                  (b.address ?? '').toLowerCase().contains(query);
            }).toList();
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        decoration: const InputDecoration(
                          labelText: 'Search businesses',
                          prefixIcon: Icon(Icons.search),
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.icon(
                      onPressed: () => _showBusinessDialog(),
                      icon: const Icon(Icons.add),
                      label: const Text('Add'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ...filtered.map((business) {
                  final total = totalByBusiness[business.id] ?? 0;
                  final completed = completedByBusiness[business.id] ?? 0;
                  final userCreated = userCreatedByBusiness[business.id] ?? 0;
                  return Card(
                    child: ListTile(
                      title: Text(business.name),
                      subtitle: Text(
                        '${business.category} • ${business.city}\n'
                        'Status: ${business.status.name}\n'
                        'Completed Orders: $completed • Created by Users: $userCreated • Total: $total',
                      ),
                      isThreeLine: true,
                      trailing: PopupMenuButton<String>(
                        onSelected: (value) async {
                          if (value == 'edit') {
                            await _showBusinessDialog(business: business);
                          } else if (value == 'delete') {
                            await ref
                                .read(firestoreServiceProvider)
                                .deleteBusiness(business.id);
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
          error: (err, _) => Center(child: Text('Error loading orders: $err')),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(child: Text('Error: $err')),
    );
  }
}

class _OrdersTab extends ConsumerStatefulWidget {
  const _OrdersTab();

  @override
  ConsumerState<_OrdersTab> createState() => _OrdersTabState();
}

class _OrdersTabState extends ConsumerState<_OrdersTab> {
  final _searchController = TextEditingController();

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
                      .map((e) => DropdownMenuItem(value: e, child: Text(e.name)))
                      .toList(),
                  onChanged: (v) => setLocal(() => status = v ?? status),
                  decoration: const InputDecoration(labelText: 'Order Status'),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<DeliveryStatus>(
                  initialValue: delivery,
                  items: DeliveryStatus.values
                      .map((e) => DropdownMenuItem(value: e, child: Text(e.name)))
                      .toList(),
                  onChanged: (v) => setLocal(() => delivery = v ?? delivery),
                  decoration: const InputDecoration(labelText: 'Delivery Status'),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<PaymentStatus>(
                  initialValue: paymentStatus,
                  items: PaymentStatus.values
                      .map((e) => DropdownMenuItem(value: e, child: Text(e.name)))
                      .toList(),
                  onChanged: (v) => setLocal(() => paymentStatus = v ?? paymentStatus),
                  decoration: const InputDecoration(labelText: 'Payment Status'),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<PaymentMethod>(
                  initialValue: paymentMethod,
                  items: PaymentMethod.values
                      .map((e) => DropdownMenuItem(value: e, child: Text(e.name)))
                      .toList(),
                  onChanged: (v) => setLocal(() => paymentMethod = v ?? paymentMethod),
                  decoration: const InputDecoration(labelText: 'Payment Method'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: amount,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Payment Amount'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
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
    final ordersAsync = ref.watch(allOrdersProvider);
    return ordersAsync.when(
      data: (orders) {
        final query = _searchController.text.trim().toLowerCase();
        final filtered = orders.where((o) {
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
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            ...filtered.map((order) {
              return Card(
                child: ListTile(
                  title: Text('Order ${order.displayOrderNumber} • ${order.businessName}'),
                  subtitle: Text(
                    'Customer: ${order.customerName}\n'
                    'Status: ${order.status.name} • Payment: ${order.payment.status.name} • Delivery: ${order.delivery.status.name}',
                  ),
                  isThreeLine: true,
                  trailing: PopupMenuButton<String>(
                    onSelected: (value) async {
                      if (value == 'edit') {
                        await _editOrderDialog(order);
                      } else if (value == 'delete') {
                        await ref.read(firestoreServiceProvider).deleteOrder(order.id);
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
      error: (err, _) => Center(child: Text('Error: $err')),
    );
  }
}

class _DeliveryAgentsTab extends ConsumerStatefulWidget {
  const _DeliveryAgentsTab();

  @override
  ConsumerState<_DeliveryAgentsTab> createState() => _DeliveryAgentsTabState();
}

class _DeliveryAgentsTabState extends ConsumerState<_DeliveryAgentsTab> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _showAgentDialog(
    List<BusinessProfile> businesses, {
    DeliveryAgent? agent,
  }) async {
    final name = TextEditingController(text: agent?.name ?? '');
    final phone = TextEditingController(text: agent?.phone ?? '');
    var businessId = agent?.businessId ?? (businesses.isNotEmpty ? businesses.first.id : '');
    var isActive = agent?.isActive ?? true;
    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: Text(agent == null ? 'Add Delivery Agent' : 'Edit Delivery Agent'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (businesses.isNotEmpty)
                  DropdownButtonFormField<String>(
                    initialValue: businessId,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Business'),
                    items: businesses
                        .map((b) => DropdownMenuItem(value: b.id, child: Text(b.name)))
                        .toList(),
                    onChanged: (value) => setLocal(() => businessId = value ?? businessId),
                  ),
                const SizedBox(height: 8),
                TextField(controller: name, decoration: const InputDecoration(labelText: 'Name')),
                const SizedBox(height: 8),
                TextField(controller: phone, decoration: const InputDecoration(labelText: 'Phone')),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Active'),
                  value: isActive,
                  onChanged: (v) => setLocal(() => isActive = v),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            FilledButton(
              onPressed: () async {
                if (businessId.isEmpty || name.text.trim().isEmpty || phone.text.trim().isEmpty) {
                  return;
                }
                if (agent == null) {
                  final id = ref.read(firestoreProvider).collection('deliveryAgents').doc().id;
                  await ref.read(firestoreServiceProvider).createDeliveryAgent(
                        DeliveryAgent(
                          id: id,
                          businessId: businessId,
                          name: name.text.trim(),
                          phone: phone.text.trim(),
                          isActive: isActive,
                          createdAt: DateTime.now(),
                          updatedAt: DateTime.now(),
                        ),
                      );
                } else {
                  await ref.read(firestoreServiceProvider).updateDeliveryAgent(agent.id, {
                    'businessId': businessId,
                    'name': name.text.trim(),
                    'phone': phone.text.trim(),
                    'isActive': isActive,
                  });
                }
                if (!mounted) return;
                Navigator.of(this.context).pop();
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    name.dispose();
    phone.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final agentsAsync = ref.watch(allDeliveryAgentsProvider);
    final businessesAsync = ref.watch(businessesProvider);
    return businessesAsync.when(
      data: (businesses) {
        final businessMap = {for (final b in businesses) b.id: b.name};
        return agentsAsync.when(
          data: (agents) {
            final query = _searchController.text.trim().toLowerCase();
            final filtered = agents.where((a) {
              if (query.isEmpty) return true;
              return a.name.toLowerCase().contains(query) ||
                  a.phone.toLowerCase().contains(query) ||
                  (businessMap[a.businessId] ?? '').toLowerCase().contains(query);
            }).toList();
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        decoration: const InputDecoration(
                          labelText: 'Search delivery agents',
                          prefixIcon: Icon(Icons.search),
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.icon(
                      onPressed: () => _showAgentDialog(businesses),
                      icon: const Icon(Icons.add),
                      label: const Text('Add'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ...filtered.map((agent) {
                  return Card(
                    child: ListTile(
                      title: Text(agent.name),
                      subtitle: Text(
                        '${agent.phone}\n${businessMap[agent.businessId] ?? agent.businessId} • ${agent.isActive ? 'Active' : 'Inactive'}',
                      ),
                      isThreeLine: true,
                      trailing: PopupMenuButton<String>(
                        onSelected: (value) async {
                          if (value == 'edit') {
                            await _showAgentDialog(businesses, agent: agent);
                          } else if (value == 'delete') {
                            await ref.read(firestoreServiceProvider).deleteDeliveryAgent(agent.id);
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
          error: (err, _) => Center(child: Text('Error: $err')),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(child: Text('Error: $err')),
    );
  }
}
