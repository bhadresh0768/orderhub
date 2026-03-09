import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  static final Uri _privacyPolicyUri = Uri.parse(
    'https://creativemindapp.blogspot.com/2026/03/privacy-policy.html',
  );
  static final Uri _termsUri = Uri.parse(
    'https://creativemindapp.blogspot.com/2026/03/terms-conditions.html',
  );
  static final Uri _deletionUri = Uri.parse(
    'https://creativemindapp.blogspot.com/2026/03/data-deletion-policy.html',
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
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Privacy Policy')),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.privacy_tip_outlined),
            title: const Text('Privacy Policy'),
            subtitle: const Text(
              'https://creativemindapp.blogspot.com/2026/03/privacy-policy.html',
            ),
            onTap: () => _openExternal(context, _privacyPolicyUri),
          ),
          ListTile(
            leading: const Icon(Icons.rule_outlined),
            title: const Text('Terms & Conditions'),
            subtitle: const Text(
              'https://creativemindapp.blogspot.com/2026/03/terms-conditions.html',
            ),
            onTap: () => _openExternal(context, _termsUri),
          ),
          ListTile(
            leading: const Icon(Icons.delete_outline),
            title: const Text('Data Deletion Policy'),
            subtitle: const Text(
              'https://creativemindapp.blogspot.com/2026/03/data-deletion-policy.html',
            ),
            onTap: () => _openExternal(context, _deletionUri),
          ),
        ],
      ),
    );
  }
}
