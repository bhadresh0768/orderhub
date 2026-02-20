import 'package:cloud_firestore/cloud_firestore.dart';

import 'enums.dart';
import 'payment.dart';

class OrderItem {
  const OrderItem({
    required this.title,
    required this.quantity,
    required this.unit,
    this.packSize,
    this.note,
    this.attachments = const [],
    this.unitPrice,
    this.gstIncluded,
    this.isIncluded,
    this.unavailableReason,
  });

  final String title;
  final double quantity;
  final QuantityUnit unit;
  final String? packSize;
  final String? note;
  final List<OrderAttachment> attachments;
  final double? unitPrice;
  final bool? gstIncluded;
  final bool? isIncluded;
  final String? unavailableReason;

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'quantity': quantity,
      'unit': enumToString(unit),
      'packSize': packSize,
      'note': note,
      'attachments': attachments.map((e) => e.toMap()).toList(),
      'unitPrice': unitPrice,
      'gstIncluded': gstIncluded,
      'isIncluded': isIncluded,
      'unavailableReason': unavailableReason,
    };
  }

  factory OrderItem.fromMap(Map<String, dynamic> data) {
    final rawQuantity = data['quantity'];
    final attachmentData = (data['attachments'] as List?) ?? [];
    return OrderItem(
      title: (data['title'] as String?) ?? '',
      quantity: rawQuantity is num ? rawQuantity.toDouble() : 1,
      unit: enumFromString(
        QuantityUnit.values,
        data['unit'] as String?,
        QuantityUnit.piece,
      ),
      packSize: data['packSize'] as String?,
      note: data['note'] as String?,
      attachments: attachmentData
          .whereType<Map>()
          .map(
            (entry) =>
                OrderAttachment.fromMap(Map<String, dynamic>.from(entry)),
          )
          .toList(),
      unitPrice: (data['unitPrice'] is num)
          ? (data['unitPrice'] as num).toDouble()
          : null,
      gstIncluded: data['gstIncluded'] as bool?,
      isIncluded: data['isIncluded'] as bool? ?? true,
      unavailableReason: data['unavailableReason'] as String?,
    );
  }
}

class OrderAttachment {
  const OrderAttachment({required this.name, required this.url});

  final String name;
  final String url;

  Map<String, dynamic> toMap() {
    return {'name': name, 'url': url};
  }

  factory OrderAttachment.fromMap(Map<String, dynamic> data) {
    return OrderAttachment(
      name: (data['name'] as String?) ?? '',
      url: (data['url'] as String?) ?? '',
    );
  }
}

class DeliveryInfo {
  const DeliveryInfo({
    required this.status,
    this.trackingId,
    this.note,
    this.estimatedDeliveryAt,
    this.deliveredAt,
    this.updatedAt,
  });

  final DeliveryStatus status;
  final String? trackingId;
  final String? note;
  final DateTime? estimatedDeliveryAt;
  final DateTime? deliveredAt;
  final DateTime? updatedAt;

  Map<String, dynamic> toMap() {
    return {
      'status': enumToString(status),
      'trackingId': trackingId,
      'note': note,
      'estimatedDeliveryAt': estimatedDeliveryAt == null
          ? null
          : Timestamp.fromDate(estimatedDeliveryAt!),
      'deliveredAt': deliveredAt == null
          ? null
          : Timestamp.fromDate(deliveredAt!),
      'updatedAt': Timestamp.fromDate(updatedAt ?? DateTime.now()),
    };
  }

