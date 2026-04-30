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
    final requestedPhone = _requestedByPhone();
    final showContact =
        requestedContact != null &&
        (!_isSamePhoneContact(requestedContact, requestedPhone));
    final includedCount = _itemIncluded.where((value) => value).length;
    final billing = _billingPreview();
    final isLocked = _isLocked;
    final isAccepted = _isAccepted;
    final canEditAfterAccept = !isLocked && isAccepted;
    final missingIncludedPrice = _hasMissingIncludedUnitPrice();
    final labelStyle = Theme.of(
      context,
    ).textTheme.bodyMedium?.copyWith(color: Colors.black54);
    final valueStyle = Theme.of(
      context,
    ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w500, height: 1.25);
    Widget detailRow(
      String label,
      String value, {
      Color? valueColor,
      FontWeight? valueWeight,
    }) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: 120, child: Text('$label:', style: labelStyle)),
            Expanded(
              child: Text(
                value,
                style: valueStyle?.copyWith(
                  color: valueColor,
                  fontWeight: valueWeight,
                ),
              ),
            ),
          ],
        ),
      );
    }

    Widget metricTile(String label, String value, {bool emphasize = false}) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: Colors.black54),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: emphasize ? FontWeight.w700 : FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Order ${_order.displayOrderNumber} Details'),
        actions: [
          IconButton(
            tooltip: 'Share order details',
            onPressed: _shareOrderDetails,
            icon: const Icon(Icons.share_outlined),
          ),
          IconButton(
            tooltip: 'Share on WhatsApp',
            onPressed: _shareOrderDetailsOnWhatsApp,
            icon: ClipOval(
              child: Image.asset(
                'assets/images/whatsapp_share.png',
                width: 24,
                height: 24,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) =>
                    const Icon(Icons.chat, color: Colors.green),
              ),
            ),
          ),
        ],
      ),
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
                    detailRow(
                      'Type',
                      isBusinessOrder ? 'Business Order' : 'Customer Order',
                    ),
                    detailRow('Order by', requester),
                    detailRow('Address', requestedAddress),
                    if (showContact) detailRow('Contact', requestedContact),
                    if (requestedPhone != null) ...[
                      detailRow('Mobile', requestedPhone),
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
                    detailRow('Priority', _capitalize(_order.priority.name)),
                    detailRow(
                      'Amount',
                      _formatAmount(_order.payment.amount),
                      valueColor: _paymentStatusColor(_order.payment.status),
                      valueWeight: FontWeight.w700,
                    ),
                    detailRow(
                      'Delivery Agent',
                      _order.assignedDeliveryAgentName ?? 'Not assigned',
                    ),
                    const Divider(height: 20),
                    detailRow(
                      'Order Created',
                      OrderSharedHelpers.formatDateTimeOrDash(_order.createdAt),
                    ),
                    detailRow(
                      'Order Delivered',
                      OrderSharedHelpers.formatDateTimeOrDash(
                        _order.delivery.deliveredAt,
                      ),
                    ),
                    detailRow(
                      'Payment Date',
                      OrderSharedHelpers.formatDateTimeOrDash(
                        _order.payment.collectedAt,
                      ),
                    ),
                    detailRow(
                      'Payment Method',
                      _paymentMethodLabel(_order.payment.method),
                    ),
                    if (_order.payment.collectedBy != null &&
                        _order.payment.status == PaymentStatus.done)
                      detailRow(
                        'Collected by',
                        '${_order.payment.collectedBy == PaymentCollectedBy.deliveryBoy ? 'Delivery Boy' : 'Business'}'
                            '${(_order.payment.collectedByName ?? '').trim().isEmpty ? '' : ' (${_order.payment.collectedByName})'}',
                      ),
                    if (_clean(_order.notes) != null)
                      detailRow(
                        'Order Remark',
                        _clean(_order.notes)!,
                        valueColor: Colors.red.shade400,
                        valueWeight: FontWeight.w600,
                      ),
                    if (_clean(_order.delivery.note) != null)
                      detailRow(
                        'Delivery Remark',
                        _clean(_order.delivery.note)!,
                      ),
                    if (_clean(_order.payment.remark) != null)
                      detailRow(
                        'Payment Remark',
                        _clean(_order.payment.remark)!,
                      ),
                    if (_clean(_order.payment.collectionNote) != null)
                      detailRow(
                        'Delivery Boy Remark',
                        _clean(_order.payment.collectionNote)!,
                      ),
                    const SizedBox(height: 8),
                    Text(
                      'Included Items: $includedCount / ${_order.items.length}',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
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
                      'Item Pricing',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 10),
                    if (isLocked) ...[
                      ..._order.items.asMap().entries.map((entry) {
                        final index = entry.key;
                        final item = entry.value;
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
                        final unavailable =
                            _itemUnavailableReasonControllers[index].text
                                .trim();
                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.02),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.black.withValues(alpha: 0.08),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${item.title} • Qty ${_itemQuantityLabel(item)}',
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(height: 8),
                              detailRow(
                                'Included',
                                included ? 'Yes' : 'No',
                                valueColor: included
                                    ? const Color(0xFF1A7F47)
                                    : const Color(0xFFC4432A),
                                valueWeight: FontWeight.w700,
                              ),
                              if (!included && unavailable.isNotEmpty)
                                detailRow('Unavailable', unavailable),
                              detailRow(
                                'Unit Price',
                                _formatAmount(included ? unitPrice : null),
                              ),
                              detailRow(
                                'GST',
                                _itemGstIncluded[index] ? 'Included' : 'No',
                              ),
                              detailRow(
                                'Subtotal',
                                _formatAmount(lineTotal),
                                valueWeight: FontWeight.w700,
                              ),
                            ],
                          ),
                        );
                      }),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Expanded(
                            child: metricTile(
                              'Common GST %',
                              _formatAmount(billing.gstPercent),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: metricTile(
                              'Extra Charges',
                              _formatAmount(billing.extra),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: metricTile(
                              'Subtotal',
                              _formatAmount(billing.subtotal),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: metricTile(
                              'GST Amount',
                              _formatAmount(billing.gstAmount),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      metricTile(
                        'Grand Total',
                        _formatAmount(billing.total),
                        emphasize: true,
                      ),
                    ] else ...[
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
                                              padding:
                                                  const EdgeInsets.symmetric(
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
                                controlAffinity:
                                    ListTileControlAffinity.leading,
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
                                  textCapitalization:
                                      TextCapitalization.sentences,
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
                                      onChanged:
                                          (included && canEditAfterAccept)
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
                                'Subtotal: ${_formatAmount(lineTotal)}',
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
                              keyboardType:
                                  const TextInputType.numberWithOptions(
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
                              keyboardType:
                                  const TextInputType.numberWithOptions(
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
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: Colors.orange[800]),
                        ),
                      ],
                      if (canEditAfterAccept && missingIncludedPrice) ...[
                        const SizedBox(height: 6),
                        Text(
                          'Enter unit price for all included items to enable Save Pricing.',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: Colors.red[700]),
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
