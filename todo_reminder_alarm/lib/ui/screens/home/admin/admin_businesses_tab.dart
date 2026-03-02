import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:todo_reminder_alarm/models/business.dart';
import 'package:todo_reminder_alarm/models/enums.dart';
import 'package:todo_reminder_alarm/providers.dart';
import 'admin_business_detail_screen.dart';
import 'admin_home_state.dart';

class AdminBusinessesTab extends ConsumerStatefulWidget {
  const AdminBusinessesTab({super.key});

  @override
  ConsumerState<AdminBusinessesTab> createState() => _AdminBusinessesTabState();
}

class _AdminBusinessesTabState extends ConsumerState<AdminBusinessesTab> {
  final _searchController = TextEditingController();
  static const _searchKey = 'businesses';

  String _capitalize(String value) {
    if (value.isEmpty) return value;
    return value[0].toUpperCase() + value.substring(1);
  }

  @override
  void initState() {
    super.initState();
    _searchController.text = ref.read(adminSearchProvider(_searchKey));
  }

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
                TextField(
                  controller: name,
                  decoration: const InputDecoration(labelText: 'Business Name'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: category,
                  decoration: const InputDecoration(labelText: 'Category'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: city,
                  decoration: const InputDecoration(labelText: 'City'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: address,
                  decoration: const InputDecoration(labelText: 'Address'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: phone,
                  decoration: const InputDecoration(labelText: 'Phone'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: gst,
                  decoration: const InputDecoration(
                    labelText: 'Business Unique No',
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: owner,
                  decoration: const InputDecoration(labelText: 'Owner UID'),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<BusinessStatus>(
                  initialValue: status,
                  items: BusinessStatus.values
                      .map(
                        (e) => DropdownMenuItem(
                          value: e,
                          child: Text(_capitalize(e.name)),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setLocal(() => status = v ?? status),
                  decoration: const InputDecoration(labelText: 'Status'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
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
                  final id = ref
                      .read(firestoreProvider)
                      .collection('businesses')
                      .doc()
                      .id;
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
                  await ref
                      .read(firestoreServiceProvider)
                      .updateBusiness(business.id, data);
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
    final search = ref.watch(adminSearchProvider(_searchKey));
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

            final query = search.trim().toLowerCase();
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
                        onChanged: (value) {
                          ref.read(adminSearchProvider(_searchKey).notifier).state =
                              value;
                        },
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
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) =>
                                AdminBusinessDetailScreen(business: business),
                          ),
                        );
                      },
                      title: Text(business.name),
                      subtitle: Text(
                        '${business.category} • ${business.city}\n'
                        'Status: ${_capitalize(business.status.name)}\n'
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
          error: (_, _) =>
              const Center(child: Text('Something went wrong. Please retry.')),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) =>
          const Center(child: Text('Something went wrong. Please retry.')),
    );
  }
}
