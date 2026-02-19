import 'package:cloud_firestore/cloud_firestore.dart' hide Order;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/delivery_agent.dart';
import '../../../models/enums.dart';
import '../../../models/order.dart';
import '../../../models/payment.dart';
import '../../../providers.dart';

class BusinessOrderDetailScreen extends ConsumerStatefulWidget {
  const BusinessOrderDetailScreen({super.key, required this.order});

  final Order order;

  @override
  ConsumerState<BusinessOrderDetailScreen> createState() =>
      _BusinessOrderDetailScreenState();
}

class _BusinessOrderDetailScreenState
    extends ConsumerState<BusinessOrderDetailScreen> {
  late Order _order;
  bool _saving = false;
  late PaymentStatus _selectedPaymentStatus;
  late PaymentMethod _selectedPaymentMethod;
  String? _selectedDeliveryAgentId;
  bool _collectPaymentOnAssign = false;
  late final TextEditingController _paymentAmountController;
  late final TextEditingController _gstPercentController;
  late final TextEditingController _extraChargesController;
  late List<TextEditingController> _itemPriceControllers;
  late List<bool> _itemGstIncluded;
  late List<bool> _itemIncluded;
  late List<TextEditingController> _itemUnavailableReasonControllers;
  late final String _actorName;

  @override
  void initState() {
    super.initState();
    _order = widget.order;
    _selectedPaymentStatus = _order.payment.status;
    _selectedPaymentMethod = _order.payment.method;
    _selectedDeliveryAgentId = _order.assignedDeliveryAgentId;
    _actorName = ref.read(authStateProvider).value?.displayName?.trim().isNotEmpty == true
        ? ref.read(authStateProvider).value!.displayName!.trim()
        : 'Business Owner';
    _paymentAmountController = TextEditingController(
      text: _order.payment.amount?.toStringAsFixed(2) ?? '',
    );
    _gstPercentController = TextEditingController(
      text: _order.gstPercent?.toStringAsFixed(2) ?? '',
    );
    _extraChargesController = TextEditingController(
      text: _order.extraCharges?.toStringAsFixed(2) ?? '',
    );
    _itemPriceControllers = _order.items
        .map(
          (item) =>
              TextEditingController(text: item.unitPrice?.toStringAsFixed(2) ?? ''),
        )
        .toList();
    _itemGstIncluded = _order.items.map((item) => item.gstIncluded ?? false).toList();
    _itemIncluded = _order.items.map((item) => item.isIncluded ?? true).toList();
    _itemUnavailableReasonControllers = _order.items
        .map(
          (item) => TextEditingController(text: item.unavailableReason ?? ''),
        )
        .toList();
  }

  @override
  void dispose() {
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

  Future<void> _saveStatusUpdates() async {
    if (_saving) return;
    setState(() => _saving = true);
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
      setState(() {
        _order = Order(
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
      });
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Payment updated')));
    } finally {
      if (mounted) {
        setState(() => _saving = false);
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

  Future<void> _saveBilling() async {
    if (_saving) return;
    setState(() => _saving = true);
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

      setState(() {
        _paymentAmountController.text = billing.total.toStringAsFixed(2);
        _order = Order(
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
      });
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Billing updated')));
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _acceptOrder() async {
    if (_saving) return;
    final billing = _billingPreview();
    if (billing.total <= 0) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter item price before accepting order')),
      );
      return;
    }

    setState(() => _saving = true);
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

      setState(() {
        _selectedPaymentStatus = _order.payment.status;
        _selectedPaymentMethod = _order.payment.method;
        _paymentAmountController.text = billing.total.toStringAsFixed(2);
        _order = Order(
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
      });

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Order accepted')));
    } finally {
      if (mounted) {
        setState(() => _saving = false);
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
    (PaymentStatus, PaymentMethod)? paymentDecision;
    if (_collectPaymentOnAssign) {
      paymentDecision = await _askPaymentOnAssign();
      if (paymentDecision == null) return;
    }
    if (_saving) return;
    setState(() => _saving = true);
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
      setState(() {
        if (paymentDecision != null) {
          _selectedPaymentStatus = paymentDecision.$1;
          _selectedPaymentMethod = paymentDecision.$2;
        }
        _order = Order(
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
      });
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
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final agentsAsync = ref.watch(
      deliveryAgentsForBusinessProvider(_order.businessId),
    );
    final isBusinessOrder =
        _order.requesterType == OrderRequesterType.businessOwner;
    final requester = isBusinessOrder
        ? (_order.requesterBusinessName ?? _order.customerName)
        : _order.customerName;
    final includedCount = _itemIncluded.where((value) => value).length;
    final billing = _billingPreview();
    return Scaffold(
      appBar: AppBar(title: Text('Order ${_order.displayOrderNumber} Details')),
      body: ListView(
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
                        onPressed: _saving ? null : _acceptOrder,
                        child: const Text('Accept Order'),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  Text(
                    'Type: ${isBusinessOrder ? 'Business Order' : 'Customer Order'}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Text(
                    'Requested by: $requester',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Text(
                    'Priority: ${_order.priority.name}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Text(
                    'Status: ${_statusLabel(_order.status)}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Text(
                    'Delivery: ${_order.delivery.status.name}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Text(
                    'Payment: ${_paymentStatusLabel(_order.payment.status)} (${_paymentMethodLabel(_order.payment.method)}) • Amount: ${_formatAmount(_order.payment.amount)}',
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
                  if (_order.notes != null && _order.notes!.isNotEmpty)
                    Text(
                      'Notes: ${_order.notes}',
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
                          Text(
                            '${item.title} • Qty ${_formatQuantity(item.quantity)} ${_shortUnit(item.unit)}',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          CheckboxListTile(
                            contentPadding: EdgeInsets.zero,
                            dense: true,
                            controlAffinity: ListTileControlAffinity.leading,
                            value: included,
                            onChanged: (value) => setState(
                              () => _itemIncluded[index] = value ?? true,
                            ),
                            title: const Text('Include in Delivery'),
                          ),
                          if (!included)
                            TextFormField(
                              controller:
                                  _itemUnavailableReasonControllers[index],
                              decoration: const InputDecoration(
                                labelText: 'Unavailable Reason',
                                hintText: 'Not available',
                              ),
                              onChanged: (_) => setState(() {}),
                            ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: _itemPriceControllers[index],
                                  enabled: included,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                        decimal: true,
                                      ),
                                  decoration: const InputDecoration(
                                    labelText: 'Unit Price',
                                  ),
                                  onChanged: (_) => setState(() {}),
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
                                  onChanged: included
                                      ? (value) => setState(
                                          () => _itemGstIncluded[index] =
                                              value ?? false,
                                        )
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
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'Common GST %',
                            hintText: 'e.g. 18',
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _extraChargesController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'Extra Charges',
                            hintText: 'e.g. 50',
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                    ],
                  ),
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
                      onPressed: _saving ? null : _saveBilling,
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
                      if (!hasSelectedAgent) {
                        _selectedDeliveryAgentId = null;
                      }
                      return Column(
                        children: [
                          DropdownButtonFormField<String?>(
                            isExpanded: true,
                            initialValue: hasSelectedAgent
                                ? _selectedDeliveryAgentId
                                : null,
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
                            onChanged: (value) => setState(
                              () => _selectedDeliveryAgentId = value,
                            ),
                          ),
                          const SizedBox(height: 6),
                          CheckboxListTile(
                            contentPadding: EdgeInsets.zero,
                            dense: true,
                            value: _collectPaymentOnAssign,
                            title: const Text('Collect payment now (optional)'),
                            onChanged: (value) => setState(
                              () => _collectPaymentOnAssign = value ?? false,
                            ),
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton(
                              onPressed: _saving
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
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() => _selectedPaymentStatus = value);
                    },
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
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() => _selectedPaymentMethod = value);
                    },
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _paymentAmountController,
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
                      onPressed: _saving ? null : _saveStatusUpdates,
                      child: Text(_saving ? 'Saving...' : 'Update Payment'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_order.attachments.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              'Attachments',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            ..._order.attachments.map(
              (attachment) => ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  attachment.name,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                subtitle: Text(
                  attachment.url,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
