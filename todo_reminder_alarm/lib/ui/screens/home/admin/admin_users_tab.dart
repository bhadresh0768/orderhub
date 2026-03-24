import 'package:cloud_firestore/cloud_firestore.dart' hide Order;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:todo_reminder_alarm/models/app_user.dart';
import 'package:todo_reminder_alarm/models/enums.dart';
import 'package:todo_reminder_alarm/providers.dart';
import 'admin_customer_detail_screen.dart';
import 'admin_home_state.dart';

class AdminUsersTab extends ConsumerStatefulWidget {
  const AdminUsersTab({super.key});

  @override
  ConsumerState<AdminUsersTab> createState() => _AdminUsersTabState();
}

class _AdminUsersTabState extends ConsumerState<AdminUsersTab> {
  final _searchController = TextEditingController();
  static const _searchKey = 'users';

  String _capitalize(String value) {
    if (value.isEmpty) return value;
    return value[0].toUpperCase() + value.substring(1);
  }

  String _fmtDate(DateTime? date) {
    if (date == null) return '-';
    final d = date.toLocal();
    final mm = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    return '${d.year}-$mm-$dd';
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
                TextField(
                  controller: name,
                  decoration: const InputDecoration(labelText: 'Name'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: email,
                  decoration: const InputDecoration(labelText: 'Email'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: phone,
                  decoration: const InputDecoration(labelText: 'Phone'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: shop,
                  decoration: const InputDecoration(labelText: 'Shop Name'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: address,
                  decoration: const InputDecoration(labelText: 'Address'),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<UserRole>(
                  initialValue: role,
                  items: UserRole.values
                      .map(
                        (e) => DropdownMenuItem(value: e, child: Text(e.name)),
                      )
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
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                await ref.read(firestoreServiceProvider).updateUser(user.id, {
                  'name': name.text.trim(),
                  'email': email.text.trim(),
                  'phoneNumber': phone.text.trim(),
                  'shopName': shop.text.trim().isEmpty
                      ? null
                      : shop.text.trim(),
                  'address': address.text.trim().isEmpty
                      ? null
                      : address.text.trim(),
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

  Future<void> _reviewDeleteRequest(
    AppUser user, {
    required bool approve,
  }) async {
    final action = approve ? 'approve' : 'reject';
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('${approve ? 'Approve' : 'Reject'} Delete Request'),
        content: Text(
          'Do you want to $action delete request for ${user.name.isEmpty ? user.id : user.name}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(approve ? 'Approve' : 'Reject'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    final adminUid = ref.read(authStateProvider).value?.uid;
    await ref.read(firestoreServiceProvider).updateUser(user.id, {
      'deleteRequestStatus': approve ? 'approved' : 'rejected',
      'deleteReviewedAt': FieldValue.serverTimestamp(),
      'deleteReviewedBy': adminUid,
      if (approve) 'isActive': false,
    });
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          approve
              ? 'Delete request approved for ${user.name}'
              : 'Delete request rejected for ${user.name}',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final search = ref.watch(adminSearchProvider(_searchKey));
    final usersAsync = ref.watch(allUsersProvider);
    return usersAsync.when(
      data: (users) {
        final query = search.trim().toLowerCase();
        final pendingDeleteRequests = users
            .where((u) => (u.deleteRequestStatus ?? '') == 'pending')
            .toList();
        final customerUsers = users.where((u) => u.role == UserRole.customer);
        final filtered = customerUsers.where((u) {
          if (query.isEmpty) return true;
          return u.name.toLowerCase().contains(query) ||
              u.email.toLowerCase().contains(query) ||
              (u.phoneNumber ?? '').toLowerCase().contains(query);
        }).toList();
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text('Customer List'),
            const SizedBox(height: 12),
            if (pendingDeleteRequests.isNotEmpty) ...[
              Text(
                'Delete Account Requests',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              ...pendingDeleteRequests.map((user) {
                return Card(
                  color: Colors.red.shade50,
                  child: ListTile(
                    title: Text(user.name.isEmpty ? 'Unknown' : user.name),
                    subtitle: Text(
                      '${user.email.isEmpty ? (user.phoneNumber ?? '-') : user.email}\nRole: ${_capitalize(user.role.name)}',
                    ),
                    isThreeLine: true,
                    trailing: PopupMenuButton<String>(
                      onSelected: (value) async {
                        if (value == 'approve') {
                          await _reviewDeleteRequest(user, approve: true);
                        } else if (value == 'reject') {
                          await _reviewDeleteRequest(user, approve: false);
                        }
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(
                          value: 'approve',
                          child: Text('Approve Delete'),
                        ),
                        PopupMenuItem(
                          value: 'reject',
                          child: Text('Reject Delete'),
                        ),
                      ],
                    ),
                  ),
                );
              }),
              const Divider(height: 24),
            ],
            const SizedBox(height: 10),
            TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                labelText: 'Search users',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (value) {
                ref.read(adminSearchProvider(_searchKey).notifier).state =
                    value;
              },
            ),
            const SizedBox(height: 12),
            ...filtered.map((user) {
              return Card(
                child: ListTile(
                  title: Text(user.name.isEmpty ? 'Unknown' : user.name),
                  subtitle: Text(
                    '${user.email.isEmpty ? (user.phoneNumber ?? '-') : user.email}\n'
                    'Status: ${user.isActive ? 'Active' : 'Inactive'}\n'
                    'Role: ${_capitalize(user.role.name)}',
                  ),
                  isThreeLine: true,
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) =>
                            AdminCustomerDetailScreen(customer: user),
                      ),
                    );
                  },
                  leading: (user.deleteRequestStatus ?? '') == 'pending'
                      ? const Icon(
                          Icons.warning_amber_rounded,
                          color: Colors.red,
                        )
                      : null,
                  trailing: PopupMenuButton<String>(
                    onSelected: (value) async {
                      if (value == 'edit') {
                        await _editUserDialog(user);
                      } else if (value == 'delete') {
                        await ref
                            .read(firestoreServiceProvider)
                            .deleteUser(user.id);
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
  }
}
