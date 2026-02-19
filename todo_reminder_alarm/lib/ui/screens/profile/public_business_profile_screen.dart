import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:android_intent_plus/android_intent.dart';

import '../../../app/deep_link_utils.dart';
import '../../../models/business.dart';

class PublicBusinessProfileScreen extends ConsumerWidget {
  const PublicBusinessProfileScreen({super.key, required this.business});

  final BusinessProfile business;

  String _buildShareMessage({
    required String businessId,
    required String businessName,
    required String category,
    required String city,
    required String? businessLink,
  }) {
    final lines = <String>[
      'Check out $businessName on OrderHub.',
      'Category: $category',
      'City: $city',
      'Open in app: ${businessDeepLink(businessId)}',
    ];
    lines.add('Web profile: ${businessWebDeepLink(businessId)}');
    if ((businessLink ?? '').trim().isNotEmpty) {
      lines.add('Business link: ${businessLink!.trim()}');
    }
    return lines.join('\n');
  }

  Future<void> _copyText(
    BuildContext context,
    String label,
    String value,
  ) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('$label copied')));
  }

  Future<void> _callBusiness(BuildContext context) async {
    final phone = (business.phone ?? '').trim();
    if (phone.isEmpty) return;
    try {
      final intent = AndroidIntent(action: 'android.intent.action.DIAL', data: 'tel:$phone');
      await intent.launch();
    } catch (_) {
      await Clipboard.setData(ClipboardData(text: phone));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Business Public Profile')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 34,
                        backgroundImage: (business.logoUrl ?? '').isNotEmpty
                            ? NetworkImage(business.logoUrl!)
                            : null,
                        child: (business.logoUrl ?? '').isEmpty
                            ? const Icon(Icons.store, size: 30)
                            : null,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              business.name,
                              style: Theme.of(context).textTheme.headlineSmall,
                            ),
                            const SizedBox(height: 4),
                            Text('${business.category} • ${business.city}'),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if ((business.description ?? '').trim().isNotEmpty) ...[
                    Text(
                      business.description!.trim(),
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    const SizedBox(height: 12),
                  ],
                  if ((business.address ?? '').trim().isNotEmpty) ...[
                    Text('Address: ${business.address!.trim()}'),
                    const SizedBox(height: 8),
                  ],
                  if (business.city.trim().isNotEmpty) ...[
                    Text('City: ${business.city.trim()}'),
                    const SizedBox(height: 8),
                  ],
                  if ((business.phone ?? '').trim().isNotEmpty) ...[
                    Text('Contact: ${business.phone!.trim()}'),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: () => _callBusiness(context),
                      icon: const Icon(Icons.call_outlined),
                      label: const Text('Call Now'),
                    ),
                    const SizedBox(height: 8),
                  ],
                  if ((business.gstNumber ?? '').trim().isNotEmpty) ...[
                    Text('Business Unique No: ${business.gstNumber!.trim()}'),
                    const SizedBox(height: 8),
                  ],
                  if ((business.shareLink ?? '').trim().isNotEmpty) ...[
                    Text('Business Link: ${business.shareLink!.trim()}'),
                    const SizedBox(height: 8),
                  ],
                  Text('Deep Link: ${businessDeepLink(business.id)}'),
                  const SizedBox(height: 8),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () => _copyText(
                          context,
                          'Deep link',
                          businessDeepLink(business.id),
                        ),
                        icon: const Icon(Icons.link),
                        label: const Text('Copy Deep Link'),
                      ),
                      OutlinedButton.icon(
                        onPressed: (business.shareLink ?? '').trim().isEmpty
                            ? null
                            : () => _copyText(
                                context,
                                'Business link',
                                business.shareLink!.trim(),
                              ),
                        icon: const Icon(Icons.copy),
                        label: const Text('Copy Business Link'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => _copyText(
                          context,
                          'Share text',
                          _buildShareMessage(
                            businessId: business.id,
                            businessName: business.name,
                            category: business.category,
                            city: business.city,
                            businessLink: business.shareLink,
                          ),
                        ),
                        icon: const Icon(Icons.ios_share),
                        label: const Text('Copy Share Text'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
