import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:uuid/uuid.dart';

import '../../../models/app_user.dart';
import '../../../models/business.dart';
import '../../../models/enums.dart';
import '../../../models/order.dart';
import '../../../models/payment.dart';
import '../../../providers.dart';

class CreateOrderScreen extends ConsumerStatefulWidget {
  const CreateOrderScreen({
    super.key,
    required this.business,
    required this.customer,
    this.requesterBusiness,
  });

  final BusinessProfile business;
  final AppUser customer;
  final BusinessProfile? requesterBusiness;

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
  final _attachmentNameController = TextEditingController();
  final _attachmentUrlController = TextEditingController();
  final _paymentRemarkController = TextEditingController();
  final List<OrderItem> _items = [];
  final List<OrderAttachment> _attachments = [];
  QuantityUnit _itemUnit = QuantityUnit.piece;
  int? _editingItemIndex;
  OrderPriority _priority = OrderPriority.medium;
  PaymentMethod _paymentMethod = PaymentMethod.cash;
  DateTime? _scheduledDate;
  TimeOfDay? _scheduledTime;
  bool _confirmedOnline = false;
  bool _loading = false;
  bool _uploadingAttachment = false;
  bool _loadingSuggestions = false;
  final Map<String, List<String>> _prefixSuggestionCache = {};
  List<String> _catalogItems = const [];
  List<String> _itemSuggestions = const [];
  Timer? _searchDebounce;
  String? _inlineError;
  final String _draftOrderId = const Uuid().v4();

  @override
  void initState() {
    super.initState();
    unawaited(_initializeItemCatalog());
  }

  @override
  void dispose() {
    _itemController.dispose();
    _quantityController.dispose();
    _packSizeController.dispose();
    _itemNoteController.dispose();
    _notesController.dispose();
    _attachmentNameController.dispose();
    _attachmentUrlController.dispose();
    _paymentRemarkController.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  Future<void> _initializeItemCatalog() async {
    final service = ref.read(itemCatalogServiceProvider);
    final cached = await service.getCachedItems();
    if (!mounted) return;
    setState(() => _catalogItems = cached);
    try {
      final refreshed = await service.refreshCatalog();
      if (!mounted) return;
      setState(() => _catalogItems = refreshed);
    } catch (_) {
      // Keep working with local cache if network refresh fails.
    }
  }

  List<String> _searchLocalCatalog(String query, {int limit = 10}) {
    final normalized = query.trim().toLowerCase();
    if (normalized.length < 3) return const [];

    final prefixMatches = _catalogItems
        .where((item) => item.toLowerCase().startsWith(normalized))
        .toList();
    final containsMatches = _catalogItems
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
      setState(() {
        _itemSuggestions = const [];
        _loadingSuggestions = false;
      });
      return;
    }
    _searchDebounce = Timer(const Duration(milliseconds: 300), () async {
      final local = _searchLocalCatalog(query);
      if (local.length >= 5) {
        if (!mounted) return;
        setState(() {
          _itemSuggestions = local;
          _loadingSuggestions = false;
        });
        return;
      }

      final cachedRemote = _prefixSuggestionCache[query];
      if (cachedRemote != null) {
        if (!mounted) return;
        setState(() => _itemSuggestions = cachedRemote);
        return;
      }

      if (mounted) {
        setState(() => _loadingSuggestions = true);
      }
      try {
        final remote = await ref
            .read(itemCatalogServiceProvider)
            .searchByPrefix(query);
        final merged = {...local, ...remote}.toList();
        _prefixSuggestionCache[query] = merged;
        if (!mounted) return;
        setState(() => _itemSuggestions = merged);
      } catch (_) {
        if (!mounted) return;
        setState(() => _itemSuggestions = local);
      } finally {
        if (mounted) {
          setState(() => _loadingSuggestions = false);
        }
      }
    });
  }

