import 'package:android_intent_plus/android_intent.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../models/enums.dart';
import '../../../models/order.dart';
import '../../../providers.dart';
import 'common/order_shared_helpers.dart';

class CustomerOrderDetailScreen extends ConsumerWidget {
  const CustomerOrderDetailScreen({super.key, required this.order});

  final Order order;

  String _formatQty(double value) {
    return value == value.truncateToDouble()
        ? value.toInt().toString()
        : value.toStringAsFixed(2);
  }

  String _unitLabel(OrderItem item) {
    if (item.unit == QuantityUnit.other) {
      return item.displayUnitSymbol;
    }
    final unit = item.unit;
    return switch (unit) {
      QuantityUnit.piece => 'pc',
      QuantityUnit.box => 'box',
      QuantityUnit.kilogram => 'kg',
      QuantityUnit.gram => 'g',
      QuantityUnit.liter => 'L',
      QuantityUnit.ton => 't',
      QuantityUnit.packet => 'pkt',
      QuantityUnit.bag => 'bag',
      QuantityUnit.bottle => 'btl',
      QuantityUnit.can => 'can',
      QuantityUnit.meter => 'm',
      QuantityUnit.foot => 'ft',
      QuantityUnit.carton => 'ctn',
      QuantityUnit.other => item.displayUnitSymbol,
    };
  }

  String _itemQuantityLabel(OrderItem item) {
    final pack = (item.packSize ?? '').trim();
    if (pack.isNotEmpty) {
      final qty = _formatQty(item.quantity);
      final suffix = item.quantity == 1 ? 'pack' : 'packs';
      return '$qty $suffix ($pack)';
    }
    return '${_formatQty(item.quantity)} ${_unitLabel(item)}';
  }

  String _money(double? value) {
    if (value == null) return 'Not set';
    return value == value.truncateToDouble()
        ? value.toInt().toString()
        : value.toStringAsFixed(2);
  }

  String _statusLabel(OrderStatus status) {
    return switch (status) {
      OrderStatus.pending => 'Pending',
      OrderStatus.approved || OrderStatus.inProgress => 'Processing',
      OrderStatus.completed => 'Completed',
      OrderStatus.cancelled => 'Cancelled',
    };
  }

  String? _clean(String? value) {
    final text = value?.trim() ?? '';
    return text.isEmpty ? null : text;
  }

  String _capitalize(String value) {
    if (value.isEmpty) return value;
    return value[0].toUpperCase() + value.substring(1);
  }

