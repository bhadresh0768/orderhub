import 'package:android_intent_plus/android_intent.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

class ContactActions {
  static String _digitsOnly(String value) {
    return value.replaceAll(RegExp(r'[^0-9]'), '');
  }

  static Future<void> callPhone(BuildContext context, String phone) async {
    final normalized = phone.trim();
    if (normalized.isEmpty) return;

    final uri = Uri(scheme: 'tel', path: normalized);
    try {
      final launched = await launchUrl(uri);
      if (launched) return;
    } catch (_) {}

    try {
      final intent = AndroidIntent(
        action: 'android.intent.action.DIAL',
        data: 'tel:$normalized',
      );
      await intent.launch();
      return;
    } catch (_) {}

    await Clipboard.setData(ClipboardData(text: normalized));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Call unavailable. Number copied to clipboard.'),
      ),
    );
  }

  static Future<void> openWhatsApp(BuildContext context, String phone) async {
    final normalized = phone.trim();
    final digits = _digitsOnly(normalized);
    if (digits.isEmpty) return;

    final uri = Uri.parse('https://wa.me/$digits');
    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (launched) return;
    } catch (_) {}

    try {
      final intent = AndroidIntent(
        action: 'android.intent.action.VIEW',
        data: uri.toString(),
      );
      await intent.launch();
      return;
    } catch (_) {}

    await Clipboard.setData(ClipboardData(text: normalized));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('WhatsApp unavailable. Number copied to clipboard.'),
      ),
    );
  }
}
