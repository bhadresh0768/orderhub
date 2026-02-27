import 'package:cloud_firestore/cloud_firestore.dart';

class DeliveryAddressEntry {
  const DeliveryAddressEntry({
    required this.id,
    required this.userId,
    required this.label,
    required this.address,
    this.city,
    this.contactPerson,
    this.contactPhone,
    this.isDefault = false,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String userId;
  final String label;
  final String address;
  final String? city;
  final String? contactPerson;
  final String? contactPhone;
  final bool isDefault;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  String get fullAddress {
    final addressText = address.trim();
    final cityText = (city ?? '').trim();
    if (addressText.isEmpty && cityText.isEmpty) return '-';
    if (addressText.isEmpty) return cityText;
    if (cityText.isEmpty) return addressText;
    return '$addressText, $cityText';
  }

  String get contactSummary {
    final person = (contactPerson ?? '').trim();
    final phone = (contactPhone ?? '').trim();
    if (person.isEmpty && phone.isEmpty) return '';
    if (person.isEmpty) return phone;
    if (phone.isEmpty) return person;
    return '$person ($phone)';
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'label': label,
      'address': address,
      'city': city,
      'contactPerson': contactPerson,
      'contactPhone': contactPhone,
      'isDefault': isDefault,
      'createdAt': Timestamp.fromDate(createdAt ?? DateTime.now()),
      'updatedAt': Timestamp.fromDate(updatedAt ?? DateTime.now()),
    };
  }

  factory DeliveryAddressEntry.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    if (data == null) {
      throw StateError('Delivery address is empty');
    }
    return DeliveryAddressEntry(
      id: doc.id,
      userId: (data['userId'] as String?) ?? '',
      label: (data['label'] as String?) ?? '',
      address: (data['address'] as String?) ?? '',
      city: data['city'] as String?,
      contactPerson: data['contactPerson'] as String?,
      contactPhone: data['contactPhone'] as String?,
      isDefault: (data['isDefault'] as bool?) ?? false,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }
}
