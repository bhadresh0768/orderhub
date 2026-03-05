import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

  String _unitLabel(QuantityUnit unit) {
    return switch (unit) {
      QuantityUnit.piece => 'pc',
      QuantityUnit.kilogram => 'kg',
      QuantityUnit.gram => 'g',
      QuantityUnit.liter => 'L',
    };
  }

  String _itemQuantityLabel(OrderItem item) {
    final pack = (item.packSize ?? '').trim();
    if (pack.isNotEmpty) {
      final qty = _formatQty(item.quantity);
      final suffix = item.quantity == 1 ? 'pack' : 'packs';
      return '$qty $suffix ($pack)';
    }
    return '${_formatQty(item.quantity)} ${_unitLabel(item.unit)}';
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final liveOrderAsync = ref.watch(orderByIdProvider(order.id));
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
    final contactName = (currentOrder.deliveryContactName ?? '').trim();
    final contactPhone = (currentOrder.deliveryContactPhone ?? '').trim();
    final deliveryContact = contactName.isNotEmpty && contactPhone.isNotEmpty
        ? '$contactName ($contactPhone)'
        : contactName.isNotEmpty
        ? contactName
        : contactPhone.isNotEmpty
        ? contactPhone
        : legacySplit.contact;
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
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      currentOrder.businessName,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text('Address: $deliveryAddress'),
                    if (deliveryContact != null)
                      Text('Contact: $deliveryContact'),
                    Text.rich(
                      TextSpan(
                        children: [
                          const TextSpan(text: 'Status: '),
                          TextSpan(
                            text: _statusLabel(effectiveStatus),
                            style: TextStyle(
                              color: statusColor,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      'Payment: ${_capitalize(currentOrder.payment.status.name)}',
                    ),
                    Text(
                      'Delivery: ${_capitalize(currentOrder.delivery.status.name)}',
                    ),
                    Text('Amount: ${_money(currentOrder.payment.amount)}'),
                    Text(
                      'Created: ${created == null ? '-' : created.toLocal().toString()}',
                    ),
                    Text(
                      'Scheduled: ${schedule == null ? '-' : schedule.toLocal().toString()}',
                    ),
                    if (_clean(currentOrder.notes) != null)
                      Text('Order Remark: ${_clean(currentOrder.notes)}'),
                    if (_clean(currentOrder.delivery.note) != null)
                      Text(
                        'Delivery Remark: ${_clean(currentOrder.delivery.note)}',
                      ),
                    if (_clean(currentOrder.payment.remark) != null)
                      Text(
                        'Payment Remark: ${_clean(currentOrder.payment.remark)}',
                      ),
                    if (_clean(currentOrder.payment.collectionNote) != null)
                      Text(
                        'Delivery Boy Remark: ${_clean(currentOrder.payment.collectionNote)}',
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text('Items', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            if (includedItems.isEmpty)
              const Text('No items included for delivery.')
            else
              ...includedItems.map((item) {
                final itemImageAttachments = item.attachments
                    .where(_isImageAttachment)
                    .toList();
                final lineSubtotal = (item.unitPrice ?? 0) * item.quantity;
                final lineGst =
                    (item.gstIncluded ?? false) &&
                        (currentOrder.gstPercent ?? 0) > 0
                    ? lineSubtotal * (currentOrder.gstPercent! / 100)
                    : 0.0;
                final lineTotal = lineSubtotal + lineGst;
                final subtitleParts = [
                  if ((item.note ?? '').trim().isNotEmpty) item.note!.trim(),
                  if (item.unitPrice != null)
                    'Price: ${_money(item.unitPrice)} • Line: ${_money(lineTotal)}',
                ];
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${item.title} ${_itemQuantityLabel(item)}',
                                style: Theme.of(context).textTheme.titleMedium,
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
                                        alpha: 0.7,
                                      ),
                                      borderRadius: BorderRadius.circular(999),
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
