import 'package:cloud_firestore/cloud_firestore.dart';

import 'enums.dart';

class PaymentInfo {
  const PaymentInfo({
    required this.status,
    required this.method,
    this.amount,
    this.remark,
    this.confirmedByCustomer,
    this.collectedBy,
    this.collectedByName,
    this.collectedAt,
    this.collectionNote,
    this.updatedAt,
  });

  final PaymentStatus status;
  final PaymentMethod method;
  final double? amount;
  final String? remark;
  final bool? confirmedByCustomer;
  final PaymentCollectedBy? collectedBy;
  final String? collectedByName;
  final DateTime? collectedAt;
  final String? collectionNote;
  final DateTime? updatedAt;

  PaymentInfo copyWith({
    PaymentStatus? status,
    PaymentMethod? method,
    double? amount,
    String? remark,
    bool? confirmedByCustomer,
    PaymentCollectedBy? collectedBy,
    String? collectedByName,
    DateTime? collectedAt,
    String? collectionNote,
    DateTime? updatedAt,
  }) {
    return PaymentInfo(
      status: status ?? this.status,
      method: method ?? this.method,
      amount: amount ?? this.amount,
      remark: remark ?? this.remark,
      confirmedByCustomer: confirmedByCustomer ?? this.confirmedByCustomer,
      collectedBy: collectedBy ?? this.collectedBy,
      collectedByName: collectedByName ?? this.collectedByName,
      collectedAt: collectedAt ?? this.collectedAt,
      collectionNote: collectionNote ?? this.collectionNote,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'status': enumToString(status),
      'method': enumToString(method),
      'amount': amount,
      'remark': remark,
      'confirmedByCustomer': confirmedByCustomer ?? false,
      'collectedBy': collectedBy == null ? null : enumToString(collectedBy!),
      'collectedByName': collectedByName,
      'collectedAt': collectedAt == null ? null : Timestamp.fromDate(collectedAt!),
      'collectionNote': collectionNote,
      'updatedAt': Timestamp.fromDate(updatedAt ?? DateTime.now()),
    };
  }

  factory PaymentInfo.fromMap(Map<String, dynamic> data) {
    final methodRaw = data['method'] as String?;
    final normalizedMethod = methodRaw == 'online'
        ? 'onlineTransfer'
        : methodRaw;
    return PaymentInfo(
      status: enumFromString(
        PaymentStatus.values,
        data['status'] as String?,
        PaymentStatus.pending,
      ),
      method: enumFromString(
        PaymentMethod.values,
        normalizedMethod,
        PaymentMethod.cash,
      ),
      amount: (data['amount'] is num)
          ? (data['amount'] as num).toDouble()
          : null,
      remark: data['remark'] as String?,
      confirmedByCustomer: data['confirmedByCustomer'] as bool?,
      collectedBy: data['collectedBy'] == null
          ? null
          : enumFromString(
              PaymentCollectedBy.values,
              data['collectedBy'] as String?,
              PaymentCollectedBy.businessOwner,
            ),
      collectedByName: data['collectedByName'] as String?,
      collectedAt: (data['collectedAt'] as Timestamp?)?.toDate(),
      collectionNote: data['collectionNote'] as String?,
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }
}
