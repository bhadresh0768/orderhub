import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../../../models/app_user.dart';
import '../../../models/business.dart';
import '../../../models/quote.dart';
import '../../../providers.dart';
import '../../../utils/file_storage_helper.dart';
import '../../../utils/money_format.dart';
import '../../../utils/quote_pdf_generator.dart';
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

  String _quoteShareMessage(Quote quote) {
    return 'Quotation ${quote.quoteNumber}\n'
        'Business: ${quote.customerName}\n'
        'Valid Until: ${DateFormat('dd MMM yyyy').format(quote.validUntil)}\n'
        'Total: ${formatMoney(quote.grandTotal, currencySymbol: quote.currencySymbol)}';
  }

  QuotePdfDocumentData _buildPdfDocument(
    Quote quote,
    BusinessProfile business,
  ) {
    return QuotePdfDocumentData(
      quoteNumber: quote.quoteNumber,
      quoteDate: quote.quoteDate,
      validUntil: quote.validUntil,
      currencySymbol: quote.currencySymbol,
      preparedBy: quote.preparedBy,
      business: QuotePdfParty(
        name: business.name,
        address: business.address,
        phone: business.phone ?? business.ownerPhone,
        email: profile.email.trim().isEmpty ? null : profile.email.trim(),
        taxRegistrationLabel: business.taxLabel,
        taxRegistrationNumber: business.gstNumber,
      ),
      customer: QuotePdfParty(
        name: quote.customerName,
        contactName: quote.customerContact,
        address: quote.customerAddress,
        phone: quote.customerPhone,
        email: quote.customerEmail,
      ),
      items: quote.items
          .map(
            (item) => QuotePdfLineItem(
              title: item.title,
              description: item.description,
              quantity: item.quantity,
              unit: item.unit,
              unitPrice: item.unitPrice,
              discountAmount: item.discountAmount,
              taxPercent: item.taxPercent,
            ),
          )
          .toList(),
      extraCharges: quote.extraCharges,
      extraChargesLabel: quote.extraChargesLabel,
      notes: quote.notes,
      paymentTerms: quote.paymentTerms,
      deliveryTimeline: quote.deliveryTimeline,
      additionalTerms: quote.additionalTerms,
      businessLogoUrl: business.logoUrl,
    );
  }

  Future<void> _shareQuote(BuildContext context, WidgetRef ref) async {
    try {
      final business = await ref.read(
        businessByIdProvider(quote.businessId).future,
      );
      if (business == null) {
        throw StateError('Business not found for this quotation');
      }
      final pdfBytes = await QuotePdfGenerator.buildQuotePdf(
        _buildPdfDocument(quote, business),
      );
      final fileName =
          'quote_${quote.quoteNumber.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_')}.pdf';
      final file = await FileStorageHelper.savePdfToUserVisibleLocation(
        bytes: pdfBytes,
        fileName: fileName,
      );
      await SharePlus.instance.share(
        ShareParams(
          text: _quoteShareMessage(quote),
          files: [XFile(file.path)],
          subject: 'Quotation ${quote.quoteNumber}',
        ),
      );
    } catch (err) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to share quotation: $err')),
      );
    }
  }

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
                  formatMoney(
                    quote.grandTotal,
                    currencySymbol: quote.currencySymbol,
                  ),
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
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
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
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  visualDensity: VisualDensity.compact,
                  icon: Icon(Icons.edit_outlined, color: Colors.green.shade700),
                ),
                const SizedBox(width: 14),
                IconButton(
                  onPressed: () => _shareQuote(context, ref),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.share_outlined),
                ),
                const SizedBox(width: 14),
                IconButton(
                  onPressed: () => _deleteQuote(context, ref),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  visualDensity: VisualDensity.compact,
                  icon: Icon(Icons.delete_outline, color: Colors.red.shade700),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
