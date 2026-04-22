import 'package:cloud_firestore/cloud_firestore.dart';

import 'enums.dart';
import 'order.dart';

enum CatalogUnitType { volume, weight, count }

const Map<CatalogUnitType, List<QuantityUnit>> _catalogUnitsByType = {
  CatalogUnitType.volume: [
    QuantityUnit.liter,
  ],
  CatalogUnitType.weight: [
    QuantityUnit.gram,
    QuantityUnit.kilogram,
    QuantityUnit.ton,
  ],
  CatalogUnitType.count: [
    QuantityUnit.piece,
    QuantityUnit.packet,
    QuantityUnit.box,
    QuantityUnit.bag,
    QuantityUnit.bottle,
    QuantityUnit.can,
    QuantityUnit.carton,
    QuantityUnit.meter,
    QuantityUnit.foot,
  ],
};

List<String> catalogBaseUnitsForType(CatalogUnitType type) {
  final units = _catalogUnitsByType[type] ?? const <QuantityUnit>[];
  return units.map(quantityUnitDefaultSymbol).toList();
}

class CatalogCategory {
  const CatalogCategory({
    required this.id,
    required this.businessId,
    required this.name,
    this.sortOrder = 0,
    this.isActive = true,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String businessId;
  final String name;
  final int sortOrder;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Map<String, dynamic> toMap() => {
    'businessId': businessId,
    'name': name,
    'sortOrder': sortOrder,
    'isActive': isActive,
    'createdAt': createdAt == null ? null : Timestamp.fromDate(createdAt!),
    'updatedAt': updatedAt == null ? null : Timestamp.fromDate(updatedAt!),
  };

  factory CatalogCategory.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? {};
    return CatalogCategory(
      id: doc.id,
      businessId: (data['businessId'] as String?) ?? '',
      name: (data['name'] as String?) ?? '',
      sortOrder: (data['sortOrder'] as num?)?.toInt() ?? 0,
      isActive: (data['isActive'] as bool?) ?? true,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }
}

class CatalogProduct {
  const CatalogProduct({
    required this.id,
    required this.businessId,
    required this.name,
    this.categoryId,
    this.description,
    this.imageUrls = const [],
    this.isActive = true,
    this.searchKeywords = const [],
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String businessId;
  final String name;
  final String? categoryId;
  final String? description;
  final List<String> imageUrls;
  final bool isActive;
  final List<String> searchKeywords;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Map<String, dynamic> toMap() => {
    'businessId': businessId,
    'name': name,
    'categoryId': categoryId,
    'description': description,
    'imageUrls': imageUrls,
    'isActive': isActive,
    'searchKeywords': searchKeywords,
    'createdAt': createdAt == null ? null : Timestamp.fromDate(createdAt!),
    'updatedAt': updatedAt == null ? null : Timestamp.fromDate(updatedAt!),
  };

  factory CatalogProduct.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? {};
    return CatalogProduct(
      id: doc.id,
      businessId: (data['businessId'] as String?) ?? '',
      name: (data['name'] as String?) ?? '',
      categoryId: data['categoryId'] as String?,
      description: data['description'] as String?,
      imageUrls:
          (data['imageUrls'] as List?)?.whereType<String>().toList() ?? const [],
      isActive: (data['isActive'] as bool?) ?? true,
      searchKeywords: (data['searchKeywords'] as List?)
              ?.whereType<String>()
              .toList() ??
          const [],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }
}

class CatalogVariant {
  const CatalogVariant({
    required this.id,
    required this.businessId,
    required this.productId,
    required this.label,
    required this.unitType,
    required this.baseValue,
    required this.baseUnit,
    required this.price,
    this.mrp,
    this.stockQty,
    this.isActive = true,
    this.imageUrls = const [],
    this.primaryImageIndex,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String businessId;
  final String productId;
  final String label;
  final CatalogUnitType unitType;
  final int baseValue;
  final String baseUnit;
  final double price;
  final double? mrp;
  final int? stockQty;
  final bool isActive;
  final List<String> imageUrls;
  final int? primaryImageIndex;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Map<String, dynamic> toMap() => {
    'businessId': businessId,
    'productId': productId,
    'label': label,
    'unitType': enumToString(unitType),
    'baseValue': baseValue,
    'baseUnit': baseUnit,
    'price': price,
    'mrp': mrp,
    'stockQty': stockQty,
    'isActive': isActive,
    'imageUrls': imageUrls,
    'primaryImageIndex': primaryImageIndex,
    'createdAt': createdAt == null ? null : Timestamp.fromDate(createdAt!),
    'updatedAt': updatedAt == null ? null : Timestamp.fromDate(updatedAt!),
  };

  factory CatalogVariant.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? {};
    return CatalogVariant(
      id: doc.id,
      businessId: (data['businessId'] as String?) ?? '',
      productId: (data['productId'] as String?) ?? '',
      label: (data['label'] as String?) ?? '',
      unitType: enumFromString(
        CatalogUnitType.values,
        data['unitType'] as String?,
        CatalogUnitType.count,
      ),
      baseValue: (data['baseValue'] as num?)?.toInt() ?? 0,
      baseUnit: (data['baseUnit'] as String?) ?? '',
      price: (data['price'] as num?)?.toDouble() ?? 0,
      mrp: (data['mrp'] as num?)?.toDouble(),
      stockQty: (data['stockQty'] as num?)?.toInt(),
      isActive: (data['isActive'] as bool?) ?? true,
      imageUrls:
          (data['imageUrls'] as List?)?.whereType<String>().toList() ?? const [],
      primaryImageIndex: (data['primaryImageIndex'] as num?)?.toInt(),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }
}
