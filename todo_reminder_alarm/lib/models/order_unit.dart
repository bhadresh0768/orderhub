import 'package:cloud_firestore/cloud_firestore.dart';

class OrderUnit {
  const OrderUnit({
    required this.code,
    required this.label,
    required this.symbol,
    this.isActive = true,
    this.sortOrder = 0,
    this.createdAt,
    this.updatedAt,
  });

  final String code;
  final String label;
  final String symbol;
  final bool isActive;
  final int sortOrder;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  String get displayLabel {
    final short = symbol.trim();
    return short.isEmpty ? label : '$label ($short)';
  }

  Map<String, dynamic> toMap() {
    return {
      'code': code,
      'label': label,
      'symbol': symbol,
      'isActive': isActive,
      'sortOrder': sortOrder,
      'createdAt': createdAt == null ? null : Timestamp.fromDate(createdAt!),
      'updatedAt': Timestamp.fromDate(updatedAt ?? DateTime.now()),
    };
  }

  factory OrderUnit.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    return OrderUnit.fromMap(doc.data() ?? const <String, dynamic>{});
  }

  factory OrderUnit.fromMap(Map<String, dynamic> data) {
    final code = (data['code'] as String? ?? '').trim().toLowerCase();
    final label = (data['label'] as String? ?? '').trim();
    final symbol = (data['symbol'] as String? ?? '').trim();
    return OrderUnit(
      code: code,
      label: label,
      symbol: symbol,
      isActive: data['isActive'] as bool? ?? true,
      sortOrder: (data['sortOrder'] as num?)?.toInt() ?? 0,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }
}
