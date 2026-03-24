import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:todo_reminder_alarm/models/business.dart';
import 'package:todo_reminder_alarm/providers.dart';

import 'admin_business_detail_screen.dart';

class AdminSubscriptionsTab extends ConsumerWidget {
  const AdminSubscriptionsTab({super.key});

  String _fmtDate(DateTime? date) {
    if (date == null) return '-';
    final d = date.toLocal();
    final dd = d.day.toString().padLeft(2, '0');
    final mm = d.month.toString().padLeft(2, '0');
    return '$dd-$mm-${d.year}';
  }

  String _alertText(BusinessProfile business, DateTime now) {
    final end = business.subscriptionEndDate!;
    final endDate = DateTime(end.year, end.month, end.day);
    final currentDate = DateTime(now.year, now.month, now.day);
    final daysLeft = endDate.difference(currentDate).inDays;
    final dayLabel = daysLeft == 1 ? 'day' : 'days';
    return 'Ending in $daysLeft $dayLabel on ${_fmtDate(end)}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final businessesAsync = ref.watch(businessesProvider);
    return businessesAsync.when(
      data: (businesses) {
        final now = DateTime.now();
        final expiring = businesses.where((business) {
          final end = business.subscriptionEndDate;
          return business.subscriptionActive &&
              end != null &&
              !now.isAfter(end) &&
              !end.isAfter(now.add(const Duration(days: 30)));
        }).toList()
          ..sort((a, b) => a.subscriptionEndDate!.compareTo(b.subscriptionEndDate!));

        if (expiring.isEmpty) {
          return const Center(
            child: Text('No business subscriptions expiring in the next 30 days.'),
          );
        }

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'Expiring Business Subscriptions',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            ...expiring.map((business) {
              return Card(
                child: ListTile(
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => AdminBusinessDetailScreen(business: business),
                      ),
                    );
                  },
                  title: Text(business.name),
                  subtitle: Text(
                    '${business.category} • ${business.city}\n${_alertText(business, now)}',
                    style: TextStyle(color: Colors.red.shade800),
                  ),
                  isThreeLine: true,
                  leading: Icon(
                    Icons.warning_amber_rounded,
                    color: Colors.red.shade700,
                  ),
                  trailing: const Icon(Icons.chevron_right),
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
