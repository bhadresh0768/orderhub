import 'package:cloud_firestore/cloud_firestore.dart';

import 'enums.dart';

class AppUser {
  const AppUser({
    required this.id,
    required this.email,
    required this.role,
    required this.name,
    this.phoneNumber,
    this.photoUrl,
    this.appShareLink,
    this.shopName,
    this.address,
    this.deleteRequestStatus,
    this.deleteRequestedAt,
    this.isActive = true,
    this.businessId,
    this.createdAt,
  });

  final String id;
  final String email;
  final String name;
  final String? phoneNumber;
  final String? photoUrl;
  final String? appShareLink;
  final String? shopName;
  final String? address;
  final String? deleteRequestStatus;
  final DateTime? deleteRequestedAt;
  final UserRole role;
  final bool isActive;
  final String? businessId;
  final DateTime? createdAt;

  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'name': name,
      'phoneNumber': phoneNumber,
      'photoUrl': photoUrl,
      'appShareLink': appShareLink,
      'shopName': shopName,
      'address': address,
      'deleteRequestStatus': deleteRequestStatus,
      'deleteRequestedAt': deleteRequestedAt == null
          ? null
          : Timestamp.fromDate(deleteRequestedAt!),
      'role': enumToString(role),
      'isActive': isActive,
      'businessId': businessId,
      'createdAt': Timestamp.fromDate(createdAt ?? DateTime.now()),
    };
  }

  factory AppUser.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    if (data == null) {
      throw StateError('User document is empty');
    }
    return AppUser(
      id: doc.id,
      email: (data['email'] as String?) ?? '',
      name: (data['name'] as String?) ?? '',
      phoneNumber: data['phoneNumber'] as String?,
      photoUrl: data['photoUrl'] as String?,
      appShareLink: data['appShareLink'] as String?,
      shopName: data['shopName'] as String?,
      address: data['address'] as String?,
      deleteRequestStatus: data['deleteRequestStatus'] as String?,
      deleteRequestedAt: (data['deleteRequestedAt'] as Timestamp?)?.toDate(),
      role: enumFromString(
        UserRole.values,
        data['role'] as String?,
        UserRole.customer,
      ),
      isActive: (data['isActive'] as bool?) ?? true,
      businessId: data['businessId'] as String?,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }
}
