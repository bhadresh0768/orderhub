import 'package:cloud_firestore/cloud_firestore.dart';

class SubscriptionRenewalRequest {
  const SubscriptionRenewalRequest({
    required this.id,
    required this.businessId,
    required this.businessName,
    required this.ownerId,
    required this.ownerName,
    required this.status,
    this.ownerEmail,
    this.ownerPhone,
    this.businessCity,
    this.subscriptionEndDate,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String businessId;
  final String businessName;
  final String ownerId;
  final String ownerName;
  final String status;
  final String? ownerEmail;
  final String? ownerPhone;
  final String? businessCity;
  final DateTime? subscriptionEndDate;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Map<String, dynamic> toMap() {
    return {
      'businessId': businessId,
      'businessName': businessName,
      'ownerId': ownerId,
      'ownerName': ownerName,
      'ownerEmail': ownerEmail,
      'ownerPhone': ownerPhone,
      'businessCity': businessCity,
      'status': status,
      'subscriptionEndDate': subscriptionEndDate == null
          ? null
          : Timestamp.fromDate(subscriptionEndDate!),
      'createdAt': Timestamp.fromDate(createdAt ?? DateTime.now()),
      'updatedAt': Timestamp.fromDate(updatedAt ?? DateTime.now()),
    };
  }

  factory SubscriptionRenewalRequest.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    if (data == null) {
      throw StateError('Subscription renewal request document is empty');
    }
    return SubscriptionRenewalRequest(
      id: doc.id,
      businessId: (data['businessId'] as String?) ?? doc.id,
      businessName: (data['businessName'] as String?) ?? '',
      ownerId: (data['ownerId'] as String?) ?? '',
      ownerName: (data['ownerName'] as String?) ?? '',
      ownerEmail: data['ownerEmail'] as String?,
      ownerPhone: data['ownerPhone'] as String?,
      businessCity: data['businessCity'] as String?,
      status: (data['status'] as String?) ?? 'pending',
      subscriptionEndDate: (data['subscriptionEndDate'] as Timestamp?)
          ?.toDate(),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }
}
