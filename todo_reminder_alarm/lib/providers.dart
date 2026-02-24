import 'package:cloud_firestore/cloud_firestore.dart' hide Order;
import 'package:app_links/app_links.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'models/app_user.dart';
import 'models/business.dart';
import 'models/catalog.dart';
import 'models/delivery_agent.dart';
import 'models/order.dart';
import 'services/auth_service.dart';
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
      .map((results) => results.any((result) => result != ConnectivityResult.none))
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

final catalogCategoriesProvider =
    StreamProvider.family<List<CatalogCategory>, String>((ref, businessId) {
      return ref
          .read(firestoreServiceProvider)
          .catalogCategoriesStream(businessId);
    });

final catalogProductsProvider =
    StreamProvider.family<List<CatalogProduct>, String>((ref, businessId) {
      return ref.read(firestoreServiceProvider).catalogProductsStream(businessId);
    });

final catalogVariantsProvider =
    StreamProvider.family<List<CatalogVariant>, String>((ref, productId) {
      return ref.read(firestoreServiceProvider).catalogVariantsStream(productId);
    });

final allOrdersProvider = StreamProvider<List<Order>>((ref) {
  return ref.read(firestoreServiceProvider).allOrdersStream();
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