  Widget _detailRow(
    BuildContext context, {
    required String label,
    required String value,
    Color? valueColor,
    FontWeight? valueWeight,
  }) {
    final labelStyle = Theme.of(
      context,
    ).textTheme.bodyMedium?.copyWith(color: Colors.black54);
    final rowValueStyle = Theme.of(context).textTheme.bodyLarge?.copyWith(
      color: valueColor ?? Colors.black87,
      fontWeight: valueWeight ?? FontWeight.w500,
      height: 1.25,
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 120, child: Text('$label:', style: labelStyle)),
          Expanded(child: Text(value, style: rowValueStyle)),
        ],
      ),
    );
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
    BuildContext context,
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

  Future<void> _callBusinessNow(BuildContext context, String phone) async {
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
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Call unavailable. Number copied to clipboard.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final liveOrderAsync = ref.watch(orderByIdProvider(order.id));
    final businessAsync = ref.watch(businessByIdProvider(order.businessId));
    final currentOrder = liveOrderAsync.asData?.value;
    if (currentOrder == null) {
      return Scaffold(
        appBar: AppBar(title: Text('Order ${order.displayOrderNumber}')),
        body: liveOrderAsync.when(
          data: (_) => const Center(child: Text('Order not found.')),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text('Failed to load latest order details: $err'),
            ),
          ),
        ),
      );
    }
    final effectiveStatus =
        currentOrder.delivery.status == DeliveryStatus.delivered
        ? OrderStatus.completed
        : currentOrder.status;
    final includedItems = currentOrder.items
        .where((e) => e.isIncluded ?? true)
        .toList();
    final unavailableItems = currentOrder.items
        .where((e) => !(e.isIncluded ?? true))
        .toList();
    final schedule = currentOrder.scheduledAt;
    final created = currentOrder.createdAt;
    final legacySplit = _splitLegacyAddress(currentOrder.deliveryAddress ?? '');
    final deliveryAddress = legacySplit.address;
    final businessCity = _clean(businessAsync.asData?.value?.city);
    final addressWithCity = switch ((deliveryAddress, businessCity)) {
      ('-', final city?) => city,
      (final address, null) => address,
      (final address, final city?) when address.contains(city) => address,
      (final address, final city?) => '$address, $city',
    };
    final businessPhone = businessAsync.asData?.value?.phone?.trim();
    final statusColor = OrderSharedHelpers.statusColor(effectiveStatus);

    return Scaffold(
      appBar: AppBar(title: Text('Order ${currentOrder.displayOrderNumber}')),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      currentOrder.businessName,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        Chip(
                          label: Text(_statusLabel(effectiveStatus)),
                          side: BorderSide.none,
                          backgroundColor: statusColor.withValues(alpha: 0.14),
                          labelStyle: TextStyle(
                            color: statusColor,
                            fontWeight: FontWeight.w700,
                          ),
                          visualDensity: VisualDensity.compact,
                        ),
                        Chip(
                          label: Text(
                            'Delivery ${_capitalize(currentOrder.delivery.status.name)}',
                          ),
                          side: BorderSide.none,
                          backgroundColor: Colors.blueGrey.withValues(
                            alpha: 0.12,
                          ),
                          labelStyle: const TextStyle(
                            color: Colors.black87,
                            fontWeight: FontWeight.w600,
                          ),
                          visualDensity: VisualDensity.compact,
                        ),
                        Chip(
                          label: Text(
                            'Payment ${_capitalize(currentOrder.payment.status.name)}',
                          ),
                          side: BorderSide.none,
                          backgroundColor: Colors.orange.withValues(
                            alpha: 0.12,
                          ),
                          labelStyle: const TextStyle(
                            color: Colors.black87,
                            fontWeight: FontWeight.w600,
                          ),
                          visualDensity: VisualDensity.compact,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _detailRow(
                      context,
                      label: 'Address',
                      value: addressWithCity,
                    ),
                    if ((businessPhone ?? '').isNotEmpty) ...[
                      _detailRow(
                        context,
                        label: 'Business Mobile',
                        value: businessPhone!,
                      ),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: OutlinedButton.icon(
                            onPressed: () =>
                                _callBusinessNow(context, businessPhone),
                            icon: const Icon(Icons.call_outlined),
                            label: const Text('Call Now'),
                          ),
                        ),
                      ),
                    ],
                    _detailRow(
                      context,
                      label: 'Amount',
                      value: _money(currentOrder.payment.amount),
                      valueColor: statusColor,
                      valueWeight: FontWeight.w700,
                    ),
                    const Divider(height: 20),
                    _detailRow(
                      context,
                      label: 'Order Created',
                      value: OrderSharedHelpers.formatDateTimeOrDash(created),
                    ),
                    _detailRow(
                      context,
                      label: 'Order Delivered',
                      value: OrderSharedHelpers.formatDateTimeOrDash(
                        currentOrder.delivery.deliveredAt,
                      ),
                    ),
                    _detailRow(
                      context,
                      label: 'Payment Date',
                      value: OrderSharedHelpers.formatDateTimeOrDash(
                        currentOrder.payment.collectedAt,
                      ),
                    ),
                    _detailRow(
                      context,
                      label: 'Scheduled',
                      value: OrderSharedHelpers.formatDateTimeOrDash(schedule),
                    ),
                    if (_clean(currentOrder.notes) != null)
                      _detailRow(
                        context,
                        label: 'Order Remark',
                        value: _clean(currentOrder.notes)!,
                      ),
                    if (_clean(currentOrder.delivery.note) != null)
                      _detailRow(
                        context,
                        label: 'Delivery Remark',
                        value: _clean(currentOrder.delivery.note)!,
                      ),
                    if (_clean(currentOrder.payment.remark) != null)
                      _detailRow(
                        context,
                        label: 'Payment Remark',
                        value: _clean(currentOrder.payment.remark)!,
                      ),
                    if (_clean(currentOrder.payment.collectionNote) != null)
                      _detailRow(
                        context,
                        label: 'Delivery Boy Remark',
                        value: _clean(currentOrder.payment.collectionNote)!,
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
                      'Items',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    if (includedItems.isEmpty)
                      const Text('No items included for delivery.')
                    else
                      ...includedItems.asMap().entries.map((entry) {
                        final index = entry.key;
                        final item = entry.value;
                        final itemImageAttachments = item.attachments
                            .where(_isImageAttachment)
                            .toList();
                        final lineSubtotal =
                            (item.unitPrice ?? 0) * item.quantity;
                        final lineGst =
                            (item.gstIncluded ?? false) &&
                                (currentOrder.gstPercent ?? 0) > 0
                            ? lineSubtotal * (currentOrder.gstPercent! / 100)
                            : 0.0;
                        final lineTotal = lineSubtotal + lineGst;
                        final subtitleParts = [
                          if ((item.note ?? '').trim().isNotEmpty)
                            item.note!.trim(),
                          if (item.unitPrice != null)
                            'Price: ${_money(item.unitPrice)} • Subtotal: ${_money(lineTotal)}',
                        ];
                        return Padding(
                          padding: EdgeInsets.only(
                            bottom: index == includedItems.length - 1 ? 0 : 12,
                          ),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.black.withValues(alpha: 0.08),
                              ),
                              color: Theme.of(context).colorScheme.surface,
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '${item.title} ${_itemQuantityLabel(item)}',
                                        style: Theme.of(
                                          context,
                                        ).textTheme.titleMedium,
                                      ),
                                      if (subtitleParts.isNotEmpty) ...[
                                        const SizedBox(height: 6),
                                        Text(subtitleParts.join('\n')),
                                      ],
                                    ],
                                  ),
                                ),
                                if (itemImageAttachments.isNotEmpty) ...[
                                  const SizedBox(width: 10),
                                  InkWell(
                                    onTap: () => _showImageGallery(
                                      context,
                                      itemImageAttachments,
                                      0,
                                    ),
                                    borderRadius: BorderRadius.circular(10),
                                    child: Stack(
                                      children: [
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                          child: Image.network(
                                            itemImageAttachments.first.url,
                                            width: 72,
                                            height: 72,
                                            fit: BoxFit.cover,
                                            errorBuilder: (_, _, _) =>
                                                Container(
                                                  width: 72,
                                                  height: 72,
                                                  color: Colors.black12,
                                                  alignment: Alignment.center,
                                                  child: const Icon(
                                                    Icons
                                                        .image_not_supported_outlined,
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
                                                alpha: 0.7,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(999),
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
                          ),
                        );
                      }),
                  ],
                ),
              ),
            ),
            if (unavailableItems.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                'Unavailable Items',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              ...unavailableItems.map(
                (item) => Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: const Icon(
                      Icons.info_outline,
                      color: Colors.orange,
                    ),
                    title: Text(item.title),
                    subtitle: Text(
                      (item.unavailableReason ?? '').trim().isEmpty
                          ? 'Not available'
                          : item.unavailableReason!.trim(),
                    ),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Billing',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text('Subtotal: ${_money(currentOrder.subtotalAmount)}'),
                    Text('GST %: ${_money(currentOrder.gstPercent)}'),
                    Text('GST Amount: ${_money(currentOrder.gstAmount)}'),
                    Text('Extra Charges: ${_money(currentOrder.extraCharges)}'),
                    Text(
                      'Grand Total: ${_money(currentOrder.totalAmount ?? currentOrder.payment.amount)}',
                      style: Theme.of(context).textTheme.titleMedium,
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
