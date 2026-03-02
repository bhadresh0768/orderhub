import 'package:cloud_firestore/cloud_firestore.dart' hide Order;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart' show StateProvider;

import '../../../models/delivery_agent.dart';
import '../../../models/enums.dart';
import '../../../models/order.dart';
import '../../../models/payment.dart';
import '../../../providers.dart';

final _businessOrderUiProvider =
    StateProvider.autoDispose.family<_BusinessOrderUiState, Order>(
  (ref, order) => _BusinessOrderUiState(
    order: order,
    selectedPaymentStatus: order.payment.status,
    selectedPaymentMethod: order.payment.method,
    selectedDeliveryAgentId: order.assignedDeliveryAgentId,
    itemGstIncluded: order.items
        .map((item) => item.gstIncluded ?? false)
        .toList(),
    itemIncluded: order.items.map((item) => item.isIncluded ?? true).toList(),
  ),
);

class _BusinessOrderUiState {
  const _BusinessOrderUiState({
    required this.order,
    required this.selectedPaymentStatus,
    required this.selectedPaymentMethod,
    required this.itemGstIncluded,
    required this.itemIncluded,
    this.selectedDeliveryAgentId,
    this.collectPaymentOnAssign = false,
    this.saving = false,
    this.refreshTick = 0,
  });

  final Order order;
  final bool saving;
  final PaymentStatus selectedPaymentStatus;
  final PaymentMethod selectedPaymentMethod;
  final String? selectedDeliveryAgentId;
  final bool collectPaymentOnAssign;
  final List<bool> itemGstIncluded;
  final List<bool> itemIncluded;
  final int refreshTick;

  _BusinessOrderUiState copyWith({
    Order? order,
    bool? saving,
    PaymentStatus? selectedPaymentStatus,
    PaymentMethod? selectedPaymentMethod,
    Object? selectedDeliveryAgentId = _businessOrderUnset,
    bool? collectPaymentOnAssign,
    List<bool>? itemGstIncluded,
    List<bool>? itemIncluded,
    int? refreshTick,
  }) {
    return _BusinessOrderUiState(
      order: order ?? this.order,
      saving: saving ?? this.saving,
      selectedPaymentStatus: selectedPaymentStatus ?? this.selectedPaymentStatus,
      selectedPaymentMethod: selectedPaymentMethod ?? this.selectedPaymentMethod,
      selectedDeliveryAgentId: selectedDeliveryAgentId == _businessOrderUnset
          ? this.selectedDeliveryAgentId
          : selectedDeliveryAgentId as String?,
      collectPaymentOnAssign:
          collectPaymentOnAssign ?? this.collectPaymentOnAssign,
      itemGstIncluded: itemGstIncluded ?? this.itemGstIncluded,
      itemIncluded: itemIncluded ?? this.itemIncluded,
      refreshTick: refreshTick ?? this.refreshTick,
    );
  }
}

const _businessOrderUnset = Object();

class BusinessOrderDetailScreen extends ConsumerStatefulWidget {
  const BusinessOrderDetailScreen({super.key, required this.order});

  final Order order;

  @override
  ConsumerState<BusinessOrderDetailScreen> createState() =>
      _BusinessOrderDetailScreenState();
}

