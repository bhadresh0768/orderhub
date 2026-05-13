part of 'business_order_detail_screen.dart';

extension _BusinessOrderDetailSummaryCard on _BusinessOrderDetailScreenState {
  Widget _buildOrderSummaryCard(BuildContext context) {
    final isBusinessOrder =
        _order.requesterType == OrderRequesterType.businessOwner;
    final requester = isBusinessOrder
        ? (_order.requesterBusinessName ?? _order.customerName)
        : _order.customerName;
    final requestedAddress = _requestedByAddress();
    final requestedContact = _requestedByContact();
    final requestedPhone = _requestedByPhone();
    final showContact =
        requestedContact != null &&
        (!_isSamePhoneContact(requestedContact, requestedPhone));
    final includedCount = _itemIncluded.where((value) => value).length;
    final isLocked = _isLocked;

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_order.status == OrderStatus.pending) ...[
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: (_saving || isLocked) ? null : _acceptOrder,
                  child: const Text('Accept Order'),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Accept this order first. Then you can add pricing and assign a delivery agent.',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: Colors.red.shade300),
              ),
              const SizedBox(height: 8),
            ],
            if (isLocked) ...[
              Text(
                'Order is completed. Editing is disabled.',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.green,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
            ],
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Chip(
                  label: Text(_statusLabel(_order.status)),
                  side: BorderSide.none,
                  backgroundColor: _orderStatusColor(
                    _order.status,
                  ).withValues(alpha: 0.14),
                  labelStyle: TextStyle(
                    color: _orderStatusColor(_order.status),
                    fontWeight: FontWeight.w700,
                  ),
                  visualDensity: VisualDensity.compact,
                ),
                Chip(
                  label: Text(
                    'Delivery ${_capitalize(_order.delivery.status.name)}',
                  ),
                  side: BorderSide.none,
                  backgroundColor: _deliveryStatusColor(
                    _order.delivery.status,
                  ).withValues(alpha: 0.14),
                  labelStyle: TextStyle(
                    color: _deliveryStatusColor(_order.delivery.status),
                    fontWeight: FontWeight.w700,
                  ),
                  visualDensity: VisualDensity.compact,
                ),
                Chip(
                  label: Text(
                    'Payment ${_paymentStatusLabel(_order.payment.status)}',
                  ),
                  side: BorderSide.none,
                  backgroundColor: _paymentStatusColor(
                    _order.payment.status,
                  ).withValues(alpha: 0.14),
                  labelStyle: TextStyle(
                    color: _paymentStatusColor(_order.payment.status),
                    fontWeight: FontWeight.w700,
                  ),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            const SizedBox(height: 12),
            _detailRow(
              context,
              'Type',
              isBusinessOrder ? 'Business Order' : 'Customer Order',
            ),
            _detailRow(context, 'Order by', requester),
            _detailRow(context, 'Address', requestedAddress),
            if (showContact) _detailRow(context, 'Contact', requestedContact),
            if (requestedPhone != null) ...[
              _detailRow(context, 'Mobile', requestedPhone),
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton.icon(
                    onPressed: () => _callCustomerNow(requestedPhone),
                    icon: const Icon(Icons.call_outlined),
                    label: const Text('Call Now'),
                  ),
                ),
              ),
            ],
            _detailRow(context, 'Priority', _capitalize(_order.priority.name)),
            _detailRow(
              context,
              'Amount',
              _formatCurrency(_order.payment.amount),
              valueColor: _paymentStatusColor(_order.payment.status),
              valueWeight: FontWeight.w700,
            ),
            _detailRow(
              context,
              'Delivery Agent',
              _order.assignedDeliveryAgentName ?? 'Not assigned',
            ),
            const Divider(height: 20),
            _detailRow(
              context,
              'Order Created',
              OrderSharedHelpers.formatDateTimeOrDash(_order.createdAt),
            ),
            _detailRow(
              context,
              'Order Delivered',
              OrderSharedHelpers.formatDateTimeOrDash(_order.delivery.deliveredAt),
            ),
            _detailRow(
              context,
              'Payment Date',
              OrderSharedHelpers.formatDateTimeOrDash(_order.payment.collectedAt),
            ),
            _detailRow(
              context,
              'Payment Method',
              _paymentMethodLabel(_order.payment.method),
            ),
            if (_order.payment.collectedBy != null &&
                _order.payment.status == PaymentStatus.done)
              _detailRow(
                context,
                'Collected by',
                '${_order.payment.collectedBy == PaymentCollectedBy.deliveryBoy ? 'Delivery Boy' : 'Business'}'
                    '${(_order.payment.collectedByName ?? '').trim().isEmpty ? '' : ' (${_order.payment.collectedByName})'}',
              ),
            if (_clean(_order.notes) != null)
              _detailRow(
                context,
                'Order Remark',
                _clean(_order.notes)!,
                valueColor: Colors.red.shade400,
                valueWeight: FontWeight.w600,
              ),
            if (_clean(_order.delivery.note) != null)
              _detailRow(
                context,
                'Delivery Remark',
                _clean(_order.delivery.note)!,
              ),
            if (_clean(_order.payment.remark) != null)
              _detailRow(context, 'Payment Remark', _clean(_order.payment.remark)!),
            if (_clean(_order.payment.collectionNote) != null)
              _detailRow(
                context,
                'Delivery Boy Remark',
                _clean(_order.payment.collectionNote)!,
              ),
            const SizedBox(height: 8),
            Text(
              'Included Items: $includedCount / ${_order.items.length}',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}
