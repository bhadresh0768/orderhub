import 'package:cloud_firestore/cloud_firestore.dart';

import 'enums.dart';

class BusinessProfile {
  const BusinessProfile({
    required this.id,
    required this.name,
    required this.category,
    required this.ownerId,
    required this.city,
    this.ownerName,
    this.address,
    this.fiscalYearStartMonth,
    this.status = BusinessStatus.approved,
    this.subscriptionActive = false,
    this.subscriptionStartDate,
    this.subscriptionEndDate,
    this.description,
    this.phone,
    this.ownerPhone,
    this.gstNumber,
    this.taxLabel,
    this.logoUrl,
    this.shareLink,
    this.createdAt,
  });

  final String id;
  final String name;
  final String category;
  final String ownerId;
  final String city;
  final String? ownerName;
  final String? address;
  final int? fiscalYearStartMonth;
  final BusinessStatus status;
  final bool subscriptionActive;
  final DateTime? subscriptionStartDate;
  final DateTime? subscriptionEndDate;
  final String? description;
  final String? phone;
  final String? ownerPhone;
  final String? gstNumber;
  final String? taxLabel;
  final String? logoUrl;
  final String? shareLink;
  final DateTime? createdAt;

  int get resolvedFiscalYearStartMonth {
    return (fiscalYearStartMonth ?? 4).clamp(1, 12);
  }

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
      'ownerName': ownerName,
      'address': address,
      'fiscalYearStartMonth': fiscalYearStartMonth,
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
      'taxLabel': taxLabel,
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
      ownerName: data['ownerName'] as String?,
      address: data['address'] as String?,
      fiscalYearStartMonth: (data['fiscalYearStartMonth'] as num?)?.toInt(),
      status: enumFromString(
        BusinessStatus.values,
        data['status'] as String?,
        BusinessStatus.approved,
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
      taxLabel: data['taxLabel'] as String?,
      logoUrl: data['logoUrl'] as String?,
      shareLink: data['shareLink'] as String?,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }
}
