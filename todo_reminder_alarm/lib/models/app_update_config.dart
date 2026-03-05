import 'package:cloud_firestore/cloud_firestore.dart';

class AppUpdateConfig {
  const AppUpdateConfig({
    required this.latestVersion,
    required this.storeUrl,
    this.notes,
    this.enabled = true,
    this.updatedAt,
  });

  final String latestVersion;
  final String storeUrl;
  final String? notes;
  final bool enabled;
  final DateTime? updatedAt;

  Map<String, dynamic> toMap() {
    return {
      'latestVersion': latestVersion,
      'storeUrl': storeUrl,
      'notes': notes,
      'enabled': enabled,
      'updatedAt': Timestamp.fromDate(updatedAt ?? DateTime.now()),
    };
  }

  factory AppUpdateConfig.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    if (data == null) {
      throw StateError('App update config document is empty');
    }
    return AppUpdateConfig(
      latestVersion: (data['latestVersion'] as String?) ?? '',
      storeUrl: (data['storeUrl'] as String?) ?? '',
      notes: data['notes'] as String?,
      enabled: (data['enabled'] as bool?) ?? true,
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }
}
