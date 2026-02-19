import 'package:cloud_firestore/cloud_firestore.dart';

import 'enums.dart';

class BusinessProfile {
  const BusinessProfile({
    required this.id,
    required this.name,
    required this.category,
    required this.ownerId,
    required this.city,
    this.address,
    this.status = BusinessStatus.pending,
    this.description,
    this.phone,
    this.gstNumber,
    this.logoUrl,
    this.shareLink,
    this.createdAt,
  });

  final String id;
  final String name;
  final String category;
  final String ownerId;
  final String city;
  final String? address;
  final BusinessStatus status;
  final String? description;
  final String? phone;
  final String? gstNumber;
  final String? logoUrl;
  final String? shareLink;
  final DateTime? createdAt;

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'category': category,
      'ownerId': ownerId,
      'city': city,
      'address': address,
      'status': enumToString(status),
      'description': description,
      'phone': phone,
      'gstNumber': gstNumber,
      'logoUrl': logoUrl,
      'shareLink': shareLink,
      'createdAt': Timestamp.fromDate(createdAt ?? DateTime.now()),
    };
  }

  factory BusinessProfile.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    if (data == null) {
      throw StateError('Business document is empty');
    }
    return BusinessProfile(
      id: doc.id,
      name: (data['name'] as String?) ?? '',
      category: (data['category'] as String?) ?? '',
      ownerId: (data['ownerId'] as String?) ?? '',
      city: (data['city'] as String?) ?? '',
      address: data['address'] as String?,
      status: enumFromString(
        BusinessStatus.values,
        data['status'] as String?,
        BusinessStatus.pending,
      ),
      description: data['description'] as String?,
      phone: data['phone'] as String?,
      gstNumber: data['gstNumber'] as String?,
      logoUrl: data['logoUrl'] as String?,
      shareLink: data['shareLink'] as String?,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }
}
