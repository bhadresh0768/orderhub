import 'package:flutter/material.dart';

import '../../../models/enums.dart';
import '../../../models/order.dart';

class CustomerOrderDetailScreen extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final effectiveStatus = order.delivery.status == DeliveryStatus.delivered
        ? OrderStatus.completed
        : order.status;
    final includedItems = order.items.where((e) => e.isIncluded ?? true).toList();
    final unavailableItems = order.items.where((e) => !(e.isIncluded ?? true)).toList();
    final itemAttachments = order.items.expand((item) => item.attachments).toList();
    final allAttachments = <OrderAttachment>[
      ...order.attachments,
      ...itemAttachments,
    ];
    final imageAttachments = allAttachments.where(_isImageAttachment).toList();
    final schedule = order.scheduledAt;
    final created = order.createdAt;
    final statusColor = switch (effectiveStatus) {
      OrderStatus.completed => Colors.green,
      OrderStatus.pending => Colors.red,
      _ => Colors.yellow.shade800,
    };

    return Scaffold(
      appBar: AppBar(title: Text('Order ${order.displayOrderNumber}')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    order.businessName,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
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
                  Text('Payment: ${order.payment.status.name}'),
                  Text('Delivery: ${order.delivery.status.name}'),
                  Text('Amount: ${_money(order.payment.amount)}'),
                  Text(
                    'Created: ${created == null ? '-' : created.toLocal().toString()}',
                  ),
                  Text(
                    'Scheduled: ${schedule == null ? '-' : schedule.toLocal().toString()}',
                  ),
                  if (_clean(order.notes) != null)
                    Text('Order Remark: ${_clean(order.notes)}'),
                  if (_clean(order.delivery.note) != null)
                    Text('Delivery Remark: ${_clean(order.delivery.note)}'),
                  if (_clean(order.payment.remark) != null)
                    Text('Payment Remark: ${_clean(order.payment.remark)}'),
                  if (_clean(order.payment.collectionNote) != null)
                    Text(
                      'Delivery Boy Remark: ${_clean(order.payment.collectionNote)}',
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
              final lineSubtotal = (item.unitPrice ?? 0) * item.quantity;
              final lineGst = (item.gstIncluded ?? false) && (order.gstPercent ?? 0) > 0
                  ? lineSubtotal * (order.gstPercent! / 100)
                  : 0.0;
              final lineTotal = lineSubtotal + lineGst;
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  title: Text(
                    '${item.title} ${_formatQty(item.quantity)} ${_unitLabel(item.unit)}',
                  ),
                  subtitle: Text(
                    [
                      if ((item.packSize ?? '').trim().isNotEmpty)
                        'Pack: ${item.packSize!.trim()}',
                      if ((item.note ?? '').trim().isNotEmpty) item.note!.trim(),
                      if (item.unitPrice != null)
                        'Price: ${_money(item.unitPrice)} • Line: ${_money(lineTotal)}',
                    ].join('\n'),
                  ),
                  isThreeLine: true,
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
                  leading: const Icon(Icons.info_outline, color: Colors.orange),
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
                  Text('Billing', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 8),
                  Text('Subtotal: ${_money(order.subtotalAmount)}'),
                  Text('GST %: ${_money(order.gstPercent)}'),
                  Text('GST Amount: ${_money(order.gstAmount)}'),
                  Text('Extra Charges: ${_money(order.extraCharges)}'),
                  Text(
                    'Grand Total: ${_money(order.totalAmount ?? order.payment.amount)}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ],
              ),
            ),
          ),
          if (imageAttachments.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              'Item Images',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: imageAttachments.asMap().entries.map((entry) {
                final index = entry.key;
                final attachment = entry.value;
                return InkWell(
                  onTap: () =>
                      _showImageGallery(context, imageAttachments, index),
                  borderRadius: BorderRadius.circular(10),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.network(
                      attachment.url,
                      width: 92,
                      height: 92,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => Container(
                        width: 92,
                        height: 92,
                        color: Colors.black12,
                        alignment: Alignment.center,
                        child: const Icon(Icons.image_not_supported_outlined),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }
}
