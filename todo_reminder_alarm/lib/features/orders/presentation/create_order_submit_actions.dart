part of 'create_order_screen.dart';

extension _CreateOrderSubmitActions on _CreateOrderScreenState {
  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_ui.items.isEmpty) {
      _updateUi(
        (state) =>
            state.copyWith(inlineError: 'At least one item is required.'),
      );
      return;
    }
    _updateUi((state) => state.copyWith(loading: true, inlineError: null));

    final savedAddresses =
        ref.read(deliveryAddressesProvider(widget.customer.id)).asData?.value ??
        const <DeliveryAddressEntry>[];
    DeliveryAddressEntry? selectedDeliveryAddress;
    for (final entry in savedAddresses) {
      if (entry.id == _ui.deliveryAddressRef) {
        selectedDeliveryAddress = entry;
        break;
      }
    }
    final deliveryAddressLabel = _ui.deliveryAddressRef == _profileAddressRef
        ? _defaultAddressLabel()
        : selectedDeliveryAddress?.label;
    final deliveryAddress = _ui.deliveryAddressRef == _profileAddressRef
        ? _defaultAddressText()
        : selectedDeliveryAddress?.fullAddress;
    final deliveryContactName = _ui.deliveryAddressRef == _profileAddressRef
        ? null
        : selectedDeliveryAddress?.contactPerson;
    final selectedAddressPhone = selectedDeliveryAddress?.contactPhone?.trim();
    final profilePhone = widget.customer.phoneNumber?.trim();
    final deliveryContactPhone = _ui.deliveryAddressRef == _profileAddressRef
        ? profilePhone
        : (selectedAddressPhone?.isNotEmpty ?? false)
        ? selectedAddressPhone
        : profilePhone;

    final firestore = ref.read(firestoreServiceProvider);
    final requesterBusiness = widget.requesterBusiness;
    final existing = widget.existingOrder;
    try {
      if (existing == null) {
        final order = Order(
          id: _draftOrderId,
          businessId: widget.business.id,
          businessName: widget.business.name,
          customerId: widget.customer.id,
          customerName: widget.customer.name,
          requesterType: requesterBusiness == null
              ? OrderRequesterType.customer
              : OrderRequesterType.businessOwner,
          requesterBusinessId: requesterBusiness?.id,
          requesterBusinessName: requesterBusiness?.name,
          deliveryAddressLabel: deliveryAddressLabel,
          deliveryAddress: deliveryAddress,
          deliveryContactName: deliveryContactName,
          deliveryContactPhone: deliveryContactPhone,
          priority: _ui.priority,
          status: OrderStatus.pending,
          payment: PaymentInfo(
            status: PaymentStatus.pending,
            method: _ui.paymentMethod,
            amount: null,
            remark: _paymentRemarkController.text.trim().isEmpty
                ? null
                : _paymentRemarkController.text.trim(),
            confirmedByCustomer:
                _ui.paymentMethod == PaymentMethod.onlineTransfer
                ? _ui.confirmedOnline
                : null,
            updatedAt: DateTime.now(),
          ),
          delivery: DeliveryInfo(
            status: DeliveryStatus.pending,
            updatedAt: DateTime.now(),
          ),
          items: _ui.items,
          attachments: const [],
          packedItemIndexes: const [],
          notes: _notesController.text.trim().isEmpty
              ? null
              : _notesController.text.trim(),
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        await firestore.createOrder(order);
      } else {
        if (existing.status != OrderStatus.pending) {
          _updateUi(
            (state) =>
                state.copyWith(inlineError: 'Only new orders can be edited.'),
          );
          return;
        }
        final updatedPayment = existing.payment.copyWith(
          method: _ui.paymentMethod,
          remark: _paymentRemarkController.text.trim().isEmpty
              ? null
              : _paymentRemarkController.text.trim(),
          confirmedByCustomer: _ui.paymentMethod == PaymentMethod.onlineTransfer
              ? _ui.confirmedOnline
              : null,
          updatedAt: DateTime.now(),
        );
        await firestore.updateOrder(existing.id, {
          'priority': enumToString(_ui.priority),
          'items': _ui.items.map((item) => item.toMap()).toList(),
          'deliveryAddressLabel': deliveryAddressLabel,
          'deliveryAddress': deliveryAddress,
          'deliveryContactName': deliveryContactName,
          'deliveryContactPhone': deliveryContactPhone,
          'payment': updatedPayment.toMap(),
          'notes': _notesController.text.trim().isEmpty
              ? null
              : _notesController.text.trim(),
        });
      }
      if (mounted) {
        final resultLabel = existing == null
            ? 'Order for ${widget.business.name}'
            : 'Order ${existing.displayOrderNumber}';
        Navigator.of(context).pop(resultLabel);
      }
    } catch (err) {
      _updateUi(
        (state) => state.copyWith(
          inlineError:
              'Failed to ${existing == null ? 'place' : 'update'} order: $err',
        ),
      );
    } finally {
      if (mounted) {
        _updateUi((state) => state.copyWith(loading: false));
      }
    }
  }
}