  void _selectSuggestion(String value) {
    setState(() {
      _itemController.text = value;
      _itemSuggestions = const [];
      _inlineError = null;
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDate: _scheduledDate ?? DateTime.now(),
    );
    if (picked != null) {
      setState(() => _scheduledDate = picked);
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _scheduledTime ?? TimeOfDay.now(),
    );
    if (picked != null) {
      setState(() => _scheduledTime = picked);
    }
  }

  DateTime? _composeSchedule() {
    if (_scheduledDate == null || _scheduledTime == null) return null;
    return DateTime(
      _scheduledDate!.year,
      _scheduledDate!.month,
      _scheduledDate!.day,
      _scheduledTime!.hour,
      _scheduledTime!.minute,
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
    _itemUnit = QuantityUnit.piece;
    _editingItemIndex = null;
  }

  void _addOrUpdateItem() {
    final title = _itemController.text.trim();
    final quantity = double.tryParse(_quantityController.text.trim()) ?? 0;
    if (title.isEmpty || quantity <= 0) {
      setState(() => _inlineError = 'Add a valid item name and quantity.');
      return;
    }
    final item = OrderItem(
      title: title,
      quantity: quantity,
      unit: _itemUnit,
      packSize: _packSizeController.text.trim().isEmpty
          ? null
          : _packSizeController.text.trim(),
      note: _itemNoteController.text.trim().isEmpty
          ? null
          : _itemNoteController.text.trim(),
      unitPrice: null,
      gstIncluded: false,
      isIncluded: true,
      unavailableReason: null,
    );
    setState(() {
      if (_editingItemIndex == null) {
        _items.add(item);
      } else {
        _items[_editingItemIndex!] = item;
      }
      _clearItemForm();
      _itemSuggestions = const [];
      _inlineError = null;
    });
    unawaited(
      ref.read(itemCatalogServiceProvider).upsertItem(title).catchError((_) {
        // Best-effort catalog enrichment; ignore failures.
      }),
    );
  }

  void _editItem(int index) {
    final item = _items[index];
    setState(() {
      _editingItemIndex = index;
      _itemController.text = item.title;
      _quantityController.text = _formatQuantity(item.quantity);
      _packSizeController.text = item.packSize ?? '';
      _itemNoteController.text = item.note ?? '';
      _itemUnit = item.unit;
      _inlineError = null;
    });
  }

  void _addAttachment() {
    final name = _attachmentNameController.text.trim();
    final url = _attachmentUrlController.text.trim();
    if (name.isEmpty || url.isEmpty) {
      setState(() => _inlineError = 'Add attachment name and URL.');
      return;
    }
    setState(() {
      _attachments.add(OrderAttachment(name: name, url: url));
      _attachmentNameController.clear();
      _attachmentUrlController.clear();
      _inlineError = null;
    });
  }

  Future<void> _uploadAttachmentFile() async {
    setState(() {
      _inlineError = null;
      _uploadingAttachment = true;
    });
    try {
      final picked = await FilePicker.platform.pickFiles(
        withData: true,
        allowMultiple: false,
      );
      if (picked == null || picked.files.isEmpty) return;
      final file = picked.files.single;
      if (file.bytes == null) {
        setState(() => _inlineError = 'Unable to read file bytes.');
        return;
      }
      final uploaded = await ref
          .read(storageServiceProvider)
          .uploadOrderAttachment(
            orderId: _draftOrderId,
            fileName: file.name,
            bytes: file.bytes!,
          );
      setState(() => _attachments.add(uploaded));
    } catch (err) {
      setState(() => _inlineError = 'Attachment upload failed: $err');
    } finally {
      if (mounted) {
        setState(() => _uploadingAttachment = false);
      }
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_items.isEmpty) {
      setState(() => _inlineError = 'At least one item is required.');
      return;
    }
    setState(() {
      _loading = true;
      _inlineError = null;
    });

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
      priority: _priority,
      status: OrderStatus.pending,
      payment: PaymentInfo(
        status: PaymentStatus.pending,
        method: _paymentMethod,
        amount: null,
        remark: _paymentRemarkController.text.trim().isEmpty
            ? null
            : _paymentRemarkController.text.trim(),
        confirmedByCustomer: _paymentMethod == PaymentMethod.onlineTransfer
            ? _confirmedOnline
            : null,
        updatedAt: DateTime.now(),
      ),
      delivery: DeliveryInfo(
        status: DeliveryStatus.pending,
        updatedAt: DateTime.now(),
      ),
      items: _items,
      attachments: _attachments,
      packedItemIndexes: const [],
      notes: _notesController.text.trim().isEmpty
          ? null
          : _notesController.text.trim(),
      scheduledAt: _composeSchedule(),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    try {
      await firestore.createOrder(order);
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (err) {
      setState(() => _inlineError = 'Failed to place order: $err');
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
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
                    if (_loadingSuggestions) ...[
                      const SizedBox(height: 8),
                      const LinearProgressIndicator(minHeight: 2),
                    ],
                    if (_itemSuggestions.isNotEmpty) ...[
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
                          itemCount: _itemSuggestions.length,
                          itemBuilder: (context, index) {
                            final suggestion = _itemSuggestions[index];
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
                      initialValue: _itemUnit,
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
                        setState(() => _itemUnit = value);
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
                    FilledButton.tonal(
                      onPressed: _addOrUpdateItem,
                      child: Text(
                        _editingItemIndex == null ? 'Add Item' : 'Update Item',
                      ),
                    ),
                    if (_editingItemIndex != null)
                      TextButton(
                        onPressed: () => setState(_clearItemForm),
                        child: const Text('Cancel Edit'),
                      ),
                    const SizedBox(height: 8),
                    if (_items.isNotEmpty)
                      Column(
                        children: _items.asMap().entries.map((entry) {
                          final index = entry.key;
                          final item = entry.value;
                          final conversion = _conversionHint(item);
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(
                              '${item.title} ${_formatQuantity(item.quantity)} ${_shortUnit(item.unit)}',
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
                                    setState(() {
                                      _items.removeAt(index);
                                      if (_editingItemIndex == index) {
                                        _clearItemForm();
                                      } else if (_editingItemIndex != null &&
                                          _editingItemIndex! > index) {
                                        _editingItemIndex =
                                            _editingItemIndex! - 1;
                                      }
                                    });
                                  },
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<OrderPriority>(
                      initialValue: _priority,
                      decoration: const InputDecoration(labelText: 'Priority'),
                      items: OrderPriority.values
                          .map(
                            (value) => DropdownMenuItem(
                              value: value,
                              child: Text(value.name),
                            ),
                          )
                          .toList(),
                      onChanged: (value) => setState(() => _priority = value!),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _pickDate,
                            icon: const Icon(Icons.calendar_today),
                            label: Text(
                              _scheduledDate == null
                                  ? 'Pick date'
                                  : _scheduledDate!
                                        .toLocal()
                                        .toString()
                                        .split(' ')
                                        .first,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _pickTime,
                            icon: const Icon(Icons.schedule),
                            label: Text(
                              _scheduledTime == null
                                  ? 'Pick time'
                                  : _scheduledTime!.format(context),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<PaymentMethod>(
                      initialValue: _paymentMethod,
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
                      onChanged: (value) =>
                          setState(() => _paymentMethod = value!),
                    ),
                    if (_paymentMethod == PaymentMethod.onlineTransfer) ...[
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
                        value: _confirmedOnline,
                        onChanged: (value) =>
                            setState(() => _confirmedOnline = value ?? false),
                        title: const Text('Customer confirmed payment'),
                      ),
                    ],
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _attachmentNameController,
                      decoration: const InputDecoration(
                        labelText: 'Attachment Name',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _attachmentUrlController,
                      decoration: const InputDecoration(
                        labelText: 'Attachment URL',
                      ),
                    ),
                    const SizedBox(height: 8),
                    FilledButton.tonal(
                      onPressed: _addAttachment,
                      child: const Text('Add Manual URL Attachment'),
                    ),
                    const SizedBox(height: 8),
                    FilledButton.tonalIcon(
                      onPressed: _uploadingAttachment
                          ? null
                          : _uploadAttachmentFile,
                      icon: const Icon(Icons.upload_file),
                      label: Text(
                        _uploadingAttachment ? 'Uploading...' : 'Upload File',
                      ),
                    ),
                    if (_attachments.isNotEmpty)
                      Column(
                        children: _attachments.asMap().entries.map((entry) {
                          final index = entry.key;
                          final attachment = entry.value;
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(attachment.name),
                            subtitle: Text(attachment.url),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete_outline),
                              onPressed: () =>
                                  setState(() => _attachments.removeAt(index)),
                            ),
                          );
                        }).toList(),
                      ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _notesController,
                      decoration: const InputDecoration(labelText: 'Notes'),
                      maxLines: 2,
                    ),
                    if (_inlineError != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        _inlineError!,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ],
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _loading ? null : _submit,
                        child: _loading
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
