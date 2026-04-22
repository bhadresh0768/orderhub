part of 'business_order_detail_screen.dart';

extension _BusinessOrderDetailHelpers on _BusinessOrderDetailScreenState {
  String _formatQuantity(double value) {
    return value == value.truncateToDouble()
        ? value.toInt().toString()
        : value.toStringAsFixed(2);
  }

  String _shortUnit(OrderItem item) {
    if (item.unit == QuantityUnit.other) {
      return item.displayUnitSymbol;
    }
    final unit = item.unit;
    switch (unit) {
      case QuantityUnit.piece:
        return 'pc';
      case QuantityUnit.box:
        return 'box';
      case QuantityUnit.kilogram:
        return 'kg';
      case QuantityUnit.gram:
        return 'g';
      case QuantityUnit.liter:
        return 'L';
      case QuantityUnit.ton:
        return 't';
      case QuantityUnit.packet:
        return 'pkt';
      case QuantityUnit.bag:
        return 'bag';
      case QuantityUnit.bottle:
        return 'btl';
      case QuantityUnit.can:
        return 'can';
      case QuantityUnit.meter:
        return 'm';
      case QuantityUnit.foot:
        return 'ft';
      case QuantityUnit.carton:
        return 'ctn';
      case QuantityUnit.other:
        return item.displayUnitSymbol;
    }
  }

  String _itemQuantityLabel(OrderItem item) {
    final pack = (item.packSize ?? '').trim();
    if (pack.isNotEmpty) {
      final qty = _formatQuantity(item.quantity);
      final suffix = item.quantity == 1 ? 'pack' : 'packs';
      return '$qty $suffix ($pack)';
    }
    return '${_formatQuantity(item.quantity)} ${_shortUnit(item)}';
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
    return OrderSharedHelpers.statusColor(status);
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
    String appendCityIfMissing(String address, String city) {
      final cleanAddress = address.trim();
      final cleanCity = city.trim();
      if (cleanAddress.isEmpty) return cleanCity;
      if (cleanCity.isEmpty) return cleanAddress;
      if (cleanAddress.toLowerCase().contains(cleanCity.toLowerCase())) {
        return cleanAddress;
      }
      return '$cleanAddress, $cleanCity';
    }

    final ownBusiness =
        ref.watch(businessByIdProvider(_order.businessId)).asData?.value;
    final ownCity = (ownBusiness?.city ?? '').trim();

    final direct = (_order.deliveryAddress ?? '').trim();
    if (direct.isNotEmpty) {
      final split = _splitLegacyAddress(direct).address;
      return appendCityIfMissing(split, ownCity);
    }

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
    if (ownCity.isNotEmpty) return ownCity;
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

  String? _extractPhoneFromText(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return null;

    final bracketMatch = RegExp(r'\(([^()]+)\)\s*$').firstMatch(text);
    final candidate = (bracketMatch?.group(1) ?? text).trim();
    final digits = _digitsOnly(candidate);
    if (digits.length < 7) return null;
    return candidate;
  }

  bool _isSamePhoneContact(String? contact, String? phone) {
    final contactPhone = _extractPhoneFromText(contact);
    final directPhone = phone?.trim();
    if (contactPhone == null || directPhone == null || directPhone.isEmpty) {
      return false;
    }
    return _digitsOnly(contactPhone) == _digitsOnly(directPhone);
  }

  String? _requestedByPhone() {
    final directPhone = (_order.deliveryContactPhone ?? '').trim();
    if (directPhone.isNotEmpty) return directPhone;

    final direct = (_order.deliveryAddress ?? '').trim();
    if (direct.isNotEmpty) {
      final legacyPhone = _extractPhoneFromText(
        _splitLegacyAddress(direct).contact,
      );
      if (legacyPhone != null) return legacyPhone;
    }
    return null;
  }

  Future<void> _callCustomerNow(String phone) async {
    final normalizedPhone = phone.trim();
    if (normalizedPhone.isEmpty) return;

    final uri = Uri(scheme: 'tel', path: normalizedPhone);
    try {
      final launched = await launchUrl(uri);
      if (launched) return;
    } catch (_) {}

    try {
      final intent = AndroidIntent(
        action: 'android.intent.action.DIAL',
        data: 'tel:$normalizedPhone',
      );
      await intent.launch();
      return;
    } catch (_) {}

    await Clipboard.setData(ClipboardData(text: normalizedPhone));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Call unavailable. Number copied to clipboard.'),
      ),
    );
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

