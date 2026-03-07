import 'package:cloud_firestore/cloud_firestore.dart';

class AppUpdateConfig {
  const AppUpdateConfig({
    required this.latestVersion,
    required this.storeUrl,
    this.notes,
    this.enabled = true,
    this.showAds = false,
    this.showAdsAdmin = false,
    this.showAdsBusiness = false,
    this.showAdsCustomer = false,
    this.showAdsDelivery = false,
    this.updatedAt,
  });

  final String latestVersion;
  final String storeUrl;
  final String? notes;
  final bool enabled;
  // Legacy flag (kept for backward compatibility).
  final bool showAds;
  final bool showAdsAdmin;
  final bool showAdsBusiness;
  final bool showAdsCustomer;
  final bool showAdsDelivery;
  final DateTime? updatedAt;

  Map<String, dynamic> toMap() {
    return {
      'latestVersion': latestVersion,
      'storeUrl': storeUrl,
      'notes': notes,
      'enabled': enabled,
      'showAds': showAds,
      'showAdsAdmin': showAdsAdmin,
      'showAdsBusiness': showAdsBusiness,
      'showAdsCustomer': showAdsCustomer,
      'showAdsDelivery': showAdsDelivery,
      'updatedAt': Timestamp.fromDate(updatedAt ?? DateTime.now()),
    };
  }

  factory AppUpdateConfig.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    if (data == null) {
      throw StateError('App update config document is empty');
    }
    final legacyShowAds = (data['showAds'] as bool?) ?? false;
    return AppUpdateConfig(
      latestVersion: (data['latestVersion'] as String?) ?? '',
      storeUrl: (data['storeUrl'] as String?) ?? '',
      notes: data['notes'] as String?,
      enabled: (data['enabled'] as bool?) ?? true,
      showAds: legacyShowAds,
      showAdsAdmin: (data['showAdsAdmin'] as bool?) ?? legacyShowAds,
      showAdsBusiness: (data['showAdsBusiness'] as bool?) ?? legacyShowAds,
      showAdsCustomer: (data['showAdsCustomer'] as bool?) ?? legacyShowAds,
      showAdsDelivery: (data['showAdsDelivery'] as bool?) ?? legacyShowAds,
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }
}
