part of 'delivery_boy_home.dart';

extension _DeliveryBoyHomeOrdersList on _DeliveryBoyBodyState {
  Widget _buildOrdersList(
    BuildContext context,
    List<Order> orders, {
    required Map<String, String> businessAddressById,
    required bool allowActions,
    required String emptyText,
  }) {
    if (orders.isEmpty) {
      return Center(child: Text(emptyText));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: orders.length,
      itemBuilder: (context, index) {
        final order = orders[index];
        final items = order.items.map(_itemSummary).join(', ');
        final amount = order.payment.amount;
        final amountText = amount == null
            ? 'Not set'
            : (amount == amount.truncateToDouble()
                  ? amount.toInt().toString()
                  : amount.toStringAsFixed(2));
        final directAddress = (order.deliveryAddress ?? '').trim();
        final deliveryAddress = directAddress.isNotEmpty
            ? directAddress
            : (order.requesterType == OrderRequesterType.businessOwner
                  ? businessAddressById[order.requesterBusinessId] ?? '-'
                  : '-');
        final isFast = order.priority == OrderPriority.fast;
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: isFast
                ? BorderSide(color: Colors.red.shade400, width: 1.8)
                : BorderSide.none,
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${order.businessName} → ${order.customerName}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 6),
                Text(
                  'Order ${order.displayOrderNumber} • ${_capitalize(order.delivery.status.name)}',
                ),
                const SizedBox(height: 4),
                Text(
                  'Payment: ${_capitalize(order.payment.status.name)} • Amount: $amountText',
                ),
                const SizedBox(height: 4),
                Text('Address: $deliveryAddress'),
                if (order.payment.collectedBy != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      'Collected by: ${order.payment.collectedBy == PaymentCollectedBy.deliveryBoy ? 'Delivery Boy' : 'Business'}'
                      '${(order.payment.collectedByName ?? '').trim().isEmpty ? '' : ' (${order.payment.collectedByName})'}',
                    ),
                  ),
                const SizedBox(height: 4),
                Text('Items: $items'),
                if (allowActions) ...[
                  const SizedBox(height: 10),
                  FilledButton(
                    onPressed: () => _updateDeliveryStatus(
                      context,
                      ref,
                      order,
                      DeliveryStatus.delivered,
                    ),
                    child: const Text('Delivered'),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
