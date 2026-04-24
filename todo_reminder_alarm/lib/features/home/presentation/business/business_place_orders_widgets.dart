part of 'business_home.dart';

class _BusinessOrderSourceCard extends StatelessWidget {
  const _BusinessOrderSourceCard({
    required this.business,
    required this.isFavorite,
    required this.titleStyle,
    required this.cardPadding,
    required this.onToggleFavorite,
    required this.onOpenCatalog,
    required this.onOpenStoreProfile,
    this.onPlaceOrder,
  });

  final BusinessProfile business;
  final bool isFavorite;
  final TextStyle? titleStyle;
  final double cardPadding;
  final Future<void> Function() onToggleFavorite;
  final Future<void> Function() onOpenCatalog;
  final VoidCallback onOpenStoreProfile;
  final Future<void> Function()? onPlaceOrder;

  @override
  Widget build(BuildContext context) {
    final ownerName = (business.ownerName ?? '').trim();
    return Card(
      child: Padding(
        padding: EdgeInsets.all(cardPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          business.name,
                          style: titleStyle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        tooltip: isFavorite
                            ? 'Remove from favorites'
                            : 'Pin to favorites',
                        onPressed: onToggleFavorite,
                        icon: Icon(
                          isFavorite ? Icons.push_pin : Icons.push_pin_outlined,
                          color: isFavorite
                              ? Theme.of(context).colorScheme.primary
                              : Colors.grey.shade600,
                        ),
                        iconSize: 20,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                  if (ownerName.isNotEmpty) ...[
                    Text(
                      'By $ownerName',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.black54,
                        fontSize:
                            ((Theme.of(context).textTheme.bodySmall?.fontSize ??
                                12) +
                            3),
                      ),
                    ),
                  ],
                  const SizedBox(height: 2),
                  Wrap(
                    spacing: 6,
                    children: [
                      Chip(
                        visualDensity: VisualDensity.compact,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        label: Text(business.category),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${(business.address ?? '').trim().isEmpty ? '-' : business.address!.trim()}, ${business.city}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    onPressed: onPlaceOrder,
                    child: const Text('Place Order'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: onOpenCatalog,
                    child: const Text('Catalog'),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 52,
                  child: IconButton(
                    onPressed: onOpenStoreProfile,
                    iconSize: 30,
                    icon: const Icon(Icons.storefront_outlined),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PlacedOutgoingOrderCard extends StatelessWidget {
  const _PlacedOutgoingOrderCard({
    required this.order,
    required this.canEdit,
    required this.onEditOrder,
    required this.onDeleteOrder,
    required this.onOpenOrderDetail,
  });

  final Order order;
  final bool canEdit;
  final Future<void> Function() onEditOrder;
  final Future<void> Function() onDeleteOrder;
  final VoidCallback onOpenOrderDetail;

  @override
  Widget build(BuildContext context) {
    final isFast = order.priority == OrderPriority.fast;
    final priorityColor = isFast
        ? Colors.red
        : Theme.of(context).colorScheme.onSurface;
    final cardIconColor = Colors.grey.shade600;
    final orderDateLabel = order.createdAt == null
        ? null
        : OrderSharedHelpers.formatDateTime(order.createdAt!);
    final paymentDone = order.payment.status == PaymentStatus.done;
    final paymentLabel = paymentDone ? 'Payment Done' : 'Payment Pending';
    final paymentBg = paymentDone
        ? Colors.blueGrey.shade50
        : Colors.red.shade100;
    final paymentFg = paymentDone
        ? Colors.blueGrey.shade800
        : Colors.red.shade800;
    final deliveryDelivered = order.delivery.status == DeliveryStatus.delivered;
    final deliveryLabel = OrderSharedHelpers.capitalize(
      order.delivery.status.name,
    );
    final deliveryBg = deliveryDelivered
        ? Colors.green.shade100
        : Colors.grey.shade200;
    final deliveryFg = deliveryDelivered
        ? Colors.green.shade700
        : Colors.grey.shade800;
    final amountText = OrderSharedHelpers.amountLabel(order.payment.amount);

    return OrderCardShell(
      isHighlighted: isFast,
      onTap: onOpenOrderDetail,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 10, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          order.businessName,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                PopupMenuButton<String>(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  iconSize: 22,
                  iconColor: cardIconColor,
                  tooltip: canEdit
                      ? 'Order actions'
                      : 'Locked: accepted orders cannot be edited/deleted',
                  onSelected: (value) async {
                    if (value == 'edit') {
                      await onEditOrder();
                    } else if (value == 'delete') {
                      await onDeleteOrder();
                    }
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(
                      value: '__help__',
                      enabled: false,
                      child: Text('Editable only while order is New'),
                    ),
                    PopupMenuItem(
                      value: 'edit',
                      enabled: canEdit,
                      child: const Text('Edit Order'),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      enabled: canEdit,
                      child: const Text('Delete Order'),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Icon(
                        Icons.receipt_long_outlined,
                        size: 18,
                        color: cardIconColor,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          order.displayOrderNumber,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                if (orderDateLabel != null)
                  Expanded(
                    child: Row(
                      children: [
                        Icon(Icons.schedule, size: 18, color: cardIconColor),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            orderDateLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  isFast ? Icons.bolt_outlined : Icons.speed_outlined,
                  size: 18,
                  color: cardIconColor,
                ),
                const SizedBox(width: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: priorityColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    OrderSharedHelpers.capitalize(order.priority.name),
                    style: TextStyle(
                      color: priorityColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(
                  Icons.local_shipping_outlined,
                  size: 18,
                  color: cardIconColor,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: paymentBg,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Text(
                          paymentLabel,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: paymentFg,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: deliveryBg,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Text(
                          deliveryLabel,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: deliveryFg,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Divider(height: 1, color: Colors.grey.shade200),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                'Amount: $amountText',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
