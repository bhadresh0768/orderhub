import 'package:cloud_firestore/cloud_firestore.dart';

import 'enums.dart';

class ContactUsMessage {
  const ContactUsMessage({
    required this.id,
    required this.userId,
    required this.userRole,
    required this.name,
    required this.mobileNumber,
    required this.description,
    this.createdAt,
  });

  final String id;
  final String userId;
  final UserRole userRole;
  final String name;
  final String mobileNumber;
  final String description;
  final DateTime? createdAt;

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'userRole': enumToString(userRole),
      'name': name,
      'mobileNumber': mobileNumber,
      'description': description,
      'createdAt': Timestamp.fromDate(createdAt ?? DateTime.now()),
    };
  }

  factory ContactUsMessage.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    if (data == null) {
      throw StateError('Contact us message document is empty');
    }
    return ContactUsMessage(
      id: doc.id,
      userId: (data['userId'] as String?) ?? '',
      userRole: enumFromString(
        UserRole.values,
        data['userRole'] as String?,
        UserRole.customer,
      ),
      name: (data['name'] as String?) ?? '',
      mobileNumber: (data['mobileNumber'] as String?) ?? '',
      description: (data['description'] as String?) ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }
}
