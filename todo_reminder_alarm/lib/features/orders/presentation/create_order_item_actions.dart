part of 'create_order_screen.dart';

extension _CreateOrderItemActions on _CreateOrderScreenState {
  String? _conversionHint(OrderItem item) {
    if ((item.packSize ?? '').trim().isNotEmpty) {
      return null;
    }
    final hint = switch (item.unit) {
      QuantityUnit.ton => '${_formatQuantity(item.quantity * 1000)} kg',
      QuantityUnit.kilogram => '${_formatQuantity(item.quantity * 1000)} g',
      QuantityUnit.gram => '${_formatQuantity(item.quantity / 1000)} kg',
      QuantityUnit.liter => '${_formatQuantity(item.quantity * 1000)} ml',
      QuantityUnit.piece ||
      QuantityUnit.box ||
      QuantityUnit.packet ||
      QuantityUnit.bag ||
      QuantityUnit.bottle ||
      QuantityUnit.can ||
      QuantityUnit.meter ||
      QuantityUnit.foot ||
      QuantityUnit.carton ||
      QuantityUnit.other => null,
    };
    if (hint == null) return null;
    final parts = hint.split(' ');
    final convertedValue = double.tryParse(parts.first);
    if (convertedValue != null && convertedValue.abs() >= 10000) {
      return null;
    }
    return hint;
  }

  void _clearItemForm() {
    _itemController.clear();
    _quantityController.text = '1';
    _packSizeController.clear();
    _itemNoteController.clear();
    _updateUi(
      (state) => state.copyWith(
        itemAttachmentsDraft: const [],
        itemUnitCode: quantityUnitCode(QuantityUnit.piece),
        itemUnitLabel: null,
        itemUnitSymbol: null,
        editingItemIndex: null,
      ),
    );
  }

  void _addOrUpdateItem(List<OrderUnit> availableUnits) {
    final title = _itemController.text.trim();
    final quantity = double.tryParse(_quantityController.text.trim()) ?? 0;
    if (title.isEmpty || quantity <= 0) {
      _updateUi(
        (state) =>
            state.copyWith(inlineError: 'Add a valid item name and quantity.'),
      );
      return;
    }
    final selectedUnit = _resolveSelectedUnit(availableUnits);
    final parsedUnit = quantityUnitFromCode(selectedUnit.code);
    final item = OrderItem(
      title: title,
      quantity: quantity,
      unit: parsedUnit,
      unitCode: selectedUnit.code,
      unitLabel: selectedUnit.label,
      unitSymbol: selectedUnit.symbol,
      packSize: _packSizeController.text.trim().isEmpty
          ? null
          : _packSizeController.text.trim(),
      note: _itemNoteController.text.trim().isEmpty
          ? null
          : _itemNoteController.text.trim(),
      attachments: List<OrderAttachment>.from(_ui.itemAttachmentsDraft),
      unitPrice: null,
      gstIncluded: false,
      isIncluded: true,
      unavailableReason: null,
    );
    final current = _ui;
    final nextItems = [...current.items];
    if (current.editingItemIndex == null) {
      nextItems.add(item);
    } else {
      nextItems[current.editingItemIndex!] = item;
    }
    _updateUi(
      (state) => state.copyWith(
        items: nextItems,
        itemSuggestions: const [],
        inlineError: null,
        itemAttachmentsDraft: const [],
        itemUnitCode: quantityUnitCode(QuantityUnit.piece),
        itemUnitLabel: null,
        itemUnitSymbol: null,
        editingItemIndex: null,
      ),
    );
    _itemController.clear();
    _quantityController.text = '1';
    _packSizeController.clear();
    _itemNoteController.clear();
    unawaited(
      ref.read(itemCatalogServiceProvider).upsertItem(title).catchError((_) {
        // Best-effort catalog enrichment; ignore failures.
      }),
    );
  }

