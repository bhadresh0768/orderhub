import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart' show StateProvider;

import 'package:todo_reminder_alarm/providers.dart';

final _adminContactSearchProvider = StateProvider.autoDispose<String>(
  (ref) => '',
);

class AdminContactUsTab extends ConsumerStatefulWidget {
  const AdminContactUsTab({super.key});

  @override
  ConsumerState<AdminContactUsTab> createState() => _AdminContactUsTabState();
}

class _AdminContactUsTabState extends ConsumerState<AdminContactUsTab> {
  final _searchController = TextEditingController();

  String _capitalize(String value) {
    if (value.isEmpty) return value;
    return value[0].toUpperCase() + value.substring(1);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final contactAsync = ref.watch(allContactUsProvider);
    final query = ref.watch(_adminContactSearchProvider).trim().toLowerCase();
    return contactAsync.when(
      data: (messages) {
        final filtered = messages.where((message) {
          if (query.isEmpty) return true;
          return message.name.toLowerCase().contains(query) ||
              message.mobileNumber.toLowerCase().contains(query) ||
              message.description.toLowerCase().contains(query);
        }).toList();
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                labelText: 'Search contact requests',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (value) {
                ref.read(_adminContactSearchProvider.notifier).state = value;
              },
            ),
            const SizedBox(height: 12),
            if (filtered.isEmpty) const Text('No contact requests found.'),
            ...filtered.map((message) {
              final created = message.createdAt
                      ?.toLocal()
                      .toString()
                      .split('.')
                      .first ??
                  '-';
              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  title: Text(message.name),
                  subtitle: Text(
                    'Role: ${_capitalize(message.userRole.name)}\n'
                    'Mobile: ${message.mobileNumber}\n'
                    'Created: $created\n'
                    '${message.description}',
                  ),
                  isThreeLine: true,
                ),
              );
            }),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(child: Text('Error loading contact requests: $err')),
    );
  }
}
