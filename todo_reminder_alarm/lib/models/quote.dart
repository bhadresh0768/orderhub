import 'package:cloud_firestore/cloud_firestore.dart';

class QuoteLineItem {
  const QuoteLineItem({
    required this.title,
    required this.quantity,
    required this.unitPrice,
    this.description,
    this.unit,
    this.discountAmount = 0,
    this.taxPercent = 0,
  });

  final String title;
  final String? description;
  final double quantity;
  final String? unit;
  final double unitPrice;
  final double discountAmount;
  final double taxPercent;

  double get grossAmount => quantity * unitPrice;
  double get taxableAmount {
    final amount = grossAmount - discountAmount;
    return amount < 0 ? 0 : amount;
  }

  double get taxAmount => taxableAmount * (taxPercent / 100);
  double get totalAmount => taxableAmount + taxAmount;

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'description': description,
      'quantity': quantity,
      'unit': unit,
      'unitPrice': unitPrice,
      'discountAmount': discountAmount,
      'taxPercent': taxPercent,
      'grossAmount': grossAmount,
      'taxableAmount': taxableAmount,
      'taxAmount': taxAmount,
      'totalAmount': totalAmount,
    };
  }

  factory QuoteLineItem.fromMap(Map<String, dynamic> data) {
    return QuoteLineItem(
      title: (data['title'] as String?) ?? '',
      description: data['description'] as String?,
      quantity: (data['quantity'] as num?)?.toDouble() ?? 0,
      unit: data['unit'] as String?,
      unitPrice: (data['unitPrice'] as num?)?.toDouble() ?? 0,
      discountAmount: (data['discountAmount'] as num?)?.toDouble() ?? 0,
      taxPercent: (data['taxPercent'] as num?)?.toDouble() ?? 0,
    );
  }
}

class Quote {
  const Quote({
    required this.id,
    required this.businessId,
    required this.businessName,
    required this.quoteNumber,
    required this.customerName,
    required this.quoteDate,
    required this.validUntil,
    required this.items,
    required this.createdByUserId,
    required this.createdByName,
    this.customerContact,
    this.customerPhone,
    this.customerEmail,
    this.customerAddress,
    this.preparedBy,
    this.currencySymbol = 'Rs.',
    this.paymentTerms,
    this.deliveryTimeline,
    this.extraCharges = 0,
    this.extraChargesLabel = 'Extra Charges',
    this.notes,
    this.additionalTerms = const [],
    this.subtotal = 0,
    this.discountTotal = 0,
    this.taxableAmount = 0,
    this.taxAmount = 0,
    this.grandTotal = 0,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String businessId;
  final String businessName;
  final String quoteNumber;
  final String customerName;
  final String? customerContact;
  final String? customerPhone;
  final String? customerEmail;
  final String? customerAddress;
  final DateTime quoteDate;
  final DateTime validUntil;
  final String? preparedBy;
  final String currencySymbol;
  final String? paymentTerms;
  final String? deliveryTimeline;
  final double extraCharges;
  final String extraChargesLabel;
  final String? notes;
  final List<String> additionalTerms;
  final List<QuoteLineItem> items;
  final double subtotal;
  final double discountTotal;
  final double taxableAmount;
  final double taxAmount;
  final double grandTotal;
  final String createdByUserId;
  final String createdByName;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Map<String, dynamic> toMap() {
    return {
      'businessId': businessId,
      'businessName': businessName,
      'quoteNumber': quoteNumber,
      'customerName': customerName,
      'customerContact': customerContact,
      'customerPhone': customerPhone,
      'customerEmail': customerEmail,
      'customerAddress': customerAddress,
      'quoteDate': Timestamp.fromDate(quoteDate),
      'validUntil': Timestamp.fromDate(validUntil),
      'preparedBy': preparedBy,
      'currencySymbol': currencySymbol,
      'paymentTerms': paymentTerms,
      'deliveryTimeline': deliveryTimeline,
      'extraCharges': extraCharges,
      'extraChargesLabel': extraChargesLabel,
      'notes': notes,
      'additionalTerms': additionalTerms,
      'items': items.map((item) => item.toMap()).toList(),
      'subtotal': subtotal,
      'discountTotal': discountTotal,
      'taxableAmount': taxableAmount,
      'taxAmount': taxAmount,
      'grandTotal': grandTotal,
      'createdByUserId': createdByUserId,
      'createdByName': createdByName,
      'createdAt': Timestamp.fromDate(createdAt ?? DateTime.now()),
      'updatedAt': Timestamp.fromDate(updatedAt ?? DateTime.now()),
    };
  }

  factory Quote.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    if (data == null) {
      throw StateError('Quote document is empty');
    }
    final itemsData = (data['items'] as List?) ?? const [];
    final additionalTermsData = (data['additionalTerms'] as List?) ?? const [];
    return Quote(
      id: doc.id,
      businessId: (data['businessId'] as String?) ?? '',
      businessName: (data['businessName'] as String?) ?? '',
      quoteNumber: (data['quoteNumber'] as String?) ?? '',
      customerName: (data['customerName'] as String?) ?? '',
      customerContact: data['customerContact'] as String?,
      customerPhone: data['customerPhone'] as String?,
      customerEmail: data['customerEmail'] as String?,
      customerAddress: data['customerAddress'] as String?,
      quoteDate: ((data['quoteDate'] as Timestamp?) ?? Timestamp.now())
          .toDate(),
      validUntil: ((data['validUntil'] as Timestamp?) ?? Timestamp.now())
          .toDate(),
      preparedBy: data['preparedBy'] as String?,
      currencySymbol: (data['currencySymbol'] as String?) ?? 'Rs.',
      paymentTerms: data['paymentTerms'] as String?,
      deliveryTimeline: data['deliveryTimeline'] as String?,
      extraCharges: (data['extraCharges'] as num?)?.toDouble() ?? 0,
      extraChargesLabel:
          (data['extraChargesLabel'] as String?) ?? 'Extra Charges',
      notes: data['notes'] as String?,
      additionalTerms: additionalTermsData
          .map((entry) => entry.toString())
          .toList(),
      items: itemsData
          .whereType<Map>()
          .map(
            (entry) => QuoteLineItem.fromMap(Map<String, dynamic>.from(entry)),
          )
          .toList(),
      subtotal: (data['subtotal'] as num?)?.toDouble() ?? 0,
      discountTotal: (data['discountTotal'] as num?)?.toDouble() ?? 0,
      taxableAmount: (data['taxableAmount'] as num?)?.toDouble() ?? 0,
      taxAmount: (data['taxAmount'] as num?)?.toDouble() ?? 0,
      grandTotal: (data['grandTotal'] as num?)?.toDouble() ?? 0,
      createdByUserId: (data['createdByUserId'] as String?) ?? '',
      createdByName: (data['createdByName'] as String?) ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }
}
