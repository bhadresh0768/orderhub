part of 'business_order_detail_screen.dart';

extension _BusinessOrderDetailBuild on _BusinessOrderDetailScreenState {
  Widget _buildContent(BuildContext context) {
    ref.watch(_businessOrderUiProvider(widget.order));
    final agentsAsync = ref.watch(
      deliveryAgentsForBusinessProvider(_order.businessId),
    );
    final isBusinessOrder =
        _order.requesterType == OrderRequesterType.businessOwner;
    final requester = isBusinessOrder
        ? (_order.requesterBusinessName ?? _order.customerName)
        : _order.customerName;
    final requestedAddress = _requestedByAddress();
    final requestedContact = _requestedByContact();
    final includedCount = _itemIncluded.where((value) => value).length;
    final billing = _billingPreview();
    final isLocked = _isLocked;
    final isAccepted = _isAccepted;
    final canEditAfterAccept = !isLocked && isAccepted;
    final missingIncludedPrice = _hasMissingIncludedUnitPrice();
    return Scaffold(
      appBar: AppBar(title: Text('Order ${_order.displayOrderNumber} Details')),
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
                    if (_order.status == OrderStatus.pending) ...[
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: (_saving || isLocked)
                              ? null
                              : _acceptOrder,
                          child: const Text('Accept Order'),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Accept this order first. Then you can add pricing and assign a delivery agent.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.red.shade300,
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                    if (isLocked) ...[
                      Text(
                        'Order is completed. Editing is disabled.',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              color: Colors.green,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                      const SizedBox(height: 8),
                    ],
                    Text(
                      'Type: ${isBusinessOrder ? 'Business Order' : 'Customer Order'}',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(
                      'Order by: $requester',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(
                      'Address: $requestedAddress',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    if (requestedContact != null)
                      Text(
                        'Contact: $requestedContact',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    Text(
                      'Priority: ${_capitalize(_order.priority.name)}',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text.rich(
                      TextSpan(
                        children: [
                          const TextSpan(text: 'Status: '),
                          TextSpan(
                            text: _statusLabel(_order.status),
                            style: TextStyle(
                              color: _orderStatusColor(_order.status),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text.rich(
                      TextSpan(
                        children: [
                          const TextSpan(text: 'Delivery: '),
                          TextSpan(
                            text: _capitalize(_order.delivery.status.name),
                            style: TextStyle(
                              color: _deliveryStatusColor(
                                _order.delivery.status,
                              ),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text.rich(
                      TextSpan(
                        children: [
                          const TextSpan(text: 'Payment: '),
                          TextSpan(
                            text:
                                '${_paymentStatusLabel(_order.payment.status)} (${_paymentMethodLabel(_order.payment.method)})',
                            style: TextStyle(
                              color: _paymentStatusColor(_order.payment.status),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const TextSpan(text: ' • Amount: '),
                          TextSpan(
                            text: _formatAmount(_order.payment.amount),
                            style: TextStyle(
                              color: _paymentStatusColor(_order.payment.status),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    if (_order.payment.collectedBy != null &&
                        _order.payment.status == PaymentStatus.done)
                      Text(
                        'Collected by: ${_order.payment.collectedBy == PaymentCollectedBy.deliveryBoy ? 'Delivery Boy' : 'Business'}'
                        '${(_order.payment.collectedByName ?? '').trim().isEmpty ? '' : ' (${_order.payment.collectedByName})'}',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    Text(
                      'Delivery Agent: ${_order.assignedDeliveryAgentName ?? 'Not assigned'}',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    if (_clean(_order.notes) != null)
                      Text(
                        'Order Remark: ${_clean(_order.notes)}',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              color: Colors.red.shade300,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    if (_clean(_order.delivery.note) != null)
                      Text(
                        'Delivery Remark: ${_clean(_order.delivery.note)}',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    if (_clean(_order.payment.remark) != null)
                      Text(
                        'Payment Remark: ${_clean(_order.payment.remark)}',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    if (_clean(_order.payment.collectionNote) != null)
                      Text(
                        'Delivery Boy Remark: ${_clean(_order.payment.collectionNote)}',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    const SizedBox(height: 8),
                    Text(
                      'Included Items: $includedCount / ${_order.items.length}',
                      style: Theme.of(context).textTheme.titleMedium,
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
                      'Item Pricing',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 10),
                    ..._order.items.asMap().entries.map((entry) {
                      final index = entry.key;
                      final item = entry.value;
                      final itemImageAttachments = item.attachments
                          .where(_isImageAttachment)
                          .toList();
                      final included = _itemIncluded[index];
                      final qty = item.quantity;
                      final unitPrice = _toDouble(
                        _itemPriceControllers[index].text,
                      );
                      final lineSubtotal = included ? qty * unitPrice : 0;
                      final lineGst =
                          included &&
                              _itemGstIncluded[index] &&
                              billing.gstPercent > 0
                          ? lineSubtotal * billing.gstPercent / 100
                          : 0.0;
                      final lineTotal = lineSubtotal + lineGst;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Text(
                                    '${item.title} • Qty ${_itemQuantityLabel(item)}',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.titleMedium,
                                  ),
                                ),
                                if (itemImageAttachments.isNotEmpty) ...[
                                  const SizedBox(width: 10),
                                  InkWell(
                                    onTap: () => _showImageGallery(
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
                                            errorBuilder: (_, _, _) => Container(
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
                                                alpha: 0.70,
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
                            const SizedBox(height: 4),
                            CheckboxListTile(
                              contentPadding: EdgeInsets.zero,
                              dense: true,
                              controlAffinity: ListTileControlAffinity.leading,
                              value: included,
                              onChanged: canEditAfterAccept
                                  ? (value) => _updateUi((state) {
                                      final updated = List<bool>.from(
                                        state.itemIncluded,
                                      );
                                      updated[index] = value ?? true;
                                      return state.copyWith(
                                        itemIncluded: updated,
                                      );
                                    })
                                  : null,
                              title: const Text('Include in Delivery'),
                            ),
                            if (!included)
                              TextFormField(
                                controller:
                                    _itemUnavailableReasonControllers[index],
                                enabled: canEditAfterAccept,
                                decoration: const InputDecoration(
                                  labelText: 'Unavailable Reason',
                                  hintText: 'Not available',
                                ),
                                onChanged: canEditAfterAccept
                                    ? (_) => _updateUi(
                                        (state) => state.copyWith(
                                          refreshTick: state.refreshTick + 1,
                                        ),
                                      )
                                    : null,
                              ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: _itemPriceControllers[index],
                                    enabled: included && canEditAfterAccept,
                                    onTap: () => _clearDefaultNumericOnTap(
                                      _itemPriceControllers[index],
                                    ),
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
                                          decimal: true,
                                        ),
                                    decoration: const InputDecoration(
                                      labelText: 'Unit Price',
                                    ),
                                    onChanged: canEditAfterAccept
                                        ? (_) => _updateUi(
                                            (state) => state.copyWith(
                                              refreshTick:
                                                  state.refreshTick + 1,
                                            ),
                                          )
                                        : null,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: CheckboxListTile(
                                    contentPadding: EdgeInsets.zero,
                                    dense: true,
                                    controlAffinity:
                                        ListTileControlAffinity.leading,
                                    value: _itemGstIncluded[index],
                                    onChanged: (included && canEditAfterAccept)
                                        ? (value) => _updateUi((state) {
                                            final updated = List<bool>.from(
                                              state.itemGstIncluded,
                                            );
                                            updated[index] = value ?? false;
                                            return state.copyWith(
                                              itemGstIncluded: updated,
                                            );
                                          })
                                        : null,
                                    title: const Text('GST'),
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              'Line Total: ${_formatAmount(lineTotal)}',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ],
                        ),
                      );
                    }),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _gstPercentController,
                            enabled: canEditAfterAccept,
                            onTap: () => _clearDefaultNumericOnTap(
                              _gstPercentController,
                            ),
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: const InputDecoration(
                              labelText: 'Common GST %',
                              hintText: 'e.g. 18',
                            ),
                            onChanged: canEditAfterAccept
                                ? (_) => _updateUi(
                                    (state) => state.copyWith(
                                      refreshTick: state.refreshTick + 1,
                                    ),
                                  )
                                : null,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _extraChargesController,
                            enabled: canEditAfterAccept,
                            onTap: () => _clearDefaultNumericOnTap(
                              _extraChargesController,
                            ),
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: const InputDecoration(
                              labelText: 'Extra Charges',
                              hintText: 'e.g. 50',
                            ),
                            onChanged: canEditAfterAccept
                                ? (_) => _updateUi(
                                    (state) => state.copyWith(
                                      refreshTick: state.refreshTick + 1,
                                    ),
                                  )
                                : null,
                          ),
                        ),
                      ],
                    ),
                    if (!isAccepted) ...[
                      const SizedBox(height: 6),
                      Text(
                        'Pricing is disabled until order is accepted.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.orange[800],
                        ),
                      ),
                    ],
                    if (canEditAfterAccept && missingIncludedPrice) ...[
                      const SizedBox(height: 6),
                      Text(
                        'Enter unit price for all included items to enable Save Pricing.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.red[700],
                        ),
                      ),
                    ],
                    const SizedBox(height: 10),
                    Text('Subtotal: ${_formatAmount(billing.subtotal)}'),
                    Text('GST Amount: ${_formatAmount(billing.gstAmount)}'),
                    Text(
                      'Grand Total: ${_formatAmount(billing.total)}',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed:
                            (_saving ||
                                !canEditAfterAccept ||
                                missingIncludedPrice)
                            ? null
                            : _saveBilling,
                        child: Text(_saving ? 'Saving...' : 'Save Pricing'),
                      ),
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
                      'Quick Status Update',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 12),
                    agentsAsync.when(
                      data: (agents) {
                        final activeAgents = agents
                            .where((agent) => agent.isActive)
                            .toList();
                        final hasSelectedAgent =
                            _selectedDeliveryAgentId == null ||
                            activeAgents.any(
                              (agent) => agent.id == _selectedDeliveryAgentId,
                            );
                        final selectedDeliveryAgentId = hasSelectedAgent
                            ? _selectedDeliveryAgentId
                            : null;
                        if (!hasSelectedAgent) {
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            _updateUi(
                              (state) =>
                                  state.copyWith(selectedDeliveryAgentId: null),
                            );
                          });
                        }
                        return Column(
                          children: [
                            DropdownButtonFormField<String?>(
                              isExpanded: true,
                              initialValue: selectedDeliveryAgentId,
                              decoration: const InputDecoration(
                                labelText: 'Assign Delivery Agent',
                              ),
                              items: [
                                const DropdownMenuItem<String?>(
                                  value: null,
                                  child: Text('Unassigned'),
                                ),
                                ...activeAgents.map(
                                  (agent) => DropdownMenuItem<String?>(
                                    value: agent.id,
                                    child: Text(
                                      '${agent.name} • ${agent.phone}',
                                    ),
                                  ),
                                ),
                              ],
                              onChanged: canEditAfterAccept
                                  ? (value) => _updateUi(
                                      (state) => state.copyWith(
                                        selectedDeliveryAgentId: value,
                                      ),
                                    )
                                  : null,
                            ),
                            const SizedBox(height: 6),
                            CheckboxListTile(
                              contentPadding: EdgeInsets.zero,
                              dense: true,
                              value: _collectPaymentOnAssign,
                              title: const Text(
                                'Collect payment now (optional)',
                              ),
                              onChanged: canEditAfterAccept
                                  ? (value) => _updateUi(
                                      (state) => state.copyWith(
                                        collectPaymentOnAssign: value ?? false,
                                      ),
                                    )
                                  : null,
                            ),
                            const SizedBox(height: 8),
                            if (canEditAfterAccept &&
                                selectedDeliveryAgentId == null)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    'Select a delivery agent to enable save.',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(color: Colors.red[700]),
                                  ),
                                ),
                              ),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton(
                                onPressed: _saving
                                    ? null
                                    : !canEditAfterAccept
                                    ? null
                                    : selectedDeliveryAgentId == null
                                    ? null
                                    : () => _assignDeliveryAgent(activeAgents),
                                child: const Text('Save Delivery Agent'),
                              ),
                            ),
                          ],
                        );
                      },
                      loading: () => const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: LinearProgressIndicator(),
                      ),
                      error: (err, _) =>
                          Text('Delivery agent load failed: $err'),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<PaymentStatus>(
                      isExpanded: true,
                      initialValue: _selectedPaymentStatus,
                      decoration: const InputDecoration(
                        labelText: 'Payment Status',
                      ),
                      items: PaymentStatus.values
                          .map(
                            (status) => DropdownMenuItem(
                              value: status,
                              child: Text(_paymentStatusLabel(status)),
                            ),
                          )
                          .toList(),
                      onChanged: canEditAfterAccept
                          ? (value) {
                              if (value == null) return;
                              _updateUi(
                                (state) => state.copyWith(
                                  selectedPaymentStatus: value,
                                ),
                              );
                            }
                          : null,
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<PaymentMethod>(
                      isExpanded: true,
                      initialValue: _selectedPaymentMethod,
                      decoration: const InputDecoration(
                        labelText: 'Payment Method',
                      ),
                      items: PaymentMethod.values
                          .map(
                            (method) => DropdownMenuItem(
                              value: method,
                              child: Text(_paymentMethodLabel(method)),
                            ),
                          )
                          .toList(),
                      onChanged: canEditAfterAccept
                          ? (value) {
                              if (value == null) return;
                              _updateUi(
                                (state) => state.copyWith(
                                  selectedPaymentMethod: value,
                                ),
                              );
                            }
                          : null,
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _paymentAmountController,
                      enabled: canEditAfterAccept,
                      onTap: () =>
                          _clearDefaultNumericOnTap(_paymentAmountController),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Order Amount',
                        hintText: 'e.g. 1250',
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: (_saving || !canEditAfterAccept)
                            ? null
                            : _saveStatusUpdates,
                        child: Text(_saving ? 'Saving...' : 'Update Payment'),
                      ),
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
