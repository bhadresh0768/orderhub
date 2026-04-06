import 'package:cloud_firestore/cloud_firestore.dart' hide Order;
import 'package:app_links/app_links.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'models/app_user.dart';
import 'models/app_update_config.dart';
import 'models/business.dart';
import 'models/catalog.dart';
import 'models/contact_us_message.dart';
import 'models/delivery_agent.dart';
import 'models/delivery_address.dart';
import 'models/order.dart';
import 'models/quote.dart';
import 'models/quote_customer.dart';
import 'models/subscription_renewal_request.dart';
import 'models/support_ticket.dart';
import 'services/auth_service.dart';
import 'services/ad_consent_service.dart';
import 'services/deep_link_service.dart';
import 'services/firestore_service.dart';
import 'services/item_catalog_service.dart';
import 'services/notification_service.dart';
import 'services/push_notification_service.dart';
import 'services/storage_service.dart';

class ThemeModeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() => ThemeMode.light;

  void setThemeMode(ThemeMode mode) {
    state = mode;
  }
}

final themeModeProvider = NotifierProvider<ThemeModeNotifier, ThemeMode>(
  ThemeModeNotifier.new,
);

final firebaseAuthProvider = Provider<FirebaseAuth>(
  (ref) => FirebaseAuth.instance,
);
final firestoreProvider = Provider<FirebaseFirestore>(
  (ref) => FirebaseFirestore.instance,
);
final firebaseStorageProvider = Provider<FirebaseStorage>(
  (ref) => FirebaseStorage.instance,
);
final firebaseMessagingProvider = Provider<FirebaseMessaging>(
  (ref) => FirebaseMessaging.instance,
);
final appLinksProvider = Provider<AppLinks>((ref) => AppLinks());
final connectivityProvider = Provider<Connectivity>((ref) => Connectivity());
final adConsentProvider = NotifierProvider<AdConsentController, AdConsentState>(
  AdConsentController.new,
);

final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService(ref.read(firebaseAuthProvider));
});

final firestoreServiceProvider = Provider<FirestoreService>((ref) {
  return FirestoreService(ref.read(firestoreProvider));
});

final storageServiceProvider = Provider<StorageService>((ref) {
  return StorageService(ref.read(firebaseStorageProvider));
});

final itemCatalogServiceProvider = Provider<ItemCatalogService>((ref) {
  return ItemCatalogService(ref.read(firestoreProvider));
});

final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService();
});

final pushNotificationServiceProvider = Provider<PushNotificationService>((
  ref,
) {
  return PushNotificationService(
    ref.read(firebaseMessagingProvider),
    ref.read(firestoreServiceProvider),
    ref.read(notificationServiceProvider),
  );
});

final deepLinkServiceProvider = Provider<DeepLinkService>((ref) {
  final service = DeepLinkService(ref.read(appLinksProvider));
  ref.onDispose(service.dispose);
  return service;
});

final authStateProvider = StreamProvider<User?>((ref) {
  return ref.read(authServiceProvider).authStateChanges();
});

final internetConnectedProvider = StreamProvider<bool>((ref) async* {
  final connectivity = ref.read(connectivityProvider);
  final initial = await connectivity.checkConnectivity();
  yield initial.any((result) => result != ConnectivityResult.none);
  yield* connectivity.onConnectivityChanged
      .map(
        (results) => results.any((result) => result != ConnectivityResult.none),
      )
      .distinct();
});

final userProfileProvider = StreamProvider.family<AppUser?, String>((ref, uid) {
  return ref.read(firestoreServiceProvider).userStream(uid);
});

final allUsersProvider = StreamProvider<List<AppUser>>((ref) {
  return ref.read(firestoreServiceProvider).allUsersStream();
});

final businessesProvider = StreamProvider<List<BusinessProfile>>((ref) {
  return ref.read(firestoreServiceProvider).businessesStream();
});

final approvedBusinessesProvider = StreamProvider<List<BusinessProfile>>((ref) {
  return ref
      .read(firestoreServiceProvider)
      .businessesStream(onlyApproved: true);
});

final businessByIdProvider = StreamProvider.family<BusinessProfile?, String>((
  ref,
  businessId,
) {
  return ref.read(firestoreServiceProvider).businessStream(businessId);
});

final ordersForBusinessProvider = StreamProvider.family<List<Order>, String>((
  ref,
  businessId,
) {
  return ref.read(firestoreServiceProvider).ordersForBusinessStream(businessId);
});

final ordersForCustomerProvider = StreamProvider.family<List<Order>, String>((
  ref,
  customerId,
) {
  return ref.read(firestoreServiceProvider).ordersForCustomerStream(customerId);
});

