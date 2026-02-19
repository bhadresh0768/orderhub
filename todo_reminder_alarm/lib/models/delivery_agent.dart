import 'package:cloud_firestore/cloud_firestore.dart';

class DeliveryAgent {
  const DeliveryAgent({
    required this.id,
    required this.businessId,
    required this.name,
    required this.phone,
    this.isActive = true,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String businessId;
  final String name;
  final String phone;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Map<String, dynamic> toMap() {
    return {
      'businessId': businessId,
      'name': name,
      'phone': phone,
      'isActive': isActive,
      'createdAt': Timestamp.fromDate(createdAt ?? DateTime.now()),
      'updatedAt': Timestamp.fromDate(updatedAt ?? DateTime.now()),
    };
  }

  factory DeliveryAgent.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    if (data == null) {
      throw StateError('Delivery agent document is empty');
    }
    return DeliveryAgent(
      id: doc.id,
      businessId: (data['businessId'] as String?) ?? '',
      name: (data['name'] as String?) ?? '',
      phone: (data['phone'] as String?) ?? '',
      isActive: (data['isActive'] as bool?) ?? true,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }
}
