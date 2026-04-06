import 'package:cloud_firestore/cloud_firestore.dart';

class QuoteCustomer {
  const QuoteCustomer({
    required this.id,
    required this.businessId,
    required this.name,
    this.contactName,
    this.phone,
    this.email,
    this.address,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String businessId;
  final String name;
  final String? contactName;
  final String? phone;
  final String? email;
  final String? address;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Map<String, dynamic> toMap() {
    return {
      'businessId': businessId,
      'name': name,
      'contactName': contactName,
      'phone': phone,
      'email': email,
      'address': address,
      'createdAt': Timestamp.fromDate(createdAt ?? DateTime.now()),
      'updatedAt': Timestamp.fromDate(updatedAt ?? DateTime.now()),
    };
  }

  factory QuoteCustomer.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    if (data == null) {
      throw StateError('Quote customer document is empty');
    }
    return QuoteCustomer(
      id: doc.id,
      businessId: (data['businessId'] as String?) ?? '',
      name: (data['name'] as String?) ?? '',
      contactName: data['contactName'] as String?,
      phone: data['phone'] as String?,
      email: data['email'] as String?,
      address: data['address'] as String?,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }
}
