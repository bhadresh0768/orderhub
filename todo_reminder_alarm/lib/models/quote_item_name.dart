import 'package:cloud_firestore/cloud_firestore.dart';

class QuoteItemName {
  const QuoteItemName({
    required this.id,
    required this.businessId,
    required this.name,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String businessId;
  final String name;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Map<String, dynamic> toMap() {
    return {
      'businessId': businessId,
      'name': name,
      'createdAt': Timestamp.fromDate(createdAt ?? DateTime.now()),
      'updatedAt': Timestamp.fromDate(updatedAt ?? DateTime.now()),
    };
  }

  factory QuoteItemName.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    if (data == null) {
      throw StateError('Quote item name document is empty');
    }
    return QuoteItemName(
      id: doc.id,
      businessId: (data['businessId'] as String?) ?? '',
      name: (data['name'] as String?) ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }
}