class _BusinessOrderDetailScreenState
    extends ConsumerState<BusinessOrderDetailScreen> {
  ProviderSubscription<AsyncValue<Order?>>? _orderSubscription;
  late final TextEditingController _paymentAmountController;
  late final TextEditingController _gstPercentController;
  late final TextEditingController _extraChargesController;
  late List<TextEditingController> _itemPriceControllers;
  late List<TextEditingController> _itemUnavailableReasonControllers;
  late final String _actorName;
  _BusinessOrderUiState get _ui =>
      ref.read(_businessOrderUiProvider(widget.order));
  void _updateUi(
    _BusinessOrderUiState Function(_BusinessOrderUiState state) update,
  ) {
    final notifier = ref.read(_businessOrderUiProvider(widget.order).notifier);
    notifier.state = update(notifier.state);
  }
  Order get _order => _ui.order;
  bool get _saving => _ui.saving;
  PaymentStatus get _selectedPaymentStatus => _ui.selectedPaymentStatus;
  PaymentMethod get _selectedPaymentMethod => _ui.selectedPaymentMethod;
  String? get _selectedDeliveryAgentId => _ui.selectedDeliveryAgentId;
  bool get _collectPaymentOnAssign => _ui.collectPaymentOnAssign;
  List<bool> get _itemGstIncluded => _ui.itemGstIncluded;
  List<bool> get _itemIncluded => _ui.itemIncluded;
  bool get _isLocked =>
      _order.status == OrderStatus.completed ||
      _order.delivery.status == DeliveryStatus.delivered;
  bool get _isAccepted => _order.status != OrderStatus.pending;

  void _syncTextControllersFromOrder(Order order) {
    _paymentAmountController.text = order.payment.amount?.toStringAsFixed(2) ?? '';
    _gstPercentController.text = order.gstPercent?.toStringAsFixed(2) ?? '';
    _extraChargesController.text = order.extraCharges?.toStringAsFixed(2) ?? '';

    for (final controller in _itemPriceControllers) {
      controller.dispose();
    }
    _itemPriceControllers = order.items
        .map(
          (item) => TextEditingController(
            text: item.unitPrice?.toStringAsFixed(2) ?? '',
          ),
        )
        .toList();

    for (final controller in _itemUnavailableReasonControllers) {
      controller.dispose();
    }
    _itemUnavailableReasonControllers = order.items
        .map(
          (item) => TextEditingController(text: item.unavailableReason ?? ''),
        )
        .toList();
  }

  void _syncUiFromLatestOrder(Order latestOrder) {
    if (!mounted) return;
    _updateUi(
      (state) => state.copyWith(
        order: latestOrder,
        selectedPaymentStatus: latestOrder.payment.status,
        selectedPaymentMethod: latestOrder.payment.method,
        selectedDeliveryAgentId: latestOrder.assignedDeliveryAgentId,
        itemGstIncluded: latestOrder.items
            .map((item) => item.gstIncluded ?? false)
            .toList(),
        itemIncluded: latestOrder.items
            .map((item) => item.isIncluded ?? true)
            .toList(),
        refreshTick: state.refreshTick + 1,
      ),
    );
    _syncTextControllersFromOrder(latestOrder);
  }

  @override
  void initState() {
    super.initState();
    final order = widget.order;
    _actorName = ref.read(authStateProvider).value?.displayName?.trim().isNotEmpty == true
        ? ref.read(authStateProvider).value!.displayName!.trim()
        : 'Business Owner';
    _paymentAmountController = TextEditingController(
      text: order.payment.amount?.toStringAsFixed(2) ?? '',
    );
    _gstPercentController = TextEditingController(
      text: order.gstPercent?.toStringAsFixed(2) ?? '',
    );
    _extraChargesController = TextEditingController(
      text: order.extraCharges?.toStringAsFixed(2) ?? '',
    );
    _itemPriceControllers = order.items
        .map(
          (item) =>
              TextEditingController(text: item.unitPrice?.toStringAsFixed(2) ?? ''),
        )
        .toList();
    _itemUnavailableReasonControllers = order.items
        .map(
          (item) => TextEditingController(text: item.unavailableReason ?? ''),
        )
        .toList();
    _orderSubscription = ref.listenManual<AsyncValue<Order?>>(
      orderByIdProvider(widget.order.id),
      (_, next) {
        next.whenData((latestOrder) {
          if (latestOrder == null) return;
          _syncUiFromLatestOrder(latestOrder);
        });
      },
      fireImmediately: true,
    );
  }

  @override
  void dispose() {
    _orderSubscription?.close();
    _paymentAmountController.dispose();
    _gstPercentController.dispose();
    _extraChargesController.dispose();
    for (final controller in _itemPriceControllers) {
      controller.dispose();
    }
    for (final controller in _itemUnavailableReasonControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  String _formatQuantity(double value) {
    return value == value.truncateToDouble()
        ? value.toInt().toString()
        : value.toStringAsFixed(2);
  }

  String _shortUnit(QuantityUnit unit) {
    switch (unit) {
      case QuantityUnit.piece:
        return 'pc';
      case QuantityUnit.kilogram:
        return 'kg';
      case QuantityUnit.gram:
        return 'g';
      case QuantityUnit.liter:
        return 'L';
    }
  }

  String _itemQuantityLabel(OrderItem item) {
    final pack = (item.packSize ?? '').trim();
    if (pack.isNotEmpty) {
      final qty = _formatQuantity(item.quantity);
      final suffix = item.quantity == 1 ? 'pack' : 'packs';
      return '$qty $suffix ($pack)';
    }
    return '${_formatQuantity(item.quantity)} ${_shortUnit(item.unit)}';
  }

  String _capitalize(String value) {
    if (value.isEmpty) return value;
    return value[0].toUpperCase() + value.substring(1);
  }

  Future<void> _saveStatusUpdates() async {
    if (_isLocked) {
      _showLockedMessage();
      return;
    }
    if (_saving) return;
    _updateUi((state) => state.copyWith(saving: true));
    try {
      await ref.read(firestoreServiceProvider).updateOrder(_order.id, {
        'payment': {
          ..._order.payment.toMap(),
          'status': enumToString(_selectedPaymentStatus),
          'method': enumToString(_selectedPaymentMethod),
          'collectedBy': _selectedPaymentStatus == PaymentStatus.done
              ? enumToString(PaymentCollectedBy.businessOwner)
              : null,
          'collectedByName': _selectedPaymentStatus == PaymentStatus.done
              ? _actorName
              : null,
          'collectedAt': _selectedPaymentStatus == PaymentStatus.done
              ? Timestamp.fromDate(DateTime.now())
              : null,
          'collectionNote': _selectedPaymentStatus == PaymentStatus.done
              ? _order.payment.collectionNote
              : null,
          'amount': double.tryParse(_paymentAmountController.text.trim()),
          'updatedAt': Timestamp.fromDate(DateTime.now()),
        },
      });
      final nextOrder = Order(
          id: _order.id,
          orderNumber: _order.orderNumber,
          businessId: _order.businessId,
          businessName: _order.businessName,
          customerId: _order.customerId,
          customerName: _order.customerName,
          requesterType: _order.requesterType,
          requesterBusinessId: _order.requesterBusinessId,
          requesterBusinessName: _order.requesterBusinessName,
          priority: _order.priority,
          status: _order.status,
          payment: PaymentInfo(
            status: _selectedPaymentStatus,
            method: _selectedPaymentMethod,
            amount: double.tryParse(_paymentAmountController.text.trim()),
            remark: _order.payment.remark,
            confirmedByCustomer: _order.payment.confirmedByCustomer ?? false,
            collectedBy: _selectedPaymentStatus == PaymentStatus.done
                ? PaymentCollectedBy.businessOwner
                : null,
            collectedByName: _selectedPaymentStatus == PaymentStatus.done
                ? _actorName
                : null,
            collectedAt: _selectedPaymentStatus == PaymentStatus.done
                ? DateTime.now()
                : null,
            collectionNote: _selectedPaymentStatus == PaymentStatus.done
                ? _order.payment.collectionNote
                : null,
            updatedAt: DateTime.now(),
          ),
          delivery: _order.delivery,
          items: _order.items,
          attachments: _order.attachments,
          packedItemIndexes: _order.packedItemIndexes,
          assignedDeliveryAgentId: _order.assignedDeliveryAgentId,
          assignedDeliveryAgentName: _order.assignedDeliveryAgentName,
          assignedDeliveryAgentPhone: _order.assignedDeliveryAgentPhone,
          assignedDeliveryAt: _order.assignedDeliveryAt,
          notes: _order.notes,
          gstPercent: _order.gstPercent,
          extraCharges: _order.extraCharges,
          subtotalAmount: _order.subtotalAmount,
          gstAmount: _order.gstAmount,
          totalAmount: _order.totalAmount,
          billingUpdatedAt: _order.billingUpdatedAt,
          scheduledAt: _order.scheduledAt,
          createdAt: _order.createdAt,
          updatedAt: DateTime.now(),
        );
      _updateUi((state) => state.copyWith(order: nextOrder));
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Payment updated')));
    } finally {
      if (mounted) {
        _updateUi((state) => state.copyWith(saving: false));
      }
    }
  }

  String _statusLabel(OrderStatus status) {
    return switch (status) {
      OrderStatus.pending => 'New',
      OrderStatus.approved || OrderStatus.inProgress => 'Processing',
      OrderStatus.completed => 'Completed',
      OrderStatus.cancelled => 'Cancelled',
    };
  }

  String _paymentStatusLabel(PaymentStatus status) {
    return status == PaymentStatus.done ? 'Done' : 'Remaining';
  }

  String _paymentMethodLabel(PaymentMethod method) {
    return switch (method) {
      PaymentMethod.cash => 'Cash',
      PaymentMethod.check => 'Check',
      PaymentMethod.onlineTransfer => 'Online Transfer',
    };
  }

  String _formatAmount(double? value) {
    if (value == null) return 'Not set';
    return value == value.truncateToDouble()
        ? value.toInt().toString()
        : value.toStringAsFixed(2);
  }

  Color _orderStatusColor(OrderStatus status) {
    return switch (status) {
      OrderStatus.completed => Colors.green,
      OrderStatus.pending => Colors.red,
      _ => Colors.orange,
    };
  }

  Color _deliveryStatusColor(DeliveryStatus status) {
    return switch (status) {
      DeliveryStatus.delivered => Colors.green,
      DeliveryStatus.pending => Colors.red,
      _ => Colors.orange,
    };
  }

  Color _paymentStatusColor(PaymentStatus status) {
    return status == PaymentStatus.done ? Colors.green : Colors.red;
  }

  ({String address, String? contact}) _splitLegacyAddress(String value) {
    final raw = value.trim();
    if (raw.isEmpty) return (address: '-', contact: null);
    const marker = '• Contact:';
    final idx = raw.indexOf(marker);
    if (idx < 0) return (address: raw, contact: null);
    final address = raw.substring(0, idx).trim();
    final contact = raw.substring(idx + marker.length).trim();
    return (
      address: address.isEmpty ? '-' : address,
      contact: contact.isEmpty ? null : contact,
    );
  }

  String _requestedByAddress() {
    final direct = (_order.deliveryAddress ?? '').trim();
    if (direct.isNotEmpty) return _splitLegacyAddress(direct).address;

    if (_order.requesterType == OrderRequesterType.businessOwner) {
      final requesterBusinessId = _order.requesterBusinessId;
      if (requesterBusinessId == null || requesterBusinessId.isEmpty) {
        return '-';
      }
      final businessAsync = ref.watch(businessByIdProvider(requesterBusinessId));
      final business = businessAsync.asData?.value;
      final address = (business?.address ?? '').trim();
      final city = (business?.city ?? '').trim();
      if (address.isEmpty && city.isEmpty) return '-';
      if (address.isEmpty) return city;
      if (city.isEmpty) return address;
      return '$address, $city';
    }
    return '-';
  }

  String? _requestedByContact() {
    final name = (_order.deliveryContactName ?? '').trim();
    final phone = (_order.deliveryContactPhone ?? '').trim();
    if (name.isNotEmpty && phone.isNotEmpty) return '$name ($phone)';
    if (name.isNotEmpty) return name;
    if (phone.isNotEmpty) return phone;
    final direct = (_order.deliveryAddress ?? '').trim();
    if (direct.isEmpty) return null;
    return _splitLegacyAddress(direct).contact;
  }

  void _showLockedMessage() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Completed order is locked and cannot be updated.'),
      ),
    );
  }

  String? _clean(String? value) {
    final text = value?.trim() ?? '';
    return text.isEmpty ? null : text;
  }

  bool _looksLikeImage(String value) {
    final normalized = value.toLowerCase();
    return normalized.contains('.jpg') ||
        normalized.contains('.jpeg') ||
        normalized.contains('.png') ||
        normalized.contains('.webp') ||
        normalized.contains('.gif');
  }

  bool _isImageAttachment(OrderAttachment attachment) {
    return _looksLikeImage(attachment.name) || _looksLikeImage(attachment.url);
  }

  Future<void> _showImageGallery(
    List<OrderAttachment> attachments,
    int initialIndex,
  ) async {
    await showDialog<void>(
      context: context,
      builder: (context) {
        return Dialog.fullscreen(
          child: Stack(
            children: [
              PageView.builder(
                controller: PageController(initialPage: initialIndex),
                itemCount: attachments.length,
                itemBuilder: (context, index) {
                  final attachment = attachments[index];
                  return Center(
                    child: InteractiveViewer(
                      child: Image.network(
                        attachment.url,
                        fit: BoxFit.contain,
                        errorBuilder: (_, _, _) =>
                            const Text('Unable to load image'),
                      ),
                    ),
                  );
                },
              ),
              Positioned(
                top: 12,
                left: 12,
                child: IconButton.filledTonal(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  double _toDouble(String input) {
    return double.tryParse(input.trim()) ?? 0;
  }

  ({double subtotal, double gstAmount, double total, double gstPercent, double extra}) _billingPreview() {
    final gstPercent = _toDouble(_gstPercentController.text);
    final extra = _toDouble(_extraChargesController.text);
    var subtotal = 0.0;
    var gstAmount = 0.0;
    for (var i = 0; i < _order.items.length; i++) {
      if (!_itemIncluded[i]) continue;
      final qty = _order.items[i].quantity;
      final unitPrice = _toDouble(_itemPriceControllers[i].text);
      final lineSubtotal = qty * unitPrice;
      subtotal += lineSubtotal;
      if (_itemGstIncluded[i] && gstPercent > 0) {
        gstAmount += (lineSubtotal * gstPercent / 100);
      }
    }
    final total = subtotal + gstAmount + extra;
    return (
      subtotal: subtotal,
      gstAmount: gstAmount,
      total: total,
      gstPercent: gstPercent,
      extra: extra,
    );
  }

  bool _hasMissingIncludedUnitPrice() {
    for (var i = 0; i < _order.items.length; i++) {
      if (!_itemIncluded[i]) continue;
      if (_itemPriceControllers[i].text.trim().isEmpty) {
        return true;
      }
    }
    return false;
  }

  Future<void> _saveBilling() async {
    if (!_isAccepted) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Accept order first to add pricing')),
      );
      return;
    }
    if (_isLocked) {
      _showLockedMessage();
      return;
    }
    if (_saving) return;
    if (_hasMissingIncludedUnitPrice()) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter unit price for all included items before saving'),
        ),
      );
      return;
    }
    _updateUi((state) => state.copyWith(saving: true));
    try {
      final now = DateTime.now();
      final billing = _billingPreview();
      final updatedItems = _order.items.asMap().entries.map((entry) {
        final i = entry.key;
        final item = entry.value;
        final included = _itemIncluded[i];
        final reasonRaw = _itemUnavailableReasonControllers[i].text.trim();
        return OrderItem(
          title: item.title,
          quantity: item.quantity,
          unit: item.unit,
          packSize: item.packSize,
          note: item.note,
          attachments: item.attachments,
          unitPrice: included ? _toDouble(_itemPriceControllers[i].text) : null,
          gstIncluded: included ? _itemGstIncluded[i] : false,
          isIncluded: included,
          unavailableReason: included
              ? null
              : (reasonRaw.isEmpty ? 'Not available' : reasonRaw),
        );
      }).toList();

      await ref.read(firestoreServiceProvider).updateOrder(_order.id, {
        'items': updatedItems.map((e) => e.toMap()).toList(),
        'gstPercent': billing.gstPercent,
        'extraCharges': billing.extra,
        'subtotalAmount': billing.subtotal,
        'gstAmount': billing.gstAmount,
        'totalAmount': billing.total,
        'billingUpdatedAt': Timestamp.fromDate(now),
        'payment': {
          ..._order.payment.toMap(),
          'amount': billing.total,
          'updatedAt': Timestamp.fromDate(now),
        },
      });

      _paymentAmountController.text = billing.total.toStringAsFixed(2);
      final nextOrder = Order(
        id: _order.id,
        orderNumber: _order.orderNumber,
        businessId: _order.businessId,
        businessName: _order.businessName,
        customerId: _order.customerId,
        customerName: _order.customerName,
        requesterType: _order.requesterType,
        requesterBusinessId: _order.requesterBusinessId,
        requesterBusinessName: _order.requesterBusinessName,
        priority: _order.priority,
        status: _order.status,
        payment: PaymentInfo(
          status: _order.payment.status,
          method: _order.payment.method,
          amount: billing.total,
          remark: _order.payment.remark,
          confirmedByCustomer: _order.payment.confirmedByCustomer,
          collectedBy: _order.payment.collectedBy,
          collectedByName: _order.payment.collectedByName,
          collectedAt: _order.payment.collectedAt,
          collectionNote: _order.payment.collectionNote,
          updatedAt: now,
        ),
        delivery: _order.delivery,
        items: updatedItems,
        attachments: _order.attachments,
        packedItemIndexes: _order.packedItemIndexes,
        assignedDeliveryAgentId: _order.assignedDeliveryAgentId,
        assignedDeliveryAgentName: _order.assignedDeliveryAgentName,
        assignedDeliveryAgentPhone: _order.assignedDeliveryAgentPhone,
        assignedDeliveryAt: _order.assignedDeliveryAt,
        notes: _order.notes,
        gstPercent: billing.gstPercent,
        extraCharges: billing.extra,
        subtotalAmount: billing.subtotal,
        gstAmount: billing.gstAmount,
        totalAmount: billing.total,
        billingUpdatedAt: now,
        scheduledAt: _order.scheduledAt,
        createdAt: _order.createdAt,
        updatedAt: now,
      );
      _updateUi((state) => state.copyWith(order: nextOrder));
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Billing updated')));
    } finally {
      if (mounted) {
        _updateUi((state) => state.copyWith(saving: false));
      }
    }
  }

  Future<void> _acceptOrder() async {
    if (_isLocked) {
      _showLockedMessage();
      return;
    }
    if (_saving) return;
    final billing = _billingPreview();

    _updateUi((state) => state.copyWith(saving: true));
    try {
      final now = DateTime.now();
      final updatedItems = _order.items.asMap().entries.map((entry) {
        final i = entry.key;
        final item = entry.value;
        final included = _itemIncluded[i];
        final reasonRaw = _itemUnavailableReasonControllers[i].text.trim();
        return OrderItem(
          title: item.title,
          quantity: item.quantity,
          unit: item.unit,
          packSize: item.packSize,
          note: item.note,
          attachments: item.attachments,
          unitPrice: included ? _toDouble(_itemPriceControllers[i].text) : null,
          gstIncluded: included ? _itemGstIncluded[i] : false,
          isIncluded: included,
          unavailableReason: included
              ? null
              : (reasonRaw.isEmpty ? 'Not available' : reasonRaw),
        );
      }).toList();

      await ref.read(firestoreServiceProvider).updateOrder(_order.id, {
        'items': updatedItems.map((e) => e.toMap()).toList(),
        'gstPercent': billing.gstPercent,
        'extraCharges': billing.extra,
        'subtotalAmount': billing.subtotal,
        'gstAmount': billing.gstAmount,
        'totalAmount': billing.total,
        'billingUpdatedAt': Timestamp.fromDate(now),
        'payment': {
          ..._order.payment.toMap(),
          'amount': billing.total,
          'updatedAt': Timestamp.fromDate(now),
        },
        'status': enumToString(OrderStatus.inProgress),
        'updatedAt': Timestamp.fromDate(now),
      });

      _paymentAmountController.text = billing.total.toStringAsFixed(2);
      final nextOrder = Order(
        id: _order.id,
        orderNumber: _order.orderNumber,
        businessId: _order.businessId,
        businessName: _order.businessName,
        customerId: _order.customerId,
        customerName: _order.customerName,
        requesterType: _order.requesterType,
        requesterBusinessId: _order.requesterBusinessId,
        requesterBusinessName: _order.requesterBusinessName,
        priority: _order.priority,
        status: OrderStatus.inProgress,
        payment: PaymentInfo(
          status: _order.payment.status,
          method: _order.payment.method,
          amount: billing.total,
          remark: _order.payment.remark,
          confirmedByCustomer: _order.payment.confirmedByCustomer,
          collectedBy: _order.payment.collectedBy,
          collectedByName: _order.payment.collectedByName,
          collectedAt: _order.payment.collectedAt,
          collectionNote: _order.payment.collectionNote,
          updatedAt: now,
        ),
        delivery: _order.delivery,
        items: updatedItems,
        attachments: _order.attachments,
        packedItemIndexes: _order.packedItemIndexes,
        assignedDeliveryAgentId: _order.assignedDeliveryAgentId,
        assignedDeliveryAgentName: _order.assignedDeliveryAgentName,
        assignedDeliveryAgentPhone: _order.assignedDeliveryAgentPhone,
        assignedDeliveryAt: _order.assignedDeliveryAt,
        notes: _order.notes,
        gstPercent: billing.gstPercent,
        extraCharges: billing.extra,
        subtotalAmount: billing.subtotal,
        gstAmount: billing.gstAmount,
        totalAmount: billing.total,
        billingUpdatedAt: now,
        scheduledAt: _order.scheduledAt,
        createdAt: _order.createdAt,
        updatedAt: now,
      );
      _updateUi(
        (state) => state.copyWith(
          selectedPaymentStatus: nextOrder.payment.status,
          selectedPaymentMethod: nextOrder.payment.method,
          order: nextOrder,
        ),
      );

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Order accepted')));
    } finally {
      if (mounted) {
        _updateUi((state) => state.copyWith(saving: false));
      }
    }
  }

  Future<(PaymentStatus, PaymentMethod)?> _askPaymentOnAssign() async {
    var selectedStatus = _selectedPaymentStatus;
    var selectedMethod = _selectedPaymentMethod;
    return showDialog<(PaymentStatus, PaymentMethod)>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocalState) => AlertDialog(
          title: const Text('Payment Confirmation'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Confirm payment while assigning delivery agent'),
              const SizedBox(height: 8),
              DropdownButtonFormField<PaymentStatus>(
                initialValue: selectedStatus,
                items: const [
                  DropdownMenuItem(
                    value: PaymentStatus.done,
                    child: Text('Done'),
                  ),
                  DropdownMenuItem(
                    value: PaymentStatus.pending,
                    child: Text('Remaining'),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setLocalState(() => selectedStatus = value);
                  }
                },
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<PaymentMethod>(
                initialValue: selectedMethod,
                items: PaymentMethod.values
                    .map(
                      (method) => DropdownMenuItem(
                        value: method,
                        child: Text(_paymentMethodLabel(method)),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) {
                    setLocalState(() => selectedMethod = value);
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.of(context).pop((selectedStatus, selectedMethod)),
              child: const Text('Confirm'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _assignDeliveryAgent(List<DeliveryAgent> agents) async {
    if (!_isAccepted) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Accept order first to assign delivery agent'),
        ),
      );
      return;
    }
    if (_isLocked) {
      _showLockedMessage();
      return;
    }
    if (_selectedDeliveryAgentId == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Select a delivery agent first'),
        ),
      );
      return;
    }
    (PaymentStatus, PaymentMethod)? paymentDecision;
    if (_collectPaymentOnAssign) {
      paymentDecision = await _askPaymentOnAssign();
      if (paymentDecision == null) return;
    }
    if (_saving) return;
    _updateUi((state) => state.copyWith(saving: true));
    try {
      final agent = agents
          .where((value) => value.id == _selectedDeliveryAgentId)
          .firstOrNull;
      final updatedPayment = paymentDecision == null
          ? _order.payment
          : PaymentInfo(
              status: paymentDecision.$1,
              method: paymentDecision.$2,
              amount: double.tryParse(_paymentAmountController.text.trim()),
              remark: _order.payment.remark,
              confirmedByCustomer: _order.payment.confirmedByCustomer ?? false,
              collectedBy: paymentDecision.$1 == PaymentStatus.done
                  ? PaymentCollectedBy.businessOwner
                  : null,
              collectedByName: paymentDecision.$1 == PaymentStatus.done
                  ? _actorName
                  : null,
              collectedAt: paymentDecision.$1 == PaymentStatus.done
                  ? DateTime.now()
                  : null,
              collectionNote: paymentDecision.$1 == PaymentStatus.done
                  ? _order.payment.collectionNote
                  : null,
              updatedAt: DateTime.now(),
            );
      await ref
          .read(firestoreServiceProvider)
          .assignOrderDeliveryAgent(
            orderId: _order.id,
            agentId: agent?.id,
            agentName: agent?.name,
            agentPhone: agent?.phone,
          );
      if (paymentDecision != null) {
        await ref.read(firestoreServiceProvider).updateOrder(_order.id, {
          'payment': updatedPayment.toMap(),
        });
      }
      final nextOrder = Order(
        id: _order.id,
        orderNumber: _order.orderNumber,
        businessId: _order.businessId,
        businessName: _order.businessName,
        customerId: _order.customerId,
        customerName: _order.customerName,
        requesterType: _order.requesterType,
        requesterBusinessId: _order.requesterBusinessId,
        requesterBusinessName: _order.requesterBusinessName,
        priority: _order.priority,
        status: _order.status,
        payment: updatedPayment,
        delivery: _order.delivery,
        items: _order.items,
        attachments: _order.attachments,
        packedItemIndexes: _order.packedItemIndexes,
        assignedDeliveryAgentId: agent?.id,
        assignedDeliveryAgentName: agent?.name,
        assignedDeliveryAgentPhone: agent?.phone,
        assignedDeliveryAt: agent == null ? null : DateTime.now(),
        notes: _order.notes,
        gstPercent: _order.gstPercent,
        extraCharges: _order.extraCharges,
        subtotalAmount: _order.subtotalAmount,
        gstAmount: _order.gstAmount,
        totalAmount: _order.totalAmount,
        billingUpdatedAt: _order.billingUpdatedAt,
        scheduledAt: _order.scheduledAt,
        createdAt: _order.createdAt,
        updatedAt: DateTime.now(),
      );
      _updateUi(
        (state) => state.copyWith(
          selectedPaymentStatus: paymentDecision?.$1,
          selectedPaymentMethod: paymentDecision?.$2,
          order: nextOrder,
        ),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            paymentDecision == null
                ? (agent == null
                      ? 'Delivery agent removed'
                      : 'Assigned to ${agent.name}')
                : (agent == null
                      ? 'Delivery agent removed and payment updated'
                      : 'Assigned to ${agent.name} and payment updated'),
          ),
        ),
      );
    } finally {
      if (mounted) {
        _updateUi((state) => state.copyWith(saving: false));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(_businessOrderUiProvider(widget.order));
    final agentsAsync = ref.watch(
      deliveryAgentsForBusinessProvider(_order.businessId),
    );
    final isBusinessOrder =
        _order.requesterType == OrderRequesterType.businessOwner;
    final requester = isBusinessOrder
        ? (_order.requesterBusinessName ?? _order.customerName)
        : _order.customerName;
    final requestedAddress = _requestedByAddress();
    final requestedContact = _requestedByContact();
    final includedCount = _itemIncluded.where((value) => value).length;
    final billing = _billingPreview();
    final isLocked = _isLocked;
    final isAccepted = _isAccepted;
    final canEditAfterAccept = !isLocked && isAccepted;
    final missingIncludedPrice = _hasMissingIncludedUnitPrice();
    return Scaffold(
      appBar: AppBar(title: Text('Order ${_order.displayOrderNumber} Details')),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_order.status == OrderStatus.pending) ...[
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: (_saving || isLocked) ? null : _acceptOrder,
                        child: const Text('Accept Order'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Accept this order first. Then you can add pricing and assign a delivery agent.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.red.shade300,
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  if (isLocked) ...[
                    Text(
                      'Order is completed. Editing is disabled.',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.green,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  Text(
                    'Type: ${isBusinessOrder ? 'Business Order' : 'Customer Order'}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Text(
                    'Order by: $requester',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Text(
                    'Address: $requestedAddress',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  if (requestedContact != null)
                    Text(
                      'Contact: $requestedContact',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  Text(
                    'Priority: ${_capitalize(_order.priority.name)}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Text.rich(
                    TextSpan(
                      children: [
                        const TextSpan(text: 'Status: '),
                        TextSpan(
                          text: _statusLabel(_order.status),
                          style: TextStyle(
                            color: _orderStatusColor(_order.status),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Text.rich(
                    TextSpan(
                      children: [
                        const TextSpan(text: 'Delivery: '),
                        TextSpan(
                          text: _capitalize(_order.delivery.status.name),
                          style: TextStyle(
                            color: _deliveryStatusColor(_order.delivery.status),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Text.rich(
                    TextSpan(
                      children: [
                        const TextSpan(text: 'Payment: '),
                        TextSpan(
                          text:
                              '${_paymentStatusLabel(_order.payment.status)} (${_paymentMethodLabel(_order.payment.method)})',
                          style: TextStyle(
                            color: _paymentStatusColor(_order.payment.status),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const TextSpan(text: ' • Amount: '),
                        TextSpan(
                          text: _formatAmount(_order.payment.amount),
                          style: TextStyle(
                            color: _paymentStatusColor(_order.payment.status),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  if (_order.payment.collectedBy != null &&
                      _order.payment.status == PaymentStatus.done)
                    Text(
                      'Collected by: ${_order.payment.collectedBy == PaymentCollectedBy.deliveryBoy ? 'Delivery Boy' : 'Business'}'
                      '${(_order.payment.collectedByName ?? '').trim().isEmpty ? '' : ' (${_order.payment.collectedByName})'}',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  Text(
                    'Delivery Agent: ${_order.assignedDeliveryAgentName ?? 'Not assigned'}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  if (_clean(_order.notes) != null)
                    Text(
                      'Order Remark: ${_clean(_order.notes)}',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.red.shade300,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  if (_clean(_order.delivery.note) != null)
                    Text(
                      'Delivery Remark: ${_clean(_order.delivery.note)}',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  if (_clean(_order.payment.remark) != null)
                    Text(
                      'Payment Remark: ${_clean(_order.payment.remark)}',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  if (_clean(_order.payment.collectionNote) != null)
                    Text(
                      'Delivery Boy Remark: ${_clean(_order.payment.collectionNote)}',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  const SizedBox(height: 8),
                  Text(
                    'Included Items: $includedCount / ${_order.items.length}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Item Pricing',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 10),
                  ..._order.items.asMap().entries.map((entry) {
                    final index = entry.key;
                    final item = entry.value;
                    final itemImageAttachments = item.attachments
                        .where(_isImageAttachment)
                        .toList();
                    final included = _itemIncluded[index];
                    final qty = item.quantity;
                    final unitPrice = _toDouble(_itemPriceControllers[index].text);
                    final lineSubtotal = included ? qty * unitPrice : 0;
                    final lineGst = included &&
                            _itemGstIncluded[index] &&
                            billing.gstPercent > 0
                        ? lineSubtotal * billing.gstPercent / 100
                        : 0.0;
                    final lineTotal = lineSubtotal + lineGst;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Text(
                                  '${item.title} • Qty ${_itemQuantityLabel(item)}',
                                  style: Theme.of(context).textTheme.titleMedium,
                                ),
                              ),
                              if (itemImageAttachments.isNotEmpty) ...[
                                const SizedBox(width: 10),
                                InkWell(
                                  onTap: () =>
                                      _showImageGallery(itemImageAttachments, 0),
                                  borderRadius: BorderRadius.circular(10),
                                  child: Stack(
                                    children: [
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(10),
                                        child: Image.network(
                                          itemImageAttachments.first.url,
                                          width: 72,
                                          height: 72,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, _, _) => Container(
                                            width: 72,
                                            height: 72,
                                            color: Colors.black12,
                                            alignment: Alignment.center,
                                            child: const Icon(
                                              Icons.image_not_supported_outlined,
                                            ),
                                          ),
                                        ),
                                      ),
                                      Positioned(
                                        top: 5,
                                        right: 5,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 6,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.black.withValues(
                                              alpha: 0.70,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              999,
                                            ),
                                          ),
                                          child: Text(
                                            '${itemImageAttachments.length}',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w700,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 4),
                          CheckboxListTile(
                            contentPadding: EdgeInsets.zero,
                            dense: true,
                            controlAffinity: ListTileControlAffinity.leading,
                            value: included,
                            onChanged: canEditAfterAccept
                                ? (value) => _updateUi((state) {
                                    final updated = List<bool>.from(
                                      state.itemIncluded,
                                    );
                                    updated[index] = value ?? true;
                                    return state.copyWith(itemIncluded: updated);
                                  })
                                : null,
                            title: const Text('Include in Delivery'),
                          ),
                          if (!included)
                            TextFormField(
                              controller:
                                  _itemUnavailableReasonControllers[index],
                              enabled: canEditAfterAccept,
                              decoration: const InputDecoration(
                                labelText: 'Unavailable Reason',
                                hintText: 'Not available',
                              ),
                              onChanged: canEditAfterAccept
                                  ? (_) => _updateUi(
                                      (state) => state.copyWith(
                                        refreshTick: state.refreshTick + 1,
                                      ),
                                    )
                                  : null,
                            ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: _itemPriceControllers[index],
                                  enabled: included && canEditAfterAccept,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                        decimal: true,
                                      ),
                                  decoration: const InputDecoration(
                                    labelText: 'Unit Price',
                                  ),
                                  onChanged: canEditAfterAccept
                                      ? (_) => _updateUi(
                                      (state) => state.copyWith(
                                        refreshTick: state.refreshTick + 1,
                                      ),
                                    )
                                      : null,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: CheckboxListTile(
                                  contentPadding: EdgeInsets.zero,
                                  dense: true,
                                  controlAffinity:
                                      ListTileControlAffinity.leading,
                                  value: _itemGstIncluded[index],
                                  onChanged: (included && canEditAfterAccept)
                                      ? (value) => _updateUi((state) {
                                          final updated = List<bool>.from(
                                            state.itemGstIncluded,
                                          );
                                          updated[index] = value ?? false;
                                          return state.copyWith(
                                            itemGstIncluded: updated,
                                          );
                                        })
                                      : null,
                                  title: const Text('GST'),
                                ),
                              ),
                            ],
                          ),
                          Text(
                            'Line Total: ${_formatAmount(lineTotal)}',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    );
                  }),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _gstPercentController,
                          enabled: canEditAfterAccept,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'Common GST %',
                            hintText: 'e.g. 18',
                          ),
                          onChanged: canEditAfterAccept
                                  ? (_) => _updateUi(
                                      (state) => state.copyWith(
                                        refreshTick: state.refreshTick + 1,
                                      ),
                                    )
                                  : null,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _extraChargesController,
                          enabled: canEditAfterAccept,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'Extra Charges',
                            hintText: 'e.g. 50',
                          ),
                          onChanged: canEditAfterAccept
                                  ? (_) => _updateUi(
                                      (state) => state.copyWith(
                                        refreshTick: state.refreshTick + 1,
                                      ),
                                    )
                                  : null,
                        ),
                      ),
                    ],
                  ),
                  if (!isAccepted) ...[
                    const SizedBox(height: 6),
                    Text(
                      'Pricing is disabled until order is accepted.',
                      style: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.copyWith(color: Colors.orange[800]),
                    ),
                  ],
                  if (canEditAfterAccept && missingIncludedPrice) ...[
                    const SizedBox(height: 6),
                    Text(
                      'Enter unit price for all included items to enable Save Pricing.',
                      style: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.copyWith(color: Colors.red[700]),
                    ),
                  ],
                  const SizedBox(height: 10),
                  Text('Subtotal: ${_formatAmount(billing.subtotal)}'),
                  Text('GST Amount: ${_formatAmount(billing.gstAmount)}'),
                  Text(
                    'Grand Total: ${_formatAmount(billing.total)}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: (_saving || !canEditAfterAccept || missingIncludedPrice)
                          ? null
                          : _saveBilling,
                      child: Text(_saving ? 'Saving...' : 'Save Pricing'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Quick Status Update',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  agentsAsync.when(
                    data: (agents) {
                      final activeAgents = agents
                          .where((agent) => agent.isActive)
                          .toList();
                      final hasSelectedAgent =
                          _selectedDeliveryAgentId == null ||
                          activeAgents.any(
                            (agent) => agent.id == _selectedDeliveryAgentId,
                          );
                      final selectedDeliveryAgentId = hasSelectedAgent
                          ? _selectedDeliveryAgentId
                          : null;
                      if (!hasSelectedAgent) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          _updateUi(
                            (state) => state.copyWith(
                              selectedDeliveryAgentId: null,
                            ),
                          );
                        });
                      }
                      return Column(
                        children: [
                          DropdownButtonFormField<String?>(
                            isExpanded: true,
                            initialValue: selectedDeliveryAgentId,
                            decoration: const InputDecoration(
                              labelText: 'Assign Delivery Agent',
                            ),
                            items: [
                              const DropdownMenuItem<String?>(
                                value: null,
                                child: Text('Unassigned'),
                              ),
                              ...activeAgents.map(
                                (agent) => DropdownMenuItem<String?>(
                                  value: agent.id,
                                  child: Text('${agent.name} • ${agent.phone}'),
                                ),
                              ),
                            ],
                            onChanged: canEditAfterAccept
                                ? (value) => _updateUi(
                                    (state) => state.copyWith(
                                      selectedDeliveryAgentId: value,
                                    ),
                                  )
                                : null,
                          ),
                          const SizedBox(height: 6),
                          CheckboxListTile(
                            contentPadding: EdgeInsets.zero,
                            dense: true,
                            value: _collectPaymentOnAssign,
                            title: const Text('Collect payment now (optional)'),
                            onChanged: canEditAfterAccept
                                ? (value) => _updateUi(
                                    (state) => state.copyWith(
                                      collectPaymentOnAssign: value ?? false,
                                    ),
                                  )
                                : null,
                          ),
                          const SizedBox(height: 8),
                          if (canEditAfterAccept &&
                              selectedDeliveryAgentId == null)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  'Select a delivery agent to enable save.',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.copyWith(color: Colors.red[700]),
                                ),
                              ),
                            ),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton(
                              onPressed: _saving
                                  ? null
                                  : !canEditAfterAccept
                                  ? null
                                  : selectedDeliveryAgentId == null
                                  ? null
                                  : () => _assignDeliveryAgent(activeAgents),
                              child: const Text('Save Delivery Agent'),
                            ),
                          ),
                        ],
                      );
                    },
                    loading: () => const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: LinearProgressIndicator(),
                    ),
                    error: (err, _) => Text('Delivery agent load failed: $err'),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<PaymentStatus>(
                    isExpanded: true,
                    initialValue: _selectedPaymentStatus,
                    decoration: const InputDecoration(
                      labelText: 'Payment Status',
                    ),
                    items: PaymentStatus.values
                        .map(
                          (status) => DropdownMenuItem(
                            value: status,
                            child: Text(_paymentStatusLabel(status)),
                          ),
                        )
                        .toList(),
                    onChanged: canEditAfterAccept
                        ? (value) {
                            if (value == null) return;
                            _updateUi(
                              (state) =>
                                  state.copyWith(selectedPaymentStatus: value),
                            );
                          }
                        : null,
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<PaymentMethod>(
                    isExpanded: true,
                    initialValue: _selectedPaymentMethod,
                    decoration: const InputDecoration(
                      labelText: 'Payment Method',
                    ),
                    items: PaymentMethod.values
                        .map(
                          (method) => DropdownMenuItem(
                            value: method,
                            child: Text(_paymentMethodLabel(method)),
                          ),
                        )
                        .toList(),
                    onChanged: canEditAfterAccept
                        ? (value) {
                            if (value == null) return;
                            _updateUi(
                              (state) =>
                                  state.copyWith(selectedPaymentMethod: value),
                            );
                          }
                        : null,
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _paymentAmountController,
                    enabled: canEditAfterAccept,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Order Amount',
                      hintText: 'e.g. 1250',
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed:
                          (_saving || !canEditAfterAccept)
                              ? null
                              : _saveStatusUpdates,
                      child: Text(_saving ? 'Saving...' : 'Update Payment'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          ],
        ),
      ),
    );
  }
}
