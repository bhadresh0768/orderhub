part of 'business_order_detail_screen.dart';

extension _BusinessOrderDetailActions on _BusinessOrderDetailScreenState {
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
          content: Text(
            'Enter unit price for all included items before saving',
          ),
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
        const SnackBar(content: Text('Select a delivery agent first')),
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
}
