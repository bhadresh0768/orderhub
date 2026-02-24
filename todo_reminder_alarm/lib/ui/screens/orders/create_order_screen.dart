import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart' show StateProvider;
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

import '../../../models/app_user.dart';
import '../../../models/business.dart';
import '../../../models/enums.dart';
import '../../../models/order.dart';
import '../../../models/payment.dart';
import '../../../providers.dart';

final _createOrderUiProvider =
    StateProvider.autoDispose.family<_CreateOrderUiState, String>(
  (ref, id) => const _CreateOrderUiState(),
);

class _CreateOrderUiState {
  const _CreateOrderUiState({
    this.items = const [],
    this.itemAttachmentsDraft = const [],
    this.itemUnit = QuantityUnit.piece,
    this.editingItemIndex,
    this.priority = OrderPriority.medium,
    this.paymentMethod = PaymentMethod.cash,
    this.confirmedOnline = false,
    this.loading = false,
    this.uploadingItemImage = false,
    this.loadingSuggestions = false,
    this.catalogItems = const [],
    this.itemSuggestions = const [],
    this.inlineError,
  });

  final List<OrderItem> items;
  final List<OrderAttachment> itemAttachmentsDraft;
  final QuantityUnit itemUnit;
  final int? editingItemIndex;
  final OrderPriority priority;
  final PaymentMethod paymentMethod;
  final bool confirmedOnline;
  final bool loading;
  final bool uploadingItemImage;
  final bool loadingSuggestions;
  final List<String> catalogItems;
  final List<String> itemSuggestions;
  final String? inlineError;

  _CreateOrderUiState copyWith({
    List<OrderItem>? items,
    List<OrderAttachment>? itemAttachmentsDraft,
    QuantityUnit? itemUnit,
    Object? editingItemIndex = _createOrderUnset,
    OrderPriority? priority,
    PaymentMethod? paymentMethod,
    bool? confirmedOnline,
    bool? loading,
    bool? uploadingItemImage,
    bool? loadingSuggestions,
    List<String>? catalogItems,
    List<String>? itemSuggestions,
    Object? inlineError = _createOrderUnset,
  }) {
    return _CreateOrderUiState(
      items: items ?? this.items,
      itemAttachmentsDraft: itemAttachmentsDraft ?? this.itemAttachmentsDraft,
      itemUnit: itemUnit ?? this.itemUnit,
      editingItemIndex: editingItemIndex == _createOrderUnset
          ? this.editingItemIndex
          : editingItemIndex as int?,
      priority: priority ?? this.priority,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      confirmedOnline: confirmedOnline ?? this.confirmedOnline,
      loading: loading ?? this.loading,
      uploadingItemImage: uploadingItemImage ?? this.uploadingItemImage,
      loadingSuggestions: loadingSuggestions ?? this.loadingSuggestions,
      catalogItems: catalogItems ?? this.catalogItems,
      itemSuggestions: itemSuggestions ?? this.itemSuggestions,
      inlineError: inlineError == _createOrderUnset
          ? this.inlineError
          : inlineError as String?,
    );
  }
}

const _createOrderUnset = Object();

class CreateOrderScreen extends ConsumerStatefulWidget {
  const CreateOrderScreen({
    super.key,
    required this.business,
    required this.customer,
    this.requesterBusiness,
    this.initialItems = const [],
  });

  final BusinessProfile business;
  final AppUser customer;
  final BusinessProfile? requesterBusiness;
  final List<OrderItem> initialItems;

  @override
  ConsumerState<CreateOrderScreen> createState() => _CreateOrderScreenState();
}

class _CreateOrderScreenState extends ConsumerState<CreateOrderScreen> {
  final _formKey = GlobalKey<FormState>();
  final _itemController = TextEditingController();
  final _quantityController = TextEditingController(text: '1');
  final _packSizeController = TextEditingController();
  final _itemNoteController = TextEditingController();
  final _notesController = TextEditingController();
  final _paymentRemarkController = TextEditingController();
  final Map<String, List<String>> _prefixSuggestionCache = {};
  Timer? _searchDebounce;
  final String _draftOrderId = const Uuid().v4();
  final ImagePicker _imagePicker = ImagePicker();

