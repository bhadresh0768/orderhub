import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:android_intent_plus/android_intent.dart';

import '../../../app/deep_link_utils.dart';
import '../../../models/business.dart';
import '../../../providers.dart';

class PublicBusinessProfileScreen extends ConsumerWidget {
  const PublicBusinessProfileScreen({super.key, required this.business});

  final BusinessProfile business;

  String _displayBusinessLinkText({
    required String rawLink,
    required String businessName,
  }) {
    final trimmed = rawLink.trim();
    if (trimmed.isEmpty) return '';
    final normalizedName = businessName.trim().isEmpty
        ? 'business'
        : businessName.trim();
    if (trimmed.startsWith('orderhub://business/')) {
      return 'orderhub://business/$normalizedName';
    }
    return trimmed;
  }

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

  Future<void> _callBusiness(BuildContext context, String phone) async {
    final normalizedPhone = phone.trim();
    if (normalizedPhone.isEmpty) return;
    try {
      final intent = AndroidIntent(
        action: 'android.intent.action.DIAL',
        data: 'tel:$normalizedPhone',
      );
      await intent.launch();
    } catch (_) {
      await Clipboard.setData(ClipboardData(text: normalizedPhone));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final liveBusinessAsync = ref.watch(businessByIdProvider(business.id));
    final currentBusiness = liveBusinessAsync.asData?.value ?? business;
    final ownerAsync = ref.watch(userProfileProvider(currentBusiness.ownerId));
    final ownerPhone = ownerAsync.asData?.value?.phoneNumber?.trim() ?? '';
    final businessPhone = (currentBusiness.phone ?? '').trim();
    final ownerPhoneSnapshot = (currentBusiness.ownerPhone ?? '').trim();
    final resolvedPhone = businessPhone.isNotEmpty
        ? businessPhone
        : ownerPhoneSnapshot.isNotEmpty
        ? ownerPhoneSnapshot
        : ownerPhone;
    final contactLabel = businessPhone.isNotEmpty
        ? 'Contact'
        : ownerPhoneSnapshot.isNotEmpty || ownerPhone.isNotEmpty
        ? 'Owner Contact'
        : null;

    return Scaffold(
      appBar: AppBar(title: const Text('Business Public Profile')),
      body: SafeArea(
        top: false,
        child: ListView(
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
                          backgroundImage:
                              (currentBusiness.logoUrl ?? '').isNotEmpty
                              ? NetworkImage(currentBusiness.logoUrl!)
                              : null,
                          child: (currentBusiness.logoUrl ?? '').isEmpty
                              ? const Icon(Icons.store, size: 30)
                              : null,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                currentBusiness.name,
                                style: Theme.of(
                                  context,
                                ).textTheme.headlineSmall,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${currentBusiness.category} • ${currentBusiness.city}',
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if ((currentBusiness.description ?? '')
                        .trim()
                        .isNotEmpty) ...[
                      Text(
                        currentBusiness.description!.trim(),
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                      const SizedBox(height: 12),
                    ],
                    if ((currentBusiness.address ?? '').trim().isNotEmpty) ...[
                      Text('Address: ${currentBusiness.address!.trim()}'),
                      const SizedBox(height: 8),
                    ],
                    if (currentBusiness.city.trim().isNotEmpty) ...[
                      Text('City: ${currentBusiness.city.trim()}'),
                      const SizedBox(height: 8),
                    ],
                    if (resolvedPhone.isNotEmpty && contactLabel != null) ...[
                      Text('$contactLabel: $resolvedPhone'),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: () => _callBusiness(context, resolvedPhone),
                        icon: const Icon(Icons.call_outlined),
                        label: const Text('Call Now'),
                      ),
                      const SizedBox(height: 8),
                    ],
                    if ((currentBusiness.gstNumber ?? '')
                        .trim()
                        .isNotEmpty) ...[
                      Text(
                        'Tax Registration Number: ${currentBusiness.gstNumber!.trim()}',
                      ),
                      const SizedBox(height: 8),
                    ],
                    if ((currentBusiness.shareLink ?? '')
                        .trim()
                        .isNotEmpty) ...[
                      Text(
                        'Business Link: ${_displayBusinessLinkText(rawLink: currentBusiness.shareLink!, businessName: currentBusiness.name)}',
                      ),
                      const SizedBox(height: 8),
                    ],
                    // Hidden as requested: Deep-link UI block for Business Public Profile.
                    // Uncomment below if you want to show deep link text and copy button again.
                    // Text('Deep Link: ${businessDeepLink(currentBusiness.id)}'),
                    // const SizedBox(height: 8),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        // Hidden as requested: Uncomment to restore deep-link copy action.
                        // OutlinedButton.icon(
                        //   onPressed: () => _copyText(
                        //     context,
                        //     'Deep link',
                        //     businessDeepLink(currentBusiness.id),
                        //   ),
                        //   icon: const Icon(Icons.link),
                        //   label: const Text('Copy Deep Link'),
                        // ),
                        OutlinedButton.icon(
                          onPressed:
                              (currentBusiness.shareLink ?? '').trim().isEmpty
                              ? null
                              : () => _copyText(
                                  context,
                                  'Business link',
                                  currentBusiness.shareLink!.trim(),
                                ),
                          icon: const Icon(Icons.copy),
                          label: const Text('Copy Business Link'),
                        ),
                        OutlinedButton.icon(
                          onPressed: () => _copyText(
                            context,
                            'Share text',
                            _buildShareMessage(
                              businessId: currentBusiness.id,
                              businessName: currentBusiness.name,
                              category: currentBusiness.category,
                              city: currentBusiness.city,
                              businessLink: currentBusiness.shareLink,
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
      ),
    );
  }
}