final ordersPlacedByBusinessOwnerProvider =
    StreamProvider.family<List<Order>, String>((ref, ownerId) {
      return ref
          .read(firestoreServiceProvider)
          .ordersPlacedByBusinessOwnerStream(ownerId);
    });

final ordersForDeliveryAgentByPhoneProvider =
    StreamProvider.family<List<Order>, String>((ref, phone) {
      return ref
          .read(firestoreServiceProvider)
          .ordersForDeliveryAgentByPhoneStream(phone);
    });

final orderByIdProvider = StreamProvider.family<Order?, String>((ref, orderId) {
  return ref.read(firestoreServiceProvider).orderStream(orderId);
});

final catalogCategoriesProvider =
    StreamProvider.family<List<CatalogCategory>, String>((ref, businessId) {
      return ref
          .read(firestoreServiceProvider)
          .catalogCategoriesStream(businessId);
    });

final catalogProductsProvider =
    StreamProvider.family<List<CatalogProduct>, String>((ref, businessId) {
      return ref
          .read(firestoreServiceProvider)
          .catalogProductsStream(businessId);
    });

final catalogVariantsProvider =
    StreamProvider.family<List<CatalogVariant>, String>((ref, productId) {
      return ref
          .read(firestoreServiceProvider)
          .catalogVariantsStream(productId);
    });

final allOrdersProvider = StreamProvider<List<Order>>((ref) {
  return ref.read(firestoreServiceProvider).allOrdersStream();
});

final quotesForBusinessProvider = StreamProvider.family<List<Quote>, String>((
  ref,
  businessId,
) {
  return ref.read(firestoreServiceProvider).quotesForBusinessStream(businessId);
});

final quoteCustomersForBusinessProvider =
    StreamProvider.family<List<QuoteCustomer>, String>((ref, businessId) {
      return ref
          .read(firestoreServiceProvider)
          .quoteCustomersForBusinessStream(businessId);
    });

final supportTicketsForUserProvider =
    StreamProvider.family<List<SupportTicket>, String>((ref, userId) {
      return ref
          .read(firestoreServiceProvider)
          .supportTicketsForUserStream(userId);
    });

final allSupportTicketsProvider = StreamProvider<List<SupportTicket>>((ref) {
  return ref.read(firestoreServiceProvider).allSupportTicketsStream();
});

final allContactUsProvider = StreamProvider<List<ContactUsMessage>>((ref) {
  return ref.read(firestoreServiceProvider).allContactUsStream();
});

final subscriptionRenewalRequestsProvider =
    StreamProvider<List<SubscriptionRenewalRequest>>((ref) {
      return ref
          .read(firestoreServiceProvider)
          .subscriptionRenewalRequestsStream();
    });

final appUpdateConfigProvider = StreamProvider<AppUpdateConfig?>((ref) {
  return ref.read(firestoreServiceProvider).appUpdateConfigStream();
});

final showAdsProvider = Provider<bool>((ref) {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return false;

  final config = ref.watch(appUpdateConfigProvider).value;
  if (config == null) return false;

  final profile = ref.watch(userProfileProvider(user.uid)).value;
  if (profile == null) return false;

  final businessId = profile.businessId;
  if (businessId != null) {
    final business = ref.watch(businessByIdProvider(businessId)).value;
    if (business?.hasActiveSubscriptionAt(DateTime.now()) ?? false) {
      return false;
    }
  }

  switch (profile.role.name) {
    case 'admin':
      return config.showAdsAdmin;
    case 'businessOwner':
      return config.showAdsBusiness;
    case 'customer':
      return config.showAdsCustomer;
    case 'deliveryBoy':
      return config.showAdsDelivery;
    default:
      return false;
  }
});

final appVersionProvider = FutureProvider<String>((ref) async {
  final packageInfo = await PackageInfo.fromPlatform();
  return packageInfo.version.trim();
});

final deliveryAgentsForBusinessProvider =
    StreamProvider.family<List<DeliveryAgent>, String>((ref, businessId) {
      return ref
          .read(firestoreServiceProvider)
          .deliveryAgentsForBusinessStream(businessId);
    });

final allDeliveryAgentsProvider = StreamProvider<List<DeliveryAgent>>((ref) {
  return ref.read(firestoreServiceProvider).allDeliveryAgentsStream();
});

final deliveryAddressesProvider =
    StreamProvider.family<List<DeliveryAddressEntry>, String>((ref, userId) {
      return ref
          .read(firestoreServiceProvider)
          .deliveryAddressesForUserStream(userId);
    });