  void _editItem(int index) {
    final item = _ui.items[index];
    _itemController.text = item.title;
    _quantityController.text = _formatQuantity(item.quantity);
    _packSizeController.text = item.packSize ?? '';
    _itemNoteController.text = item.note ?? '';
    _updateUi(
      (state) => state.copyWith(
        editingItemIndex: index,
        itemAttachmentsDraft: List<OrderAttachment>.from(item.attachments),
        itemUnitCode: item.unitCode ?? quantityUnitCode(item.unit),
        itemUnitLabel: item.unitLabel,
        itemUnitSymbol: item.unitSymbol,
        inlineError: null,
      ),
    );
  }

  Future<void> _pickSingleItemImage(ImageSource source) async {
    _updateUi(
      (state) => state.copyWith(inlineError: null, uploadingItemImage: true),
    );
    try {
      final picked = await _imagePicker.pickImage(source: source);
      if (picked == null) return;
      final Uint8List bytes = await picked.readAsBytes();
      if (bytes.isEmpty) {
        _updateUi(
          (state) => state.copyWith(inlineError: 'Unable to read image bytes.'),
        );
        return;
      }
      final fileName = picked.name.trim().isEmpty
          ? 'item_${DateTime.now().millisecondsSinceEpoch}.jpg'
          : picked.name;
      final uploaded = await ref
          .read(storageServiceProvider)
          .uploadOrderAttachment(
            orderId: _draftOrderId,
            fileName: fileName,
            bytes: bytes,
          );
      _updateUi(
        (state) => state.copyWith(
          itemAttachmentsDraft: [...state.itemAttachmentsDraft, uploaded],
        ),
      );
    } catch (err) {
      _updateUi(
        (state) => state.copyWith(inlineError: 'Image upload failed: $err'),
      );
    } finally {
      if (mounted) {
        _updateUi((state) => state.copyWith(uploadingItemImage: false));
      }
    }
  }

  Future<void> _pickMultipleItemImagesFromGallery() async {
    _updateUi(
      (state) => state.copyWith(inlineError: null, uploadingItemImage: true),
    );
    try {
      final picked = await _imagePicker.pickMultiImage();
      if (picked.isEmpty) return;
      for (final image in picked) {
        final bytes = await image.readAsBytes();
        if (bytes.isEmpty) continue;
        final fileName = image.name.trim().isEmpty
            ? 'item_${DateTime.now().millisecondsSinceEpoch}.jpg'
            : image.name;
        final uploaded = await ref
            .read(storageServiceProvider)
            .uploadOrderAttachment(
              orderId: _draftOrderId,
              fileName: fileName,
              bytes: bytes,
            );
        if (!mounted) return;
        _updateUi(
          (state) => state.copyWith(
            itemAttachmentsDraft: [...state.itemAttachmentsDraft, uploaded],
          ),
        );
      }
    } catch (err) {
      _updateUi(
        (state) => state.copyWith(inlineError: 'Image upload failed: $err'),
      );
    } finally {
      if (mounted) {
        _updateUi((state) => state.copyWith(uploadingItemImage: false));
      }
    }
  }

  Future<void> _showItemImageSourceSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt_outlined),
                title: const Text('Camera (single image)'),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _pickSingleItemImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_outlined),
                title: const Text('Gallery (single image)'),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _pickSingleItemImage(ImageSource.gallery);
                },
              ),
              ListTile(
                leading: const Icon(Icons.collections_outlined),
                title: const Text('Gallery (multiple images)'),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _pickMultipleItemImagesFromGallery();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showItemImageGallery(
    List<OrderAttachment> attachments, {
    int initialIndex = 0,
  }) async {
    final pageNotifier = ValueNotifier<int>(initialIndex);
    await showDialog<void>(
      context: context,
      builder: (context) {
        return Dialog.fullscreen(
          child: Stack(
            children: [
              PageView.builder(
                controller: PageController(initialPage: initialIndex),
                itemCount: attachments.length,
                onPageChanged: (index) => pageNotifier.value = index,
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
              if (attachments.length > 1)
                Positioned(
                  top: 16,
                  right: 16,
                  child: ValueListenableBuilder<int>(
                    valueListenable: pageNotifier,
                    builder: (context, page, _) {
                      return DecoratedBox(
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          child: Text(
                            '${page + 1}/${attachments.length}',
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        );
      },
    );
    pageNotifier.dispose();
  }
}
