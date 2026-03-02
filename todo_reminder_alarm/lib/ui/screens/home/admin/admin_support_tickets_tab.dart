import 'package:cloud_firestore/cloud_firestore.dart' hide Order;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:todo_reminder_alarm/models/enums.dart';
import 'package:todo_reminder_alarm/models/support_ticket.dart';
import 'package:todo_reminder_alarm/providers.dart';
import 'admin_home_state.dart';

class AdminSupportTicketsTab extends ConsumerStatefulWidget {
  const AdminSupportTicketsTab({super.key});

  @override
  ConsumerState<AdminSupportTicketsTab> createState() =>
      _AdminSupportTicketsTabState();
}

class _AdminSupportTicketsTabState extends ConsumerState<AdminSupportTicketsTab> {
  final _searchController = TextEditingController();
  static const _searchKey = 'support_tickets';

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

  Future<void> _updateTicketDialog(SupportTicket ticket) async {
    var nextStatus = ticket.status;
    var noteText = ticket.adminNote ?? '';
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: Text('Update Ticket ${ticket.id.substring(0, 6)}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<SupportTicketStatus>(
                  initialValue: nextStatus,
                  decoration: const InputDecoration(labelText: 'Ticket Status'),
                  items: SupportTicketStatus.values
                      .map(
                        (status) => DropdownMenuItem(
                          value: status,
                          child: Text(_capitalize(status.name)),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value == null) return;
                    setLocal(() => nextStatus = value);
                  },
                ),
                const SizedBox(height: 8),
                TextFormField(
                  initialValue: noteText,
                  maxLines: 3,
                  onChanged: (value) => noteText = value,
                  decoration: const InputDecoration(
                    labelText: 'Admin Note',
                    hintText: 'Visible to user',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                final data = <String, dynamic>{
                  'status': enumToString(nextStatus),
                  'adminNote': noteText.trim().isEmpty ? null : noteText.trim(),
                };
                if (nextStatus == SupportTicketStatus.resolved ||
                    nextStatus == SupportTicketStatus.closed) {
                  data['resolvedAt'] = Timestamp.fromDate(DateTime.now());
                } else {
                  data['resolvedAt'] = null;
                }
                await ref
                    .read(firestoreServiceProvider)
                    .updateSupportTicket(ticket.id, data);
                if (!dialogContext.mounted) return;
                Navigator.of(dialogContext).pop();
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final search = ref.watch(adminSearchProvider(_searchKey));
    final statusFilter = ref.watch(adminTicketStatusProvider);
    final ticketsAsync = ref.watch(allSupportTicketsProvider);
    return ticketsAsync.when(
      data: (tickets) {
        final query = search.trim().toLowerCase();
        final filtered = tickets.where((ticket) {
          if (statusFilter != null && ticket.status != statusFilter) {
            return false;
          }
          if (query.isEmpty) return true;
          return ticket.userName.toLowerCase().contains(query) ||
              ticket.id.toLowerCase().contains(query) ||
              (ticket.orderId ?? '').toLowerCase().contains(query) ||
              ticket.description.toLowerCase().contains(query);
        }).toList();
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                labelText: 'Search tickets',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (value) {
                ref.read(adminSearchProvider(_searchKey).notifier).state = value;
              },
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<SupportTicketStatus?>(
              initialValue: statusFilter,
              decoration: const InputDecoration(labelText: 'Status Filter'),
              items: [
                const DropdownMenuItem(value: null, child: Text('All')),
                ...SupportTicketStatus.values.map(
                  (status) => DropdownMenuItem(
                    value: status,
                    child: Text(_capitalize(status.name)),
                  ),
                ),
              ],
              onChanged: (value) {
                ref.read(adminTicketStatusProvider.notifier).state = value;
              },
            ),
            const SizedBox(height: 12),
            if (filtered.isEmpty) const Text('No support tickets found.'),
            ...filtered.map((ticket) {
              final created =
                  ticket.createdAt?.toLocal().toString().split('.').first ?? '-';
              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  title: Text(
                    '${ticket.userName} • ${_capitalize(ticket.issueType.name)}',
                  ),
                  subtitle: Text(
                    'Role: ${_capitalize(ticket.userRole.name)} | Priority: ${_capitalize(ticket.priority.name)} | Status: ${_capitalize(ticket.status.name)}\n'
                    'Created: $created'
                    '${ticket.orderId == null ? '' : ' | Order: ${ticket.orderId}'}\n'
                    '${ticket.description}'
                    '${ticket.attachments.isEmpty ? '' : '\nAttachments: ${ticket.attachments.length}'}'
                    '${(ticket.adminNote ?? '').trim().isEmpty ? '' : '\nAdmin Note: ${ticket.adminNote!.trim()}'}',
                  ),
                  isThreeLine: true,
                  trailing: IconButton(
                    onPressed: () => _updateTicketDialog(ticket),
                    icon: const Icon(Icons.edit_outlined),
                    tooltip: 'Update ticket',
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
