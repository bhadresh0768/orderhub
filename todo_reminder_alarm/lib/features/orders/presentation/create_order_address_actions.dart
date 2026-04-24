part of 'create_order_screen.dart';

extension _CreateOrderAddressActions on _CreateOrderScreenState {
  String _composeAddress(String? address, String? city) {
    final addressText = (address ?? '').trim();
    final cityText = (city ?? '').trim();
    if (addressText.isEmpty && cityText.isEmpty) return '-';
    if (addressText.isEmpty) return cityText;
    if (cityText.isEmpty) return addressText;
    return '$addressText, $cityText';
  }

  String _defaultAddressLabel() {
    if (widget.requesterBusiness != null) {
      return '${widget.requesterBusiness!.name} (Default)';
    }
    final shopName = (widget.customer.shopName ?? '').trim();
    if (shopName.isNotEmpty) return '$shopName (Default)';
    return 'Default Address';
  }

  String _defaultAddressText() {
    if (widget.requesterBusiness != null) {
      return _composeAddress(
        widget.requesterBusiness!.address,
        widget.requesterBusiness!.city,
      );
    }
    return _composeAddress(widget.customer.address, null);
  }

  Future<void> _showDeliveryAddressBottomSheet({
    DeliveryAddressEntry? existing,
    required bool hasAnySavedAddress,
  }) async {
    String label = existing?.label ?? '';
    String address = existing?.address ?? '';
    String city = existing?.city ?? '';
    String contactPerson = existing?.contactPerson ?? '';
    String contactPhone = existing?.contactPhone ?? '';
    bool isDefault = existing?.isDefault ?? !hasAnySavedAddress;
    bool saving = false;
    String? errorText;

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return SafeArea(
              child: Padding(
                padding: EdgeInsets.only(
                  left: 16,
                  right: 16,
                  top: 8,
                  bottom: MediaQuery.of(context).viewInsets.bottom + 16,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        existing == null
                            ? 'Add Delivery Address'
                            : 'Edit Delivery Address',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        initialValue: label,
                        textCapitalization: TextCapitalization.words,
                        onChanged: (value) => label = value,
                        decoration: const InputDecoration(
                          labelText: 'Label',
                          hintText: 'Example: Office A',
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        initialValue: address,
                        textCapitalization: TextCapitalization.sentences,
                        onChanged: (value) => address = value,
                        decoration: const InputDecoration(
                          labelText: 'Address',
                          hintText: 'Example: 123 Main Road',
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        initialValue: city,
                        textCapitalization: TextCapitalization.words,
                        onChanged: (value) => city = value,
                        decoration: const InputDecoration(
                          labelText: 'City (optional)',
                          hintText: 'Example: Surat',
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        initialValue: contactPerson,
                        textCapitalization: TextCapitalization.words,
                        onChanged: (value) => contactPerson = value,
                        decoration: const InputDecoration(
                          labelText: 'Contact Person (optional)',
                          hintText: 'Example: Ramesh',
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        initialValue: contactPhone,
                        keyboardType: TextInputType.phone,
                        onChanged: (value) => contactPhone = value,
                        decoration: const InputDecoration(
                          labelText: 'Mobile Number (optional)',
                          hintText: 'Example: +91 9876543210',
                        ),
                      ),
                      const SizedBox(height: 8),
                      CheckboxListTile(
                        value: isDefault,
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Set as default'),
                        onChanged: saving
                            ? null
                            : (next) => setModalState(
                                () => isDefault = next ?? false,
                              ),
                      ),
                      if (errorText != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text(
                            errorText!,
                            style: const TextStyle(color: Colors.red),
                          ),
                        ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: saving
                                ? null
                                : () => Navigator.of(sheetContext).pop(false),
                            child: const Text('Cancel'),
                          ),
                          const SizedBox(width: 8),
                          FilledButton(
                            onPressed: saving
                                ? null
                                : () async {
                                    final cleanLabel = label.trim();
                                    final cleanAddress = address.trim();
                                    final cleanCity = city.trim();
                                    final cleanContactPerson = contactPerson
                                        .trim();
                                    final cleanContactPhone = contactPhone
                                        .trim();
                                    if (cleanLabel.isEmpty ||
                                        cleanAddress.isEmpty) {
                                      setModalState(() {
                                        errorText =
                                            'Label and address are required.';
                                      });
                                      return;
                                    }
                                    setModalState(() {
                                      saving = true;
                                      errorText = null;
                                    });
                                    try {
                                      final service = ref.read(
                                        firestoreServiceProvider,
                                      );
                                      final entry = DeliveryAddressEntry(
                                        id: existing?.id ?? const Uuid().v4(),
                                        userId: widget.customer.id,
                                        label: cleanLabel,
                                        address: cleanAddress,
                                        city: cleanCity.isEmpty
                                            ? null
                                            : cleanCity,
                                        contactPerson:
                                            cleanContactPerson.isEmpty
                                            ? null
                                            : cleanContactPerson,
                                        contactPhone: cleanContactPhone.isEmpty
                                            ? null
                                            : cleanContactPhone,
                                        isDefault: isDefault,
                                        createdAt:
                                            existing?.createdAt ??
                                            DateTime.now(),
                                        updatedAt: DateTime.now(),
                                      );
                                      if (existing == null) {
                                        await service.createDeliveryAddress(
                                          entry,
                                        );
                                      } else {
                                        await service.updateDeliveryAddress(
                                          existing.id,
                                          entry,
                                        );
                                      }
                                      if (!mounted || !sheetContext.mounted) {
                                        return;
                                      }
                                      _updateUi(
                                        (state) => state.copyWith(
                                          deliveryAddressRef: entry.id,
                                          inlineError: null,
                                        ),
                                      );
                                      Navigator.of(sheetContext).pop(true);
                                    } catch (err) {
                                      setModalState(() {
                                        errorText =
                                            'Failed to save address: $err';
                                        saving = false;
                                      });
                                    }
                                  },
                            child: const Text('Save'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    if (saved == true && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Delivery address saved')));
    }
  }

  Future<void> _deleteDeliveryAddress(DeliveryAddressEntry address) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete Address'),
          content: Text('Delete "${address.label}"?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
    if (confirm != true) return;
    try {
      await ref
          .read(firestoreServiceProvider)
          .deleteDeliveryAddress(address.id);
      if (!mounted) return;
      if (_ui.deliveryAddressRef == address.id) {
        _updateUi(
          (state) => state.copyWith(deliveryAddressRef: _profileAddressRef),
        );
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Address deleted')));
    } catch (err) {
      if (!mounted) return;
      _updateUi(
        (state) =>
            state.copyWith(inlineError: 'Failed to delete address: $err'),
      );
    }
  }
}
