import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart' show StateProvider;
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

import '../../../models/app_user.dart';
import '../../../models/business.dart';
import '../../../models/delivery_address.dart';
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
    this.deliveryAddressRef = _profileAddressRef,
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
  final String deliveryAddressRef;
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
    String? deliveryAddressRef,
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
      deliveryAddressRef: deliveryAddressRef ?? this.deliveryAddressRef,
      inlineError: inlineError == _createOrderUnset
          ? this.inlineError
          : inlineError as String?,
    );
  }
}

const _createOrderUnset = Object();
const _profileAddressRef = '__profile__';

class CreateOrderScreen extends ConsumerStatefulWidget {
  const CreateOrderScreen({
    super.key,
    required this.business,
    required this.customer,
    this.requesterBusiness,
    this.initialItems = const [],
    this.existingOrder,
  });

  final BusinessProfile business;
  final AppUser customer;
  final BusinessProfile? requesterBusiness;
  final List<OrderItem> initialItems;
  final Order? existingOrder;

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
  late final String _draftOrderId;
  final ImagePicker _imagePicker = ImagePicker();
  bool _defaultDeliveryAddressInitialized = false;

  _CreateOrderUiState get _ui => ref.read(_createOrderUiProvider(_draftOrderId));
  void _updateUi(_CreateOrderUiState Function(_CreateOrderUiState state) update) {
    final notifier = ref.read(_createOrderUiProvider(_draftOrderId).notifier);
    notifier.state = update(notifier.state);
  }

  @override
  void initState() {
    super.initState();
    _draftOrderId = widget.existingOrder?.id ?? const Uuid().v4();
    unawaited(_initializeItemCatalog());
    final existing = widget.existingOrder;
    if (existing != null) {
      _notesController.text = existing.notes ?? '';
      _paymentRemarkController.text = existing.payment.remark ?? '';
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _updateUi(
          (state) => state.copyWith(
            items: existing.items,
            priority: existing.priority,
            paymentMethod: existing.payment.method,
            confirmedOnline: existing.payment.confirmedByCustomer ?? false,
          ),
        );
      });
    } else if (widget.initialItems.isNotEmpty) {
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

  String _itemQuantityLabel(OrderItem item) {
    return _formatQuantity(item.quantity);
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
                        onChanged: (value) => label = value,
                        decoration: const InputDecoration(
                          labelText: 'Label',
                          hintText: 'Example: Office A',
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        initialValue: address,
                        onChanged: (value) => address = value,
                        decoration: const InputDecoration(
                          labelText: 'Address',
                          hintText: 'Example: 123 Main Road',
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        initialValue: city,
                        onChanged: (value) => city = value,
                        decoration: const InputDecoration(
                          labelText: 'City (optional)',
                          hintText: 'Example: Surat',
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        initialValue: contactPerson,
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
                                    final cleanContactPerson =
                                        contactPerson.trim();
                                    final cleanContactPhone = contactPhone.trim();
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
                                        contactPerson: cleanContactPerson.isEmpty
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Delivery address saved')),
      );
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
      await ref.read(firestoreServiceProvider).deleteDeliveryAddress(address.id);
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
        (state) => state.copyWith(inlineError: 'Failed to delete address: $err'),
      );
    }
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

    final savedAddresses =
        ref.read(deliveryAddressesProvider(widget.customer.id)).asData?.value ??
        const <DeliveryAddressEntry>[];
    DeliveryAddressEntry? selectedDeliveryAddress;
    for (final entry in savedAddresses) {
      if (entry.id == _ui.deliveryAddressRef) {
        selectedDeliveryAddress = entry;
        break;
      }
    }
    final deliveryAddressLabel = _ui.deliveryAddressRef == _profileAddressRef
        ? _defaultAddressLabel()
        : selectedDeliveryAddress?.label;
    final deliveryAddress = _ui.deliveryAddressRef == _profileAddressRef
        ? _defaultAddressText()
        : selectedDeliveryAddress?.fullAddress;
    final deliveryContactName = _ui.deliveryAddressRef == _profileAddressRef
        ? null
        : selectedDeliveryAddress?.contactPerson;
    final deliveryContactPhone = _ui.deliveryAddressRef == _profileAddressRef
        ? null
        : selectedDeliveryAddress?.contactPhone;

    final firestore = ref.read(firestoreServiceProvider);
    final requesterBusiness = widget.requesterBusiness;
    final existing = widget.existingOrder;
    try {
      if (existing == null) {
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
          deliveryAddressLabel: deliveryAddressLabel,
          deliveryAddress: deliveryAddress,
          deliveryContactName: deliveryContactName,
          deliveryContactPhone: deliveryContactPhone,
          priority: _ui.priority,
          status: OrderStatus.pending,
          payment: PaymentInfo(
            status: PaymentStatus.pending,
            method: _ui.paymentMethod,
            amount: null,
            remark: _paymentRemarkController.text.trim().isEmpty
                ? null
                : _paymentRemarkController.text.trim(),
            confirmedByCustomer:
                _ui.paymentMethod == PaymentMethod.onlineTransfer
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
        await firestore.createOrder(order);
      } else {
        if (existing.status != OrderStatus.pending) {
          _updateUi(
            (state) => state.copyWith(
              inlineError: 'Only new orders can be edited.',
            ),
          );
          return;
        }
        final updatedPayment = existing.payment.copyWith(
          method: _ui.paymentMethod,
          remark: _paymentRemarkController.text.trim().isEmpty
              ? null
              : _paymentRemarkController.text.trim(),
          confirmedByCustomer: _ui.paymentMethod == PaymentMethod.onlineTransfer
              ? _ui.confirmedOnline
              : null,
          updatedAt: DateTime.now(),
        );
        await firestore.updateOrder(existing.id, {
          'priority': enumToString(_ui.priority),
          'items': _ui.items.map((item) => item.toMap()).toList(),
          'deliveryAddressLabel': deliveryAddressLabel,
          'deliveryAddress': deliveryAddress,
          'deliveryContactName': deliveryContactName,
          'deliveryContactPhone': deliveryContactPhone,
          'payment': updatedPayment.toMap(),
          'notes': _notesController.text.trim().isEmpty
              ? null
              : _notesController.text.trim(),
        });
      }
      if (mounted) {
        final resultLabel = existing == null
            ? 'Order for ${widget.business.name}'
            : 'Order ${existing.displayOrderNumber}';
        Navigator.of(context).pop(resultLabel);
      }
    } catch (err) {
      _updateUi(
        (state) => state.copyWith(
          inlineError:
              'Failed to ${existing == null ? 'place' : 'update'} order: $err',
        ),
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
    final deliveryAddressesAsync = ref.watch(
      deliveryAddressesProvider(widget.customer.id),
    );
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
                          final defaultEntry = addresses.where((e) => e.isDefault).firstOrNull;
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
                        final selectedRef = addresses.any(
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
                              selectedItemBuilder: (context) => addressLabels.values
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
                                  onPressed: () => _showDeliveryAddressBottomSheet(
                                    hasAnySavedAddress: addresses.isNotEmpty,
                                  ),
                                  icon: const Icon(Icons.add_location_alt_outlined),
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
                                        hasAnySavedAddress: addresses.isNotEmpty,
                                      );
                                    },
                                    icon: const Icon(Icons.edit_location_alt_outlined),
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
                      loading: () => const LinearProgressIndicator(minHeight: 2),
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
                                          borderRadius: BorderRadius.circular(8),
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
                                                Icons.image_not_supported_outlined,
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
                                if (item.note != null && item.note!.isNotEmpty)
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
