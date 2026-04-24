part of 'create_order_screen.dart';

extension _CreateOrderScreenBody on _CreateOrderScreenState {
  Widget _buildCreateOrderScaffold(BuildContext context) {
    final ui = ref.watch(_createOrderUiProvider(_draftOrderId));
    final deliveryAddressesAsync = ref.watch(
      deliveryAddressesProvider(widget.customer.id),
    );
    final unitsAsync = ref.watch(orderUnitsProvider);
    final firebaseUnits = unitsAsync.asData?.value ?? const <OrderUnit>[];
    final availableUnits = _mergedOrderUnits(firebaseUnits);
    final selectedUnit = _resolveSelectedUnit(availableUnits);
    final dropdownUnits = availableUnits
        .where((unit) => unit.code != selectedUnit.code)
        .toList();
    dropdownUnits.insert(0, selectedUnit);
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.existingOrder == null
              ? 'Order ${widget.business.name}'
              : 'Edit Order ${widget.existingOrder!.displayOrderNumber}',
        ),
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.requesterBusiness == null
                            ? 'Requester: ${widget.customer.name}'
                            : 'Requester: ${widget.requesterBusiness!.name} (Business Owner)',
                      ),
                      const SizedBox(height: 12),
                      deliveryAddressesAsync.when(
                        data: (addresses) {
                          if (!_defaultDeliveryAddressInitialized) {
                            _defaultDeliveryAddressInitialized = true;
                            final defaultEntry = addresses
                                .where((e) => e.isDefault)
                                .firstOrNull;
                            if (defaultEntry != null &&
                                _ui.deliveryAddressRef == _profileAddressRef) {
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                if (!mounted) return;
                                _updateUi(
                                  (state) => state.copyWith(
                                    deliveryAddressRef: defaultEntry.id,
                                  ),
                                );
                              });
                            }
                          }
                          final selectedRef =
                              addresses.any(
                                (entry) => entry.id == ui.deliveryAddressRef,
                              )
                              ? ui.deliveryAddressRef
                              : _profileAddressRef;
                          final addressLabels = <String, String>{
                            _profileAddressRef:
                                '${_defaultAddressLabel()} • ${_defaultAddressText()}',
                            for (final entry in addresses)
                              entry.id: '${entry.label} • ${entry.fullAddress}',
                          };
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              DropdownButtonFormField<String>(
                                key: ValueKey(selectedRef),
                                initialValue: selectedRef,
                                isExpanded: true,
                                decoration: const InputDecoration(
                                  labelText: 'Delivery Address',
                                ),
                                items: addressLabels.entries
                                    .map(
                                      (entry) => DropdownMenuItem<String>(
                                        value: entry.key,
                                        child: Text(
                                          entry.value,
                                          overflow: TextOverflow.ellipsis,
                                          maxLines: 1,
                                        ),
                                      ),
                                    )
                                    .toList(),
                                selectedItemBuilder: (context) => addressLabels
                                    .values
                                    .map(
                                      (label) => Align(
                                        alignment: Alignment.centerLeft,
                                        child: Text(
                                          label,
                                          overflow: TextOverflow.ellipsis,
                                          maxLines: 1,
                                        ),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (value) {
                                  if (value == null) return;
                                  _updateUi(
                                    (state) => state.copyWith(
                                      deliveryAddressRef: value,
                                      inlineError: null,
                                    ),
                                  );
                                },
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  OutlinedButton.icon(
                                    onPressed: () =>
                                        _showDeliveryAddressBottomSheet(
                                          hasAnySavedAddress:
                                              addresses.isNotEmpty,
                                        ),
                                    icon: const Icon(
                                      Icons.add_location_alt_outlined,
                                    ),
                                    label: const Text('Add Address'),
                                  ),
                                  if (selectedRef != _profileAddressRef)
                                    OutlinedButton.icon(
                                      onPressed: () {
                                        final editing = addresses.firstWhere(
                                          (entry) => entry.id == selectedRef,
                                        );
                                        _showDeliveryAddressBottomSheet(
                                          existing: editing,
                                          hasAnySavedAddress:
                                              addresses.isNotEmpty,
                                        );
                                      },
                                      icon: const Icon(
                                        Icons.edit_location_alt_outlined,
                                      ),
                                      label: const Text('Edit Selected'),
                                    ),
                                  if (selectedRef != _profileAddressRef)
                                    OutlinedButton.icon(
                                      onPressed: () {
                                        final deleting = addresses.firstWhere(
                                          (entry) => entry.id == selectedRef,
                                        );
                                        _deleteDeliveryAddress(deleting);
                                      },
                                      icon: const Icon(Icons.delete_outline),
                                      label: const Text('Delete Selected'),
                                    ),
                                ],
                              ),
                            ],
                          );
                        },
                        loading: () =>
                            const LinearProgressIndicator(minHeight: 2),
                        error: (_, _) => Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Address book temporarily unavailable. Please retry.',
                              style: TextStyle(color: Colors.red),
                            ),
                            const SizedBox(height: 8),
                            OutlinedButton.icon(
                              onPressed: () => ref.invalidate(
                                deliveryAddressesProvider(widget.customer.id),
                              ),
                              icon: const Icon(Icons.refresh),
                              label: const Text('Retry'),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _itemController,
                        textCapitalization: TextCapitalization.words,
                        onChanged: _onItemQueryChanged,
                        decoration: const InputDecoration(
                          labelText: 'Item / Service',
                        ),
                      ),
                      if (ui.loadingSuggestions) ...[
                        const SizedBox(height: 8),
                        const LinearProgressIndicator(minHeight: 2),
                      ],
                      if (ui.itemSuggestions.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Container(
                          constraints: const BoxConstraints(maxHeight: 220),
                          decoration: BoxDecoration(
                            color: Theme.of(
                              context,
                            ).colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: ListView.builder(
                            shrinkWrap: true,
                            itemCount: ui.itemSuggestions.length,
                            itemBuilder: (context, index) {
                              final suggestion = ui.itemSuggestions[index];
                              return ListTile(
                                dense: true,
                                title: Text(suggestion),
                                onTap: () => _selectSuggestion(suggestion),
                              );
                            },
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _quantityController,
                        decoration: const InputDecoration(
                          labelText: 'Quantity',
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _packSizeController,
                        textCapitalization: TextCapitalization.words,
                        decoration: const InputDecoration(
                          labelText: 'Pack Size (optional)',
                          hintText: 'e.g. 1 L pouch, 500 g pack',
                        ),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: selectedUnit.code,
                        decoration: const InputDecoration(labelText: 'Unit'),
                        items: dropdownUnits
                            .map(
                              (entry) => DropdownMenuItem<String>(
                                value: entry.code,
                                child: Text(entry.displayLabel),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          if (value == null) return;
                          final picked = dropdownUnits
                              .where((unit) => unit.code == value)
                              .firstOrNull;
                          _updateUi(
                            (state) => state.copyWith(
                              itemUnitCode: value,
                              itemUnitLabel: picked?.label,
                              itemUnitSymbol: picked?.symbol,
                            ),
                          );
                        },
                      ),
                      if (unitsAsync.isLoading)
                        const Padding(
                          padding: EdgeInsets.only(top: 8),
                          child: LinearProgressIndicator(minHeight: 2),
                        ),
                      if (unitsAsync.hasError)
                        const Padding(
                          padding: EdgeInsets.only(top: 8),
                          child: Text(
                            'Units sync failed. Showing built-in units.',
                            style: TextStyle(color: Colors.red),
                          ),
                        ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _itemNoteController,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: const InputDecoration(
                          labelText: 'Item Note (optional)',
                        ),
                      ),
                      const SizedBox(height: 8),
                      FilledButton.tonalIcon(
                        onPressed: ui.uploadingItemImage
                            ? null
                            : _showItemImageSourceSheet,
                        icon: const Icon(Icons.add_a_photo_outlined),
                        label: Text(
                          ui.uploadingItemImage
                              ? 'Uploading...'
                              : 'Upload Item Image',
                        ),
                      ),
                      if (ui.itemAttachmentsDraft.isNotEmpty)
                        Column(
                          children: ui.itemAttachmentsDraft.asMap().entries.map(
                            (entry) {
                              final index = entry.key;
                              final attachment = entry.value;
                              return ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.network(
                                    attachment.url,
                                    width: 40,
                                    height: 40,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, _, _) => const Icon(
                                      Icons.image_not_supported_outlined,
                                    ),
                                  ),
                                ),
                                title: Text(
                                  attachment.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                trailing: IconButton(
                                  icon: const Icon(Icons.delete_outline),
                                  onPressed: () {
                                    final updated = [...ui.itemAttachmentsDraft]
                                      ..removeAt(index);
                                    _updateUi(
                                      (state) => state.copyWith(
                                        itemAttachmentsDraft: updated,
                                      ),
                                    );
                                  },
                                ),
                              );
                            },
                          ).toList(),
                        ),
                      const SizedBox(height: 8),
                      FilledButton.tonal(
                        onPressed: () => _addOrUpdateItem(availableUnits),
                        style: ui.editingItemIndex != null
                            ? FilledButton.styleFrom(
                                backgroundColor: Colors.red.shade100,
                                foregroundColor: Colors.red.shade800,
                              )
                            : null,
                        child: Text(
                          ui.editingItemIndex == null
                              ? 'Add Item'
                              : 'Update Item',
                        ),
                      ),
                      if (ui.editingItemIndex != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            'Tap "Update Item" to save item changes.',
                            style: TextStyle(
                              color: Colors.red.shade400,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      if (ui.editingItemIndex != null)
                        TextButton(
                          onPressed: _clearItemForm,
                          child: const Text('Cancel Edit'),
                        ),
                      const SizedBox(height: 8),
                      if (ui.items.isNotEmpty)
                        Column(
                          children: ui.items.asMap().entries.map((entry) {
                            final index = entry.key;
                            final item = entry.value;
                            final conversion = _conversionHint(item);
                            final imageCount = item.attachments.length;
                            return ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: imageCount == 0
                                  ? null
                                  : InkWell(
                                      borderRadius: BorderRadius.circular(8),
                                      onTap: () => _showItemImageGallery(
                                        item.attachments,
                                        initialIndex: 0,
                                      ),
                                      child: Stack(
                                        clipBehavior: Clip.none,
                                        children: [
                                          ClipRRect(
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                            child: Image.network(
                                              item.attachments.first.url,
                                              width: 48,
                                              height: 48,
                                              fit: BoxFit.cover,
                                              errorBuilder: (_, _, _) => Container(
                                                width: 48,
                                                height: 48,
                                                alignment: Alignment.center,
                                                decoration: BoxDecoration(
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                  color: Theme.of(context)
                                                      .colorScheme
                                                      .surfaceContainerHighest,
                                                ),
                                                child: const Icon(
                                                  Icons
                                                      .image_not_supported_outlined,
                                                  size: 20,
                                                ),
                                              ),
                                            ),
                                          ),
                                          if (imageCount > 1)
                                            Positioned(
                                              right: -6,
                                              top: -6,
                                              child: Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 5,
                                                      vertical: 1,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: Colors.black87,
                                                  borderRadius:
                                                      BorderRadius.circular(10),
                                                ),
                                                child: Text(
                                                  '$imageCount',
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                              title: Text(
                                '${item.title}, Qty - ${_itemQuantityLabel(item)}',
                              ),
                              subtitle: Text(
                                [
                                  if (item.packSize != null &&
                                      item.packSize!.isNotEmpty)
                                    'Pack: ${item.packSize!}',
                                  if (item.note != null &&
                                      item.note!.isNotEmpty)
                                    item.note!,
                                  if (conversion != null) '~ $conversion',
                                ].join('  '),
                              ),
                              trailing: Wrap(
                                spacing: 0,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.edit_outlined),
                                    onPressed: () => _editItem(index),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline),
                                    onPressed: () {
                                      final updatedItems = [...ui.items]
                                        ..removeAt(index);
                                      final currentEditing =
                                          ui.editingItemIndex;
                                      int? nextEditing = currentEditing;
                                      if (currentEditing == index) {
                                        nextEditing = null;
                                      } else if (currentEditing != null &&
                                          currentEditing > index) {
                                        nextEditing = currentEditing - 1;
                                      }
                                      _updateUi(
                                        (state) => state.copyWith(
                                          items: updatedItems,
                                          editingItemIndex: nextEditing,
                                        ),
                                      );
                                      if (currentEditing == index) {
                                        _clearItemForm();
                                      }
                                    },
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<OrderPriority>(
                        initialValue: ui.priority,
                        decoration: const InputDecoration(
                          labelText: 'Priority',
                        ),
                        items: OrderPriority.values
                            .map(
                              (value) => DropdownMenuItem(
                                value: value,
                                child: Text(value.name),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          if (value == null) return;
                          _updateUi((state) => state.copyWith(priority: value));
                        },
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<PaymentMethod>(
                        initialValue: ui.paymentMethod,
                        decoration: const InputDecoration(
                          labelText: 'Payment Method',
                        ),
                        items: PaymentMethod.values
                            .map(
                              (value) => DropdownMenuItem(
                                value: value,
                                child: Text(_paymentMethodLabel(value)),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          if (value == null) return;
                          _updateUi(
                            (state) => state.copyWith(paymentMethod: value),
                          );
                        },
                      ),
                      if (ui.paymentMethod == PaymentMethod.onlineTransfer) ...[
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _paymentRemarkController,
                          textCapitalization: TextCapitalization.sentences,
                          decoration: const InputDecoration(
                            labelText:
                                'Online Payment Remark (GPay, PhonePe, etc.)',
                          ),
                        ),
                        CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          value: ui.confirmedOnline,
                          onChanged: (value) => _updateUi(
                            (state) =>
                                state.copyWith(confirmedOnline: value ?? false),
                          ),
                          title: const Text('Customer confirmed payment'),
                        ),
                      ],
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _notesController,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: const InputDecoration(labelText: 'Notes'),
                        maxLines: 2,
                      ),
                      if (ui.inlineError != null) ...[
                        const SizedBox(height: 10),
                        Text(
                          ui.inlineError!,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ],
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: ui.loading ? null : _submit,
                          child: ui.loading
                              ? const SizedBox(
                                  height: 18,
                                  width: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text(
                                  widget.existingOrder == null
                                      ? 'Place Order'
                                      : 'Update Order',
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
