import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:todo_reminder_alarm/models/business.dart';
import 'package:todo_reminder_alarm/models/enums.dart';
import 'package:todo_reminder_alarm/providers.dart';
import 'admin_business_detail_screen.dart';
import 'admin_edit_dialogs.dart';
import 'admin_home_state.dart';

class AdminBusinessesTab extends ConsumerStatefulWidget {
  const AdminBusinessesTab({super.key});

  @override
  ConsumerState<AdminBusinessesTab> createState() => _AdminBusinessesTabState();
}

class _AdminBusinessesTabState extends ConsumerState<AdminBusinessesTab> {
  final _searchController = TextEditingController();
  static const _searchKey = 'businesses';

  String _fmtDate(DateTime? date) {
    if (date == null) return '-';
    final d = date.toLocal();
    final dd = d.day.toString().padLeft(2, '0');
    final mm = d.month.toString().padLeft(2, '0');
    return '$dd-$mm-${d.year}';
  }

  String _subscriptionAlertText(BusinessProfile business) {
    final end = business.subscriptionEndDate!;
    final now = DateTime.now();
    final endDate = DateTime(end.year, end.month, end.day);
    final currentDate = DateTime(now.year, now.month, now.day);
    final daysLeft = endDate.difference(currentDate).inDays;
    final dayLabel = daysLeft == 1 ? 'day' : 'days';
    return 'Subscription ending in $daysLeft $dayLabel on ${_fmtDate(end)}';
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

  @override
  Widget build(BuildContext context) {
    final search = ref.watch(adminSearchProvider(_searchKey));
    final businessesAsync = ref.watch(businessesProvider);
    final ordersAsync = ref.watch(allOrdersProvider);
    return businessesAsync.when(
      data: (businesses) {
        return ordersAsync.when(
          data: (orders) {
            final completedByBusiness = <String, int>{};
            final pendingByBusiness = <String, int>{};
            final processingByBusiness = <String, int>{};
            for (final order in orders) {
              switch (order.status) {
                case OrderStatus.pending:
                  pendingByBusiness[order.businessId] =
                      (pendingByBusiness[order.businessId] ?? 0) + 1;
                case OrderStatus.approved:
                case OrderStatus.inProgress:
                  processingByBusiness[order.businessId] =
                      (processingByBusiness[order.businessId] ?? 0) + 1;
                case OrderStatus.completed:
                  completedByBusiness[order.businessId] =
                      (completedByBusiness[order.businessId] ?? 0) + 1;
                case OrderStatus.cancelled:
                  break;
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
                      onPressed: () => showAdminBusinessDialog(context, ref),
                      icon: const Icon(Icons.add),
                      label: const Text('Add'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ...filtered.map((business) {
                  final completed = completedByBusiness[business.id] ?? 0;
                  final pending = pendingByBusiness[business.id] ?? 0;
                  final processing = processingByBusiness[business.id] ?? 0;
                  final now = DateTime.now();
                  final subscriptionEndDate = business.subscriptionEndDate;
                  final showSubscriptionAlert =
                      business.subscriptionActive &&
                      subscriptionEndDate != null &&
                      !now.isAfter(subscriptionEndDate) &&
                      !subscriptionEndDate.isAfter(
                        now.add(const Duration(days: 30)),
                      );
                  return Card(
                    child: InkWell(
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) =>
                                AdminBusinessDetailScreen(business: business),
                          ),
                        );
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Container(
                                    width: 56,
                                    height: 56,
                                    color: Colors.black12,
                                    child: (business.logoUrl?.trim().isNotEmpty ??
                                            false)
                                        ? Image.network(
                                            business.logoUrl!.trim(),
                                            fit: BoxFit.cover,
                                            errorBuilder: (context, error, stackTrace) =>
                                                const Icon(Icons.storefront),
                                          )
                                        : const Icon(Icons.storefront),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        business.name,
                                        style: Theme.of(
                                          context,
                                        ).textTheme.titleMedium?.copyWith(
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        business.category,
                                        style: Theme.of(context).textTheme.bodyMedium,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        (business.address ?? '').trim().isEmpty
                                            ? business.city
                                            : business.address!.trim(),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: Theme.of(context).textTheme.bodySmall,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                _statusChip(
                                  context,
                                  label: 'Pending',
                                  count: pending,
                                ),
                                _statusChip(
                                  context,
                                  label: 'Processing',
                                  count: processing,
                                ),
                                _statusChip(
                                  context,
                                  label: 'Completed',
                                  count: completed,
                                ),
                              ],
                            ),
                            if (showSubscriptionAlert) ...[
                              const SizedBox(height: 10),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.red.shade50,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: Colors.red.shade300,
                                  ),
                                ),
                                child: Text(
                                  _subscriptionAlertText(business),
                                  style: TextStyle(
                                    color: Colors.red.shade800,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
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

  Widget _statusChip(
    BuildContext context, {
    required String label,
    required int count,
  }) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Text(
          '$label: $count',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
