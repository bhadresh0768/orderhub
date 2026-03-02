import 'package:cloud_firestore/cloud_firestore.dart' hide Order;

import '../models/app_user.dart';
import '../models/business.dart';
import '../models/catalog.dart';
import '../models/delivery_agent.dart';
import '../models/delivery_address.dart';
import '../models/enums.dart';
import '../models/order.dart';
import '../models/support_ticket.dart';

class FirestoreService {
  FirestoreService(this._db);

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _users =>
      _db.collection('users');
  CollectionReference<Map<String, dynamic>> get _businesses =>
      _db.collection('businesses');
  CollectionReference<Map<String, dynamic>> get _orders =>
      _db.collection('orders');
  CollectionReference<Map<String, dynamic>> get _deliveryAgents =>
      _db.collection('deliveryAgents');
  CollectionReference<Map<String, dynamic>> get _deliveryAddresses =>
      _db.collection('deliveryAddresses');
  CollectionReference<Map<String, dynamic>> get _orderCounters =>
      _db.collection('orderCounters');
  CollectionReference<Map<String, dynamic>> get _catalogCategories =>
      _db.collection('catalogCategories');
  CollectionReference<Map<String, dynamic>> get _catalogProducts =>
      _db.collection('catalogProducts');
  CollectionReference<Map<String, dynamic>> get _catalogVariants =>
      _db.collection('catalogVariants');
  CollectionReference<Map<String, dynamic>> get _supportTickets =>
      _db.collection('supportTickets');

  Stream<AppUser?> userStream(String uid) {
    return _users.doc(uid).snapshots().map((doc) {
      if (!doc.exists) return null;
      return AppUser.fromDoc(doc);
    });
  }

