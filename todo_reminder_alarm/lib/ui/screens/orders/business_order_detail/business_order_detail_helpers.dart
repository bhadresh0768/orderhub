part of 'business_order_detail_screen.dart';

extension _BusinessOrderDetailHelpers on _BusinessOrderDetailScreenState {
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

  bool _isDefaultNumericValue(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return false;
    final parsed = double.tryParse(trimmed);
    return parsed != null && parsed == 0;
  }

  void _clearDefaultNumericOnTap(TextEditingController controller) {
    if (_tapClearedControllers.contains(controller)) return;
    if (_isDefaultNumericValue(controller.text)) {
      controller.clear();
      _tapClearedControllers.add(controller);
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
      final businessAsync = ref.watch(
        businessByIdProvider(requesterBusinessId),
      );
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

  ({
    double subtotal,
    double gstAmount,
    double total,
    double gstPercent,
    double extra,
  })
  _billingPreview() {
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
}
