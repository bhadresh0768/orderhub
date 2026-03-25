import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../providers.dart';

class PrivacyPolicyScreen extends ConsumerWidget {
  const PrivacyPolicyScreen({super.key});

  static final Uri _privacyPolicyUri = Uri.parse(
    'https://mvapptools.blogspot.com/2026/03/privacy-policy.html',
  );
  static final Uri _termsUri = Uri.parse(
    'https://mvapptools.blogspot.com/2026/03/terms-conditions.html',
  );
  static final Uri _deletionUri = Uri.parse(
    'https://mvapptools.blogspot.com/2026/03/data-deletion-policy.html',
  );

  Future<void> _openExternal(BuildContext context, Uri uri) async {
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not open ${uri.host}')));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final adConsent = ref.watch(adConsentProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Privacy Policy')),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.privacy_tip_outlined),
            title: const Text('Privacy Policy'),
            subtitle: const Text(
              'https://mvapptools.blogspot.com/2026/03/privacy-policy.html',
            ),
            onTap: () => _openExternal(context, _privacyPolicyUri),
          ),
          ListTile(
            leading: const Icon(Icons.rule_outlined),
            title: const Text('Terms & Conditions'),
            subtitle: const Text(
              'https://mvapptools.blogspot.com/2026/03/terms-conditions.html',
            ),
            onTap: () => _openExternal(context, _termsUri),
          ),
          ListTile(
            leading: const Icon(Icons.delete_outline),
            title: const Text('Data Deletion Policy'),
            subtitle: const Text(
              'https://mvapptools.blogspot.com/2026/03/data-deletion-policy.html',
            ),
            onTap: () => _openExternal(context, _deletionUri),
          ),
          if (adConsent.privacyOptionsRequired)
            ListTile(
              leading: const Icon(Icons.shield_outlined),
              title: const Text('Manage Ad Privacy'),
              subtitle: const Text('Review or update your ad consent choices'),
              onTap: adConsent.initializing
                  ? null
                  : () async {
                      await ref
                          .read(adConsentProvider.notifier)
                          .showPrivacyOptionsForm();
                      final error = ref.read(adConsentProvider).error;
                      if (error != null && context.mounted) {
                        ScaffoldMessenger.of(
                          context,
                        ).showSnackBar(SnackBar(content: Text(error)));
                      }
                    },
            ),
        ],
      ),
    );
  }
}