  Stream<List<AppUser>> allUsersStream() {
    return _users
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map(AppUser.fromDoc).toList());
  }

  Future<void> createUserProfile(AppUser user) async {
    await _users.doc(user.id).set(user.toMap(), SetOptions(merge: true));
  }

  Stream<List<BusinessProfile>> businessesStream({bool onlyApproved = false}) {
    final query = onlyApproved
        ? _businesses.where(
            'status',
            isEqualTo: enumToString(BusinessStatus.approved),
          )
        : _businesses;
    return query
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map(BusinessProfile.fromDoc).toList());
  }

  Stream<List<DeliveryAgent>> allDeliveryAgentsStream() {
    return _deliveryAgents.snapshots().map((snapshot) {
      final items = snapshot.docs.map(DeliveryAgent.fromDoc).toList();
      items.sort(
        (a, b) => b.createdAt?.compareTo(a.createdAt ?? DateTime(0)) ?? 0,
      );
      return items;
    });
  }

  Stream<BusinessProfile?> businessStream(String businessId) {
    return _businesses.doc(businessId).snapshots().map((doc) {
      if (!doc.exists) return null;
      return BusinessProfile.fromDoc(doc);
    });
  }

  Future<void> createBusiness(BusinessProfile profile) async {
    await _businesses
        .doc(profile.id)
        .set(profile.toMap(), SetOptions(merge: true));
  }

  Stream<List<Order>> ordersForBusinessStream(String businessId) {
    return _orders
        .where('businessId', isEqualTo: businessId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map(Order.fromDoc).toList());
  }

  Stream<List<Order>> ordersForCustomerStream(String customerId) {
    return _orders
        .where('customerId', isEqualTo: customerId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map(Order.fromDoc).toList());
  }

  Stream<List<Order>> ordersPlacedByBusinessOwnerStream(String ownerId) {
    return _orders
        .where('customerId', isEqualTo: ownerId)
        .where('requesterType', isEqualTo: 'businessOwner')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map(Order.fromDoc).toList());
  }

  Stream<List<Order>> allOrdersStream() {
    return _orders
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map(Order.fromDoc).toList());
  }

  Stream<List<SupportTicket>> supportTicketsForUserStream(String userId) {
    return _supportTickets
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map(SupportTicket.fromDoc).toList());
  }

  Stream<List<SupportTicket>> allSupportTicketsStream() {
    return _supportTickets
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map(SupportTicket.fromDoc).toList());
  }

  Stream<List<Order>> ordersForDeliveryAgentByPhoneStream(String phone) {
    return _orders
        .where('assignedDeliveryAgentPhone', isEqualTo: phone)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map(Order.fromDoc).toList());
  }

  Stream<Order?> orderStream(String orderId) {
    return _orders.doc(orderId).snapshots().map((doc) {
      if (!doc.exists) return null;
      return Order.fromDoc(doc);
    });
  }

  Future<BusinessProfile?> getBusinessById(String businessId) async {
    final doc = await _businesses.doc(businessId).get();
    if (!doc.exists) return null;
    return BusinessProfile.fromDoc(doc);
  }

  Future<void> createOrder(Order order) async {
    final counterRef = _orderCounters.doc(order.businessId);
    final orderRef = _orders.doc(order.id);
    final businessRef = _businesses.doc(order.businessId);

    await _db.runTransaction((txn) async {
      final counterSnapshot = await txn.get(counterRef);
      int currentCounter = 0;
      if (counterSnapshot.exists) {
        final counterData = counterSnapshot.data();
        final raw = counterData?['value'];
        if (raw is num) {
          currentCounter = raw.toInt();
        }
      } else {
        final businessSnapshot = await txn.get(businessRef);
        final businessData = businessSnapshot.data();
        final raw = businessData?['orderCounter'];
        if (raw is num) {
          currentCounter = raw.toInt();
        }
      }
      final nextCounter = currentCounter + 1;

      txn.set(orderRef, {
        ...order.toMap(),
        'orderNumber': nextCounter.toString(),
      }, SetOptions(merge: true));
      txn.set(counterRef, {
        'businessId': order.businessId,
        'value': nextCounter,
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      }, SetOptions(merge: true));
    });
  }

  Future<void> updateOrder(String orderId, Map<String, dynamic> data) async {
    await _orders.doc(orderId).update({
      ...data,
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    });
  }

  Stream<List<DeliveryAgent>> deliveryAgentsForBusinessStream(
    String businessId,
  ) {
    return _deliveryAgents
        .where('businessId', isEqualTo: businessId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map(DeliveryAgent.fromDoc).toList());
  }

  Stream<List<DeliveryAddressEntry>> deliveryAddressesForUserStream(
    String userId,
  ) {
    return _deliveryAddresses
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) {
          final items = snapshot.docs.map(DeliveryAddressEntry.fromDoc).toList();
          items.sort((a, b) {
            if (a.isDefault != b.isDefault) {
              return a.isDefault ? -1 : 1;
            }
            final aTime = a.updatedAt ?? DateTime(0);
            final bTime = b.updatedAt ?? DateTime(0);
            return bTime.compareTo(aTime);
          });
          return items;
        });
  }

  Stream<List<CatalogCategory>> catalogCategoriesStream(String businessId) {
    return _catalogCategories
        .where('businessId', isEqualTo: businessId)
        .orderBy('sortOrder')
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map(CatalogCategory.fromDoc).toList(),
        );
  }

  Stream<List<CatalogProduct>> catalogProductsStream(String businessId) {
    return _catalogProducts
        .where('businessId', isEqualTo: businessId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs.map(CatalogProduct.fromDoc).toList(),
        );
  }

  Stream<List<CatalogVariant>> catalogVariantsStream(String productId) {
    return _catalogVariants
        .where('productId', isEqualTo: productId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs.map(CatalogVariant.fromDoc).toList(),
        );
  }

  Future<void> createCatalogCategory(CatalogCategory category) async {
    await _catalogCategories.doc(category.id).set(
          category.toMap(),
          SetOptions(merge: true),
        );
  }

  Future<void> updateCatalogCategory(
    String categoryId,
    Map<String, dynamic> data,
  ) async {
    await _catalogCategories.doc(categoryId).update({
      ...data,
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    });
  }

  Future<void> deleteCatalogCategory(String categoryId) async {
    await _catalogCategories.doc(categoryId).delete();
  }

  Future<void> createCatalogProduct(CatalogProduct product) async {
    await _catalogProducts.doc(product.id).set(
          product.toMap(),
          SetOptions(merge: true),
        );
  }

  Future<void> updateCatalogProduct(
    String productId,
    Map<String, dynamic> data,
  ) async {
    await _catalogProducts.doc(productId).update({
      ...data,
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    });
  }

  Future<void> deleteCatalogProduct(String productId) async {
    await _catalogProducts.doc(productId).delete();
  }

  Future<void> createCatalogVariant(CatalogVariant variant) async {
    await _catalogVariants.doc(variant.id).set(
          variant.toMap(),
          SetOptions(merge: true),
        );
  }

  Future<void> updateCatalogVariant(
    String variantId,
    Map<String, dynamic> data,
  ) async {
    await _catalogVariants.doc(variantId).update({
      ...data,
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    });
  }

  Future<void> deleteCatalogVariant(String variantId) async {
    await _catalogVariants.doc(variantId).delete();
  }

  Future<void> createDeliveryAgent(DeliveryAgent agent) async {
    await _deliveryAgents
        .doc(agent.id)
        .set(agent.toMap(), SetOptions(merge: true));
  }

  Future<void> createDeliveryAddress(DeliveryAddressEntry address) async {
    final batch = _db.batch();
    if (address.isDefault) {
      final existing = await _deliveryAddresses
          .where('userId', isEqualTo: address.userId)
          .where('isDefault', isEqualTo: true)
          .get();
      for (final doc in existing.docs) {
        if (doc.id == address.id) continue;
        batch.update(doc.reference, {
          'isDefault': false,
          'updatedAt': Timestamp.fromDate(DateTime.now()),
        });
      }
    }
    batch.set(
      _deliveryAddresses.doc(address.id),
      address.toMap(),
      SetOptions(merge: true),
    );
    await batch.commit();
  }

  Future<void> updateDeliveryAddress(
    String addressId,
    DeliveryAddressEntry address,
  ) async {
    final batch = _db.batch();
    if (address.isDefault) {
      final existing = await _deliveryAddresses
          .where('userId', isEqualTo: address.userId)
          .where('isDefault', isEqualTo: true)
          .get();
      for (final doc in existing.docs) {
        if (doc.id == addressId) continue;
        batch.update(doc.reference, {
          'isDefault': false,
          'updatedAt': Timestamp.fromDate(DateTime.now()),
        });
      }
    }
    batch.update(_deliveryAddresses.doc(addressId), {
      ...address.toMap(),
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    });
    await batch.commit();
  }

  Future<void> deleteDeliveryAddress(String addressId) async {
    await _deliveryAddresses.doc(addressId).delete();
  }

  Future<void> updateDeliveryAgent(
    String agentId,
    Map<String, dynamic> data,
  ) async {
    await _deliveryAgents.doc(agentId).update({
      ...data,
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    });
  }

  Future<void> assignOrderDeliveryAgent({
    required String orderId,
    String? agentId,
    String? agentName,
    String? agentPhone,
  }) async {
    await _orders.doc(orderId).update({
      'assignedDeliveryAgentId': agentId,
      'assignedDeliveryAgentName': agentName,
      'assignedDeliveryAgentPhone': agentPhone,
      'assignedDeliveryAt': agentId == null
          ? null
          : Timestamp.fromDate(DateTime.now()),
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    });
  }

  Future<DeliveryAgent?> findActiveDeliveryAgentByPhone(String phone) async {
    final normalized = phone.trim();
    if (normalized.isEmpty) return null;
    final snapshot = await _deliveryAgents
        .where('phone', isEqualTo: normalized)
        .where('isActive', isEqualTo: true)
        .limit(1)
        .get();
    if (snapshot.docs.isEmpty) return null;
    return DeliveryAgent.fromDoc(snapshot.docs.first);
  }

  Future<void> updateUser(String uid, Map<String, dynamic> data) async {
    await _users.doc(uid).update({
      ...data,
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    });
  }

  Future<void> addFcmToken(String uid, String token) async {
    await _users.doc(uid).set({
      'fcmTokens': FieldValue.arrayUnion([token]),
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    }, SetOptions(merge: true));
  }

  Future<void> updateBusiness(
    String businessId,
    Map<String, dynamic> data,
  ) async {
    await _businesses.doc(businessId).update({
      ...data,
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    });
  }

  Future<void> deleteBusiness(String businessId) async {
    await _businesses.doc(businessId).delete();
  }

  Future<void> deleteOrder(String orderId) async {
    await _orders.doc(orderId).delete();
  }

  Future<void> createSupportTicket(SupportTicket ticket) async {
    await _supportTickets.doc(ticket.id).set(
      ticket.toMap(),
      SetOptions(merge: true),
    );
  }

  Future<void> updateSupportTicket(
    String ticketId,
    Map<String, dynamic> data,
  ) async {
    await _supportTickets.doc(ticketId).update({
      ...data,
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    });
  }

  Future<void> deleteUser(String uid) async {
    await _users.doc(uid).delete();
  }

  Future<void> deleteDeliveryAgent(String agentId) async {
    await _deliveryAgents.doc(agentId).delete();
  }
}
