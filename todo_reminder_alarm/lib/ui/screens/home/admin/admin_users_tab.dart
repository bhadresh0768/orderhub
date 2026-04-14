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

  String _primaryContact(AppUser user) {
    if (user.phoneNumber != null && user.phoneNumber!.trim().isNotEmpty) {
      return user.phoneNumber!.trim();
    }
    if (user.email.trim().isNotEmpty) return user.email.trim();
    return '-';
  }

  String _optionalText(String? value) {
    final text = value?.trim() ?? '';
    return text.isEmpty ? '-' : text;
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
                final name = user.name.isEmpty ? 'Unknown' : user.name;
                final shopName = _optionalText(user.shopName);
                final address = _optionalText(user.address);
                final contact = _primaryContact(user);
                return Card(
                  color: Colors.red.shade50,
                  child: ListTile(
                    title: Text(
                      name,
                      style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: Text(
                      '$contact\nShop: $shopName\nAddress: $address',
                      style: const TextStyle(fontSize: 15.5, height: 1.3),
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
              final name = user.name.isEmpty ? 'Unknown' : user.name;
              final shopName = _optionalText(user.shopName);
              final address = _optionalText(user.address);
              final contact = _primaryContact(user);
              return Card(
                child: ListTile(
                  title: Text(
                    name,
                    style: const TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      '$contact\n'
                      'Shop: $shopName\n'
                      'Address: $address\n'
                      'Status: ${user.isActive ? 'Active' : 'Inactive'}',
                      style: const TextStyle(fontSize: 16, height: 1.35),
                    ),
                  ),
                  isThreeLine: false,
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