  factory DeliveryInfo.fromMap(Map<String, dynamic> data) {
    return DeliveryInfo(
      status: enumFromString(
        DeliveryStatus.values,
        data['status'] as String?,
        DeliveryStatus.pending,
      ),
      trackingId: data['trackingId'] as String?,
      note: data['note'] as String?,
      estimatedDeliveryAt: (data['estimatedDeliveryAt'] as Timestamp?)
          ?.toDate(),
      deliveredAt: (data['deliveredAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }
}

class Order {
  const Order({
    required this.id,
    this.orderNumber,
    required this.businessId,
    required this.businessName,
    required this.customerId,
    required this.customerName,
    required this.requesterType,
    required this.priority,
    required this.status,
    required this.payment,
    required this.delivery,
    required this.items,
    required this.attachments,
    required this.packedItemIndexes,
    this.assignedDeliveryAgentId,
    this.assignedDeliveryAgentName,
    this.assignedDeliveryAgentPhone,
    this.assignedDeliveryAt,
    this.requesterBusinessId,
    this.requesterBusinessName,
    this.notes,
    this.gstPercent,
    this.extraCharges,
    this.subtotalAmount,
    this.gstAmount,
    this.totalAmount,
    this.billingUpdatedAt,
    this.scheduledAt,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String? orderNumber;
  final String businessId;
  final String businessName;
  final String customerId;
  final String customerName;
  final OrderRequesterType requesterType;
  final String? requesterBusinessId;
  final String? requesterBusinessName;
  final OrderPriority priority;
  final OrderStatus status;
  final PaymentInfo payment;
  final DeliveryInfo delivery;
  final List<OrderItem> items;
  final List<OrderAttachment> attachments;
  final List<int> packedItemIndexes;
  final String? assignedDeliveryAgentId;
  final String? assignedDeliveryAgentName;
  final String? assignedDeliveryAgentPhone;
  final DateTime? assignedDeliveryAt;
  final String? notes;
  final double? gstPercent;
  final double? extraCharges;
  final double? subtotalAmount;
  final double? gstAmount;
  final double? totalAmount;
  final DateTime? billingUpdatedAt;
  final DateTime? scheduledAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  String get displayOrderNumber {
    final numeric = orderNumber?.trim();
    if (numeric != null && numeric.isNotEmpty) {
      return numeric;
    }
    if (createdAt != null) {
      return createdAt!.millisecondsSinceEpoch.toString();
    }
    final hash = id.codeUnits.fold<int>(0, (prev, code) {
      return (prev * 31 + code) & 0x7fffffff;
    });
    return hash.toString();
  }

  Map<String, dynamic> toMap() {
    return {
      'businessId': businessId,
      'orderNumber': orderNumber,
      'businessName': businessName,
      'customerId': customerId,
      'customerName': customerName,
      'requesterType': enumToString(requesterType),
      'requesterBusinessId': requesterBusinessId,
      'requesterBusinessName': requesterBusinessName,
      'priority': enumToString(priority),
      'status': enumToString(status),
      'payment': payment.toMap(),
      'delivery': delivery.toMap(),
      'items': items.map((e) => e.toMap()).toList(),
      'attachments': attachments.map((e) => e.toMap()).toList(),
      'packedItemIndexes': packedItemIndexes,
      'assignedDeliveryAgentId': assignedDeliveryAgentId,
      'assignedDeliveryAgentName': assignedDeliveryAgentName,
      'assignedDeliveryAgentPhone': assignedDeliveryAgentPhone,
      'assignedDeliveryAt': assignedDeliveryAt == null
          ? null
          : Timestamp.fromDate(assignedDeliveryAt!),
      'notes': notes,
      'gstPercent': gstPercent,
      'extraCharges': extraCharges,
      'subtotalAmount': subtotalAmount,
      'gstAmount': gstAmount,
      'totalAmount': totalAmount,
      'billingUpdatedAt': billingUpdatedAt == null
          ? null
          : Timestamp.fromDate(billingUpdatedAt!),
      'scheduledAt': scheduledAt == null
          ? null
          : Timestamp.fromDate(scheduledAt!),
      'createdAt': Timestamp.fromDate(createdAt ?? DateTime.now()),
      'updatedAt': Timestamp.fromDate(updatedAt ?? DateTime.now()),
    };
  }

  factory Order.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    if (data == null) {
      throw StateError('Order document is empty');
    }
    final itemsData = (data['items'] as List?) ?? [];
    final attachmentData = (data['attachments'] as List?) ?? [];
    final packedIndexesData = (data['packedItemIndexes'] as List?) ?? [];
    return Order(
      id: doc.id,
      orderNumber: data['orderNumber']?.toString(),
      businessId: (data['businessId'] as String?) ?? '',
      businessName: (data['businessName'] as String?) ?? '',
      customerId: (data['customerId'] as String?) ?? '',
      customerName: (data['customerName'] as String?) ?? '',
      requesterType: enumFromString(
        OrderRequesterType.values,
        data['requesterType'] as String?,
        OrderRequesterType.customer,
      ),
      requesterBusinessId: data['requesterBusinessId'] as String?,
      requesterBusinessName: data['requesterBusinessName'] as String?,
      priority: enumFromString(
        OrderPriority.values,
        data['priority'] as String?,
        OrderPriority.medium,
      ),
      status: enumFromString(
        OrderStatus.values,
        data['status'] as String?,
        OrderStatus.pending,
      ),
      payment: PaymentInfo.fromMap(_asMap(data['payment'])),
      delivery: DeliveryInfo.fromMap(_asMap(data['delivery'])),
      items: itemsData.map((item) => OrderItem.fromMap(_asMap(item))).toList(),
      attachments: attachmentData
          .map((item) => OrderAttachment.fromMap(_asMap(item)))
          .toList(),
      packedItemIndexes: packedIndexesData
          .whereType<num>()
          .map((value) => value.toInt())
          .toList(),
      assignedDeliveryAgentId: data['assignedDeliveryAgentId'] as String?,
      assignedDeliveryAgentName: data['assignedDeliveryAgentName'] as String?,
      assignedDeliveryAgentPhone: data['assignedDeliveryAgentPhone'] as String?,
      assignedDeliveryAt: (data['assignedDeliveryAt'] as Timestamp?)?.toDate(),
      notes: data['notes'] as String?,
      gstPercent: (data['gstPercent'] is num)
          ? (data['gstPercent'] as num).toDouble()
          : null,
      extraCharges: (data['extraCharges'] is num)
          ? (data['extraCharges'] as num).toDouble()
          : null,
      subtotalAmount: (data['subtotalAmount'] is num)
          ? (data['subtotalAmount'] as num).toDouble()
          : null,
      gstAmount: (data['gstAmount'] is num)
          ? (data['gstAmount'] as num).toDouble()
          : null,
      totalAmount: (data['totalAmount'] is num)
          ? (data['totalAmount'] as num).toDouble()
          : null,
      billingUpdatedAt: (data['billingUpdatedAt'] as Timestamp?)?.toDate(),
      scheduledAt: (data['scheduledAt'] as Timestamp?)?.toDate(),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  static Map<String, dynamic> _asMap(Object? value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) {
      return value.map(
        (key, dynamic mapValue) => MapEntry(key.toString(), mapValue),
      );
    }
    return {};
  }
}
