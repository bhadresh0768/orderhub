import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../models/app_user.dart';
import '../../../models/quote.dart';
import '../../../providers.dart';
import 'create_quote_screen.dart';

class QuoteHistoryScreen extends ConsumerWidget {
  const QuoteHistoryScreen({super.key, required this.profile});

  final AppUser profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final businessId = profile.businessId;
    if (businessId == null) {
      return const Scaffold(body: Center(child: Text('No business linked')));
    }
    final quotesAsync = ref.watch(quotesForBusinessProvider(businessId));
    return Scaffold(
      appBar: AppBar(title: const Text('Quotation History')),
      body: quotesAsync.when(
        data: (quotes) {
          if (quotes.isEmpty) {
            return const Center(child: Text('No quotations saved yet'));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: quotes.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final quote = quotes[index];
              return _QuoteHistoryCard(profile: profile, quote: quote);
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) =>
            Center(child: Text('Failed to load quotations: $err')),
      ),
    );
  }
}

class _QuoteHistoryCard extends ConsumerWidget {
  const _QuoteHistoryCard({required this.profile, required this.quote});

  final AppUser profile;
  final Quote quote;

  Future<void> _deleteQuote(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Quotation'),
        content: Text('Delete ${quote.quoteNumber} for ${quote.customerName}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    try {
      await ref.read(firestoreServiceProvider).deleteQuote(quote.id);
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Quotation deleted')));
    } catch (err) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete quotation: $err')),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final money = NumberFormat('#,##0.00');
    final updatedLabel = quote.updatedAt ?? quote.createdAt ?? quote.quoteDate;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        quote.quoteNumber,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        quote.customerName,
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Updated ${DateFormat('dd MMM yyyy').format(updatedLabel)}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                Text(
                  '${quote.currencySymbol} ${money.format(quote.grandTotal)}',
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Items: ${quote.items.length}'
              '${(quote.customerPhone ?? '').trim().isEmpty ? '' : ' • ${quote.customerPhone!.trim()}'}',
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => CreateQuoteScreen(
                            profile: profile,
                            initialQuote: quote,
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('Edit'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _deleteQuote(context, ref),
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Delete'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