  _CreateOrderUiState get _ui => ref.read(_createOrderUiProvider(_draftOrderId));
  void _updateUi(_CreateOrderUiState Function(_CreateOrderUiState state) update) {
    final notifier = ref.read(_createOrderUiProvider(_draftOrderId).notifier);
    notifier.state = update(notifier.state);
  }

  @override
  void initState() {
    super.initState();
    unawaited(_initializeItemCatalog());
    if (widget.initialItems.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _updateUi((state) => state.copyWith(items: widget.initialItems));
      });
    }
  }

  @override
  void dispose() {
    _itemController.dispose();
    _quantityController.dispose();
    _packSizeController.dispose();
    _itemNoteController.dispose();
    _notesController.dispose();
    _paymentRemarkController.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  Future<void> _initializeItemCatalog() async {
    final service = ref.read(itemCatalogServiceProvider);
    final cached = await service.getCachedItems();
    if (!mounted) return;
    _updateUi((state) => state.copyWith(catalogItems: cached));
    try {
      final refreshed = await service.refreshCatalog();
      if (!mounted) return;
      _updateUi((state) => state.copyWith(catalogItems: refreshed));
    } catch (_) {
      // Keep working with local cache if network refresh fails.
    }
  }

  List<String> _searchLocalCatalog(String query, {int limit = 10}) {
    final normalized = query.trim().toLowerCase();
    if (normalized.length < 3) return const [];

    final prefixMatches = _ui.catalogItems
        .where((item) => item.toLowerCase().startsWith(normalized))
        .toList();
    final containsMatches = _ui.catalogItems
        .where(
          (item) =>
              !item.toLowerCase().startsWith(normalized) &&
              item.toLowerCase().contains(normalized),
        )
        .toList();
    final merged = [...prefixMatches, ...containsMatches];
    return merged.take(limit).toList();
  }

  void _onItemQueryChanged(String value) {
    _searchDebounce?.cancel();
    final query = value.trim().toLowerCase();
    if (query.length < 3) {
      _updateUi(
        (state) => state.copyWith(
          itemSuggestions: const [],
          loadingSuggestions: false,
        ),
      );
      return;
    }
    _searchDebounce = Timer(const Duration(milliseconds: 300), () async {
      final local = _searchLocalCatalog(query);
      if (local.length >= 5) {
        if (!mounted) return;
        _updateUi(
          (state) => state.copyWith(
            itemSuggestions: local,
            loadingSuggestions: false,
          ),
        );
        return;
      }

      final cachedRemote = _prefixSuggestionCache[query];
      if (cachedRemote != null) {
        if (!mounted) return;
        _updateUi((state) => state.copyWith(itemSuggestions: cachedRemote));
        return;
      }

      if (mounted) {
        _updateUi((state) => state.copyWith(loadingSuggestions: true));
      }
      try {
        final remote = await ref
            .read(itemCatalogServiceProvider)
            .searchByPrefix(query);
        final merged = {...local, ...remote}.toList();
        _prefixSuggestionCache[query] = merged;
        if (!mounted) return;
        _updateUi((state) => state.copyWith(itemSuggestions: merged));
      } catch (_) {
        if (!mounted) return;
        _updateUi((state) => state.copyWith(itemSuggestions: local));
      } finally {
        if (mounted) {
          _updateUi((state) => state.copyWith(loadingSuggestions: false));
        }
      }
    });
  }

  void _selectSuggestion(String value) {
    _itemController.text = value;
    _updateUi(
      (state) => state.copyWith(itemSuggestions: const [], inlineError: null),
    );
  }

  String _formatQuantity(double value) {
    return value == value.truncateToDouble()
        ? value.toInt().toString()
        : value.toString();
  }

  String _shortUnit(QuantityUnit unit) {
    switch (unit) {
      case QuantityUnit.piece:
        return 'pc';
      case QuantityUnit.kilogram:
        return 'kg';
      case QuantityUnit.gram:
        return 'g';
      case QuantityUnit.liter:
        return 'L';
    }
  }

  String _itemQuantityLabel(OrderItem item) {
    final hasPack = (item.packSize ?? '').trim().isNotEmpty;
    if (hasPack) {
      final qty = _formatQuantity(item.quantity);
      final suffix = item.quantity == 1 ? 'pack' : 'packs';
      return '$qty $suffix';
    }
    return '${_formatQuantity(item.quantity)} ${_shortUnit(item.unit)}';
  }

  String _paymentMethodLabel(PaymentMethod method) {
    switch (method) {
      case PaymentMethod.cash:
        return 'Cash';
      case PaymentMethod.check:
        return 'Check';
      case PaymentMethod.onlineTransfer:
        return 'Online Transfer';
    }
  }

  String? _conversionHint(OrderItem item) {
    if ((item.packSize ?? '').trim().isNotEmpty) {
      return null;
    }
    switch (item.unit) {
      case QuantityUnit.kilogram:
        return '${_formatQuantity(item.quantity * 1000)} g';
      case QuantityUnit.gram:
        return '${_formatQuantity(item.quantity / 1000)} kg';
      case QuantityUnit.liter:
        return '${_formatQuantity(item.quantity * 1000)} ml';
      case QuantityUnit.piece:
        return null;
    }
  }

  void _clearItemForm() {
    _itemController.clear();
    _quantityController.text = '1';
    _packSizeController.clear();
    _itemNoteController.clear();
    _updateUi(
      (state) => state.copyWith(
        itemAttachmentsDraft: const [],
        itemUnit: QuantityUnit.piece,
        editingItemIndex: null,
      ),
    );
  }

  void _addOrUpdateItem() {
    final title = _itemController.text.trim();
    final quantity = double.tryParse(_quantityController.text.trim()) ?? 0;
    if (title.isEmpty || quantity <= 0) {
      _updateUi(
        (state) =>
            state.copyWith(inlineError: 'Add a valid item name and quantity.'),
      );
      return;
    }
    final item = OrderItem(
      title: title,
      quantity: quantity,
      unit: _ui.itemUnit,
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
        itemUnit: QuantityUnit.piece,
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
        itemUnit: item.unit,
        inlineError: null,
      ),
    );
  }

  Future<void> _pickSingleItemImage(ImageSource source) async {
    _updateUi(
      (state) => state.copyWith(
        inlineError: null,
        uploadingItemImage: true,
      ),
    );
    try {
      final picked = await _imagePicker.pickImage(
        source: source,
        imageQuality: 75,
        maxWidth: 1800,
      );
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
      (state) => state.copyWith(
        inlineError: null,
        uploadingItemImage: true,
      ),
    );
    try {
      final picked = await _imagePicker.pickMultiImage(
        imageQuality: 75,
        maxWidth: 1800,
      );
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

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_ui.items.isEmpty) {
      _updateUi(
        (state) =>
            state.copyWith(inlineError: 'At least one item is required.'),
      );
      return;
    }
    _updateUi((state) => state.copyWith(loading: true, inlineError: null));

    final firestore = ref.read(firestoreServiceProvider);
    final requesterBusiness = widget.requesterBusiness;
    final order = Order(
      id: _draftOrderId,
      businessId: widget.business.id,
      businessName: widget.business.name,
      customerId: widget.customer.id,
      customerName: widget.customer.name,
      requesterType: requesterBusiness == null
          ? OrderRequesterType.customer
          : OrderRequesterType.businessOwner,
      requesterBusinessId: requesterBusiness?.id,
      requesterBusinessName: requesterBusiness?.name,
      priority: _ui.priority,
      status: OrderStatus.pending,
      payment: PaymentInfo(
        status: PaymentStatus.pending,
        method: _ui.paymentMethod,
        amount: null,
        remark: _paymentRemarkController.text.trim().isEmpty
            ? null
            : _paymentRemarkController.text.trim(),
        confirmedByCustomer: _ui.paymentMethod == PaymentMethod.onlineTransfer
            ? _ui.confirmedOnline
            : null,
        updatedAt: DateTime.now(),
      ),
      delivery: DeliveryInfo(
        status: DeliveryStatus.pending,
        updatedAt: DateTime.now(),
      ),
      items: _ui.items,
      attachments: const [],
      packedItemIndexes: const [],
      notes: _notesController.text.trim().isEmpty
          ? null
          : _notesController.text.trim(),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    try {
      await firestore.createOrder(order);
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (err) {
      _updateUi(
        (state) => state.copyWith(inlineError: 'Failed to place order: $err'),
      );
    } finally {
      if (mounted) {
        _updateUi((state) => state.copyWith(loading: false));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ui = ref.watch(_createOrderUiProvider(_draftOrderId));
    return Scaffold(
      appBar: AppBar(title: Text('Order ${widget.business.name}')),
      body: ListView(
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
                    TextFormField(
                      controller: _itemController,
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
                      decoration: const InputDecoration(labelText: 'Quantity'),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _packSizeController,
                      decoration: const InputDecoration(
                        labelText: 'Pack Size (optional)',
                        hintText: 'e.g. 1 L pouch, 500 g pack',
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<QuantityUnit>(
                      initialValue: ui.itemUnit,
                      decoration: const InputDecoration(labelText: 'Unit'),
                      items: const [
                        DropdownMenuItem(
                          value: QuantityUnit.piece,
                          child: Text('Piece (pc)'),
                        ),
                        DropdownMenuItem(
                          value: QuantityUnit.kilogram,
                          child: Text('Kilogram (kg)'),
                        ),
                        DropdownMenuItem(
                          value: QuantityUnit.gram,
                          child: Text('Gram (g)'),
                        ),
                        DropdownMenuItem(
                          value: QuantityUnit.liter,
                          child: Text('Liter (L)'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value == null) return;
                        _updateUi((state) => state.copyWith(itemUnit: value));
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _itemNoteController,
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
                        children: ui.itemAttachmentsDraft.asMap().entries.map((
                          entry,
                        ) {
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
                                final updated = [
                                  ...ui.itemAttachmentsDraft,
                                ]..removeAt(index);
                                _updateUi(
                                  (state) => state.copyWith(
                                    itemAttachmentsDraft: updated,
                                  ),
                                );
                              },
                            ),
                          );
                        }).toList(),
                      ),
                    const SizedBox(height: 8),
                    FilledButton.tonal(
                      onPressed: _addOrUpdateItem,
                      child: Text(
                        ui.editingItemIndex == null
                            ? 'Add Item'
                            : 'Update Item',
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
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(
                              '${item.title} ${_itemQuantityLabel(item)}',
                            ),
                            subtitle: Text(
                              [
                                if (item.packSize != null &&
                                    item.packSize!.isNotEmpty)
                                  'Pack: ${item.packSize!}',
                                if (item.note != null && item.note!.isNotEmpty)
                                  item.note!,
                                if (conversion != null) '~ $conversion',
                                if (item.attachments.isNotEmpty)
                                  'Images: ${item.attachments.length}',
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
                                    final currentEditing = ui.editingItemIndex;
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
                      decoration: const InputDecoration(labelText: 'Priority'),
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
                        decoration: const InputDecoration(
                          labelText:
                              'Online Payment Remark (GPay, PhonePe, etc.)',
                        ),
                      ),
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        value: ui.confirmedOnline,
                        onChanged: (value) => _updateUi(
                          (state) => state.copyWith(
                            confirmedOnline: value ?? false,
                          ),
                        ),
                        title: const Text('Customer confirmed payment'),
                      ),
                    ],
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _notesController,
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
                            : const Text('Place Order'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
