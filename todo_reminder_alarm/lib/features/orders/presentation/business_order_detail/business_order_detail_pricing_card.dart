part of 'business_order_detail_screen.dart';

extension _BusinessOrderDetailPricingCard on _BusinessOrderDetailScreenState {
  Widget _buildItemPricingCard(BuildContext context) {
    final billing = _billingPreview();
    final isLocked = _isLocked;
    final isAccepted = _isAccepted;
    final canEditAfterAccept = !isLocked && isAccepted;
    final missingIncludedPrice = _hasMissingIncludedUnitPrice();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Item Pricing', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 10),
            if (isLocked) ...[
              ..._order.items.asMap().entries.map((entry) {
                final index = entry.key;
                final item = entry.value;
                final included = _itemIncluded[index];
                final qty = item.quantity;
                final unitPrice = _toDouble(_itemPriceControllers[index].text);
                final lineSubtotal = included ? qty * unitPrice : 0;
                final lineGst =
                    included && _itemGstIncluded[index] && billing.gstPercent > 0
                    ? lineSubtotal * billing.gstPercent / 100
                    : 0.0;
                final lineTotal = lineSubtotal + lineGst;
                final unavailable =
                    _itemUnavailableReasonControllers[index].text.trim();
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.02),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${item.title} • Qty ${_itemQuantityLabel(item)}',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _detailRow(
                        context,
                        'Included',
                        included ? 'Yes' : 'No',
                        valueColor: included
                            ? const Color(0xFF1A7F47)
                            : const Color(0xFFC4432A),
                        valueWeight: FontWeight.w700,
                      ),
                      if (!included && unavailable.isNotEmpty)
                        _detailRow(context, 'Unavailable', unavailable),
                      _detailRow(
                        context,
                        'Unit Price',
                        _formatAmount(included ? unitPrice : null),
                      ),
                      _detailRow(
                        context,
                        'GST',
                        _itemGstIncluded[index] ? 'Included' : 'No',
                      ),
                      _detailRow(
                        context,
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
                    child: _metricTile(
                      context,
                      'Common GST %',
                      _formatAmount(billing.gstPercent),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _metricTile(
                      context,
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
                    child: _metricTile(
                      context,
                      'Subtotal',
                      _formatAmount(billing.subtotal),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _metricTile(
                      context,
                      'GST Amount',
                      _formatAmount(billing.gstAmount),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _metricTile(
                context,
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
                final unitPrice = _toDouble(_itemPriceControllers[index].text);
                final lineSubtotal = included ? qty * unitPrice : 0;
                final lineGst =
                    included && _itemGstIncluded[index] && billing.gstPercent > 0
                    ? lineSubtotal * billing.gstPercent / 100
                    : 0.0;
                final lineTotal = lineSubtotal + lineGst;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
                      color: Theme.of(context).colorScheme.surface,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                '${item.title} • Qty ${_itemQuantityLabel(item)}',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                            ),
                            if (itemImageAttachments.isNotEmpty) ...[
                              const SizedBox(width: 10),
                              InkWell(
                                onTap: () => _showImageGallery(itemImageAttachments, 0),
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
                                          color: Colors.black.withValues(alpha: 0.70),
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
                        const SizedBox(height: 4),
                        CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                          controlAffinity: ListTileControlAffinity.leading,
                          value: included,
                          onChanged: canEditAfterAccept
                              ? (value) => _updateUi((state) {
                                  final updated = List<bool>.from(state.itemIncluded);
                                  updated[index] = value ?? true;
                                  return state.copyWith(itemIncluded: updated);
                                })
                              : null,
                          title: const Text('Include in Delivery'),
                        ),
                        if (!included)
                          TextFormField(
                            controller: _itemUnavailableReasonControllers[index],
                            enabled: canEditAfterAccept,
                            textCapitalization: TextCapitalization.sentences,
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
                                keyboardType: const TextInputType.numberWithOptions(
                                  decimal: true,
                                ),
                                decoration: const InputDecoration(
                                  labelText: 'Unit Price',
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
                              child: CheckboxListTile(
                                contentPadding: EdgeInsets.zero,
                                dense: true,
                                controlAffinity: ListTileControlAffinity.leading,
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
                          'Subtotal: ${_formatAmount(lineTotal)}',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
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
                      onTap: () => _clearDefaultNumericOnTap(_gstPercentController),
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
                      onTap: () => _clearDefaultNumericOnTap(_extraChargesController),
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
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: Colors.orange[800]),
                ),
              ],
              if (canEditAfterAccept && missingIncludedPrice) ...[
                const SizedBox(height: 6),
                Text(
                  'Enter unit price for all included items to enable Save Pricing.',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: Colors.red[700]),
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
                      (_saving || !canEditAfterAccept || missingIncludedPrice)
                      ? null
                      : _saveBilling,
                  child: Text(_saving ? 'Saving...' : 'Save Pricing'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
