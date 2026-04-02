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
    this.subscriptionActive = false,
    this.subscriptionStartDate,
    this.subscriptionEndDate,
    this.description,
    this.phone,
    this.ownerPhone,
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
  final bool subscriptionActive;
  final DateTime? subscriptionStartDate;
  final DateTime? subscriptionEndDate;
  final String? description;
  final String? phone;
  final String? ownerPhone;
  final String? gstNumber;
  final String? logoUrl;
  final String? shareLink;
  final DateTime? createdAt;

  bool hasActiveSubscriptionAt(DateTime now) {
    if (!subscriptionActive) return false;
    if (subscriptionStartDate != null && now.isBefore(subscriptionStartDate!)) {
      return false;
    }
    if (subscriptionEndDate != null && now.isAfter(subscriptionEndDate!)) {
      return false;
    }
    return true;
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'category': category,
      'ownerId': ownerId,
      'city': city,
      'address': address,
      'status': enumToString(status),
      'subscriptionActive': subscriptionActive,
      'subscriptionStartDate': subscriptionStartDate == null
          ? null
          : Timestamp.fromDate(subscriptionStartDate!),
      'subscriptionEndDate': subscriptionEndDate == null
          ? null
          : Timestamp.fromDate(subscriptionEndDate!),
      'description': description,
      'phone': phone,
      'ownerPhone': ownerPhone,
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
      subscriptionActive: (data['subscriptionActive'] as bool?) ?? false,
      subscriptionStartDate: (data['subscriptionStartDate'] as Timestamp?)
          ?.toDate(),
      subscriptionEndDate: (data['subscriptionEndDate'] as Timestamp?)
          ?.toDate(),
      description: data['description'] as String?,
      phone: data['phone'] as String?,
      ownerPhone: data['ownerPhone'] as String?,
      gstNumber: data['gstNumber'] as String?,
      logoUrl: data['logoUrl'] as String?,
      shareLink: data['shareLink'] as String?,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }
}
