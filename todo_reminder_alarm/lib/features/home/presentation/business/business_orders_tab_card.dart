part of 'business_home.dart';

extension _BusinessOrdersTabCard on _BusinessOrdersTabState {
  Widget _buildOrderCard(BuildContext context, Order order) {
    final colorScheme = Theme.of(context).colorScheme;
    final isBusinessOrder =
        order.requesterType == OrderRequesterType.businessOwner;
    final sourceLabel = isBusinessOrder ? 'Business Order' : 'Customer Order';
    final requestedBy = isBusinessOrder
        ? (order.requesterBusinessName ?? order.customerName)
        : order.customerName;
    final customerShopName = _customerShopName(order);
    final requestedAddress = _requestedByAddress(order);
    final paymentCollector = _paymentCollectorLabel(order);
    final paymentDone = order.payment.status == PaymentStatus.done;
    final paymentLabel = paymentDone
        ? 'Payment Done${paymentCollector == null ? '' : ' • $paymentCollector'}'
        : 'Payment Pending';
    final paymentBg = paymentDone ? Colors.blueGrey.shade50 : Colors.red.shade100;
    final paymentFg = paymentDone ? Colors.blueGrey.shade800 : Colors.red.shade800;
    final deliveryDelivered = order.delivery.status == DeliveryStatus.delivered;
    final deliveryLabel = OrderSharedHelpers.capitalize(order.delivery.status.name);
    final deliveryBg = deliveryDelivered ? Colors.green.shade100 : Colors.grey.shade200;
    final deliveryFg = deliveryDelivered ? Colors.green.shade700 : Colors.grey.shade800;
    final amountText = OrderSharedHelpers.amountLabel(order.payment.amount);
    final isFast = order.priority == OrderPriority.fast;
    final priorityColor = isFast ? Colors.red : colorScheme.onSurface;
    final cardIconColor = Colors.grey.shade600;
    final orderDateLabel = order.createdAt == null
        ? null
        : OrderSharedHelpers.formatDateTime(order.createdAt!);
    final canApprove = order.status == OrderStatus.pending;
    final canMarkDelivered =
        order.status == OrderStatus.approved ||
        order.status == OrderStatus.inProgress;
    final canSetPaymentDone =
        order.status != OrderStatus.pending &&
        order.payment.status != PaymentStatus.done;
    final canShowActionMenu =
        widget.allowActions &&
        (canApprove || canMarkDelivered || canSetPaymentDone);
    return OrderCardShell(
      isHighlighted: isFast,
      margin: const EdgeInsets.only(bottom: 14),
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => BusinessOrderDetailScreen(order: order),
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    'Order ${order.displayOrderNumber} • $sourceLabel',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                canShowActionMenu
                    ? PopupMenuButton<String>(
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        icon: Icon(
                          Icons.more_vert_rounded,
                          color: colorScheme.onSurface.withValues(alpha: 0.75),
                        ),
                        onSelected: (value) => _handleOrderAction(context, order, value),
                        itemBuilder: (context) {
                          return [
                            if (canApprove)
                              const PopupMenuItem(
                                value: 'approve',
                                child: Text('Approve Order'),
                              ),
                            if (canMarkDelivered)
                              const PopupMenuItem(
                                value: 'mark_delivered',
                                child: Text('Mark Delivered'),
                              ),
                            if (canSetPaymentDone)
                              const PopupMenuItem(
                                value: 'payment_done',
                                child: Text('Set Payment Done'),
                              ),
                          ];
                        },
                      )
                    : const Icon(Icons.chevron_right),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(Icons.schedule, size: 18, color: cardIconColor),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    orderDateLabel ?? '-',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(Icons.person_outline, size: 18, color: cardIconColor),
                const SizedBox(width: 6),
                Expanded(child: Text(requestedBy)),
              ],
            ),
            if (!isBusinessOrder && customerShopName != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.storefront_outlined, size: 18, color: cardIconColor),
                  const SizedBox(width: 6),
                  Expanded(child: Text(customerShopName)),
                ],
              ),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.location_on_outlined, size: 18, color: cardIconColor),
                const SizedBox(width: 6),
                Expanded(child: Text(requestedAddress)),
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
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
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
                Icon(Icons.local_shipping_outlined, size: 18, color: cardIconColor),
                const SizedBox(width: 6),
                Expanded(
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: paymentBg,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Text(
                          paymentLabel,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: paymentFg,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: deliveryBg,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Text(
                          deliveryLabel,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
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
            if ((order.notes ?? '').trim().isNotEmpty) ...[
              Text(
                'Remark: ${order.notes!.trim()}',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFFB54708),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
            ],
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