  String _digitsOnly(String value) => value.replaceAll(RegExp(r'[^0-9]'), '');

  String _buildOrderShareDetailsText() {
    final isBusinessOrder =
        _order.requesterType == OrderRequesterType.businessOwner;
    final requester = isBusinessOrder
        ? (_order.requesterBusinessName ?? _order.customerName)
        : _order.customerName;
    final requestedAddress = _requestedByAddress();
    final requestedContact = _requestedByContact();
    final paymentCollector =
        _order.payment.collectedBy == null ||
            _order.payment.status != PaymentStatus.done
        ? null
        : (_order.payment.collectedBy == PaymentCollectedBy.deliveryBoy
              ? 'Delivery Boy'
              : 'Business');
    final items = _order.items
        .asMap()
        .entries
        .map((entry) {
          final index = entry.key;
          final item = entry.value;
          final include = _itemIncluded[index] ? 'Included' : 'Excluded';
          final unitPriceText = _itemPriceControllers[index].text.trim().isEmpty
              ? 'Not set'
              : _itemPriceControllers[index].text.trim();
          final gstText = _itemGstIncluded[index] ? 'GST: Yes' : 'GST: No';
          final unavailableReason = (item.unavailableReason ?? '').trim();
          final note = (item.note ?? '').trim();
          return '- ${item.title} | Qty: ${_itemQuantityLabel(item)} | $include | Unit Price: $unitPriceText | $gstText'
              '${unavailableReason.isEmpty ? '' : ' | Unavailable: $unavailableReason'}'
              '${note.isEmpty ? '' : ' | Note: $note'}';
        })
        .join('\n');

    final billing = _billingPreview();
    final orderNote = (_order.notes ?? '').trim();
    final deliveryNote = (_order.delivery.note ?? '').trim();
    final paymentNote = (_order.payment.remark ?? '').trim();

    return '''
Order ${_order.displayOrderNumber} Details
Business: ${_order.businessName}
Type: ${isBusinessOrder ? 'Business Order' : 'Customer Order'}
Order by: $requester
Address: $requestedAddress
${requestedContact == null ? '' : 'Contact: $requestedContact\n'}Status: ${_statusLabel(_order.status)}
Delivery: ${_capitalize(_order.delivery.status.name)}
Payment: ${_paymentStatusLabel(_order.payment.status)} (${_paymentMethodLabel(_order.payment.method)})
Amount: ${_formatAmount(_order.payment.amount)}
${paymentCollector == null ? '' : 'Collected By: $paymentCollector\n'}Delivery Agent: ${_order.assignedDeliveryAgentName ?? 'Not assigned'}
Included Items: ${_itemIncluded.where((e) => e).length} / ${_order.items.length}
Subtotal: ${_formatAmount(billing.subtotal)}
GST %: ${billing.gstPercent.toStringAsFixed(2)}
GST Amount: ${_formatAmount(billing.gstAmount)}
Extra Charges: ${_formatAmount(billing.extra)}
Total: ${_formatAmount(billing.total)}
${orderNote.isEmpty ? '' : 'Order Remark: $orderNote\n'}${deliveryNote.isEmpty ? '' : 'Delivery Remark: $deliveryNote\n'}${paymentNote.isEmpty ? '' : 'Payment Remark: $paymentNote\n'}
Items:
$items
'''
        .trim();
  }

  Future<void> _shareOrderDetails() async {
    final text = _buildOrderShareDetailsText();
    try {
      final intent = AndroidIntent(
        action: 'android.intent.action.SEND',
        type: 'text/plain',
        arguments: {'android.intent.extra.TEXT': text},
      );
      await intent.launchChooser('Share order details');
    } catch (_) {
      await Clipboard.setData(ClipboardData(text: text));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Share unavailable. Order details copied.'),
        ),
      );
    }
  }

  Future<void> _shareOrderDetailsOnWhatsApp() async {
    final contactPhone = (_order.deliveryContactPhone ?? '').trim();
    final digits = _digitsOnly(contactPhone);
    final text = Uri.encodeComponent(_buildOrderShareDetailsText());
    final url = digits.isEmpty
        ? 'https://wa.me/?text=$text'
        : 'https://wa.me/$digits?text=$text';
    try {
      final intent = AndroidIntent(
        action: 'android.intent.action.VIEW',
        data: url,
      );
      await intent.launch();
    } catch (_) {
      await Clipboard.setData(
        ClipboardData(text: _buildOrderShareDetailsText()),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('WhatsApp unavailable. Order details copied.'),
        ),
      );
    }
  }
}
