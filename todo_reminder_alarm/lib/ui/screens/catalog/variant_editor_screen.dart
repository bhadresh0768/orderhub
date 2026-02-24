import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart' show StateProvider;
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

import '../../../models/catalog.dart';
import '../../../providers.dart';

final _variantEditorUiProvider =
    StateProvider.autoDispose.family<_VariantEditorUiState, String>(
  (ref, _) => const _VariantEditorUiState(),
);

class _VariantEditorUiState {
  const _VariantEditorUiState({
    this.saving = false,
    this.unitType = CatalogUnitType.count,
    this.isActive = true,
    this.imageUrls = const [],
  });

  final bool saving;
  final CatalogUnitType unitType;
  final bool isActive;
  final List<String> imageUrls;

  _VariantEditorUiState copyWith({
    bool? saving,
    CatalogUnitType? unitType,
    bool? isActive,
    List<String>? imageUrls,
  }) {
    return _VariantEditorUiState(
      saving: saving ?? this.saving,
      unitType: unitType ?? this.unitType,
      isActive: isActive ?? this.isActive,
      imageUrls: imageUrls ?? this.imageUrls,
    );
  }
}

class VariantEditorScreen extends ConsumerStatefulWidget {
  const VariantEditorScreen({
    super.key,
    required this.businessId,
    required this.product,
    this.variant,
  });

  final String businessId;
  final CatalogProduct product;
  final CatalogVariant? variant;

  @override
  ConsumerState<VariantEditorScreen> createState() =>
      _VariantEditorScreenState();
}

class _VariantEditorScreenState extends ConsumerState<VariantEditorScreen> {
  static const List<String> _volumeUnits = ['ml', 'lit'];
  static const List<String> _weightUnits = ['g', 'kg'];
  static const List<String> _countUnits = ['pc', 'pack', 'box', 'set'];

  late final String _variantId;
  late final TextEditingController _labelController;
  late final TextEditingController _baseValueController;
  late final TextEditingController _baseUnitController;
  late final TextEditingController _priceController;
  late final TextEditingController _mrpController;
  late final TextEditingController _stockController;

  _VariantEditorUiState get _ui =>
      ref.read(_variantEditorUiProvider(_variantId));
  void _updateUi(
    _VariantEditorUiState Function(_VariantEditorUiState state) update,
  ) {
    final notifier = ref.read(_variantEditorUiProvider(_variantId).notifier);
    notifier.state = update(notifier.state);
  }
  CatalogUnitType get _unitType => _ui.unitType;
  bool get _isActive => _ui.isActive;
  List<String> get _imageUrls => _ui.imageUrls;
  bool get _saving => _ui.saving;

  @override
  void initState() {
    super.initState();
    final variant = widget.variant;
    _variantId = variant?.id ?? const Uuid().v4();
    _labelController = TextEditingController(text: variant?.label ?? '');
    _baseValueController = TextEditingController(
      text: variant?.baseValue.toString() ?? '',
    );
    _baseUnitController = TextEditingController(text: variant?.baseUnit ?? '');
    _priceController = TextEditingController(
      text: variant?.price.toStringAsFixed(2) ?? '',
    );
    _mrpController = TextEditingController(
      text: variant?.mrp?.toStringAsFixed(2) ?? '',
    );
    _stockController = TextEditingController(
      text: variant?.stockQty?.toString() ?? '',
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _updateUi(
        (state) => state.copyWith(
          unitType: variant?.unitType ?? CatalogUnitType.count,
          isActive: variant?.isActive ?? true,
          imageUrls: List<String>.from(variant?.imageUrls ?? const []),
        ),
      );
    });
  }

  @override
  void dispose() {
    _labelController.dispose();
    _baseValueController.dispose();
    _baseUnitController.dispose();
    _priceController.dispose();
    _mrpController.dispose();
    _stockController.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    final picker = ImagePicker();
    final choice = await showModalBottomSheet<_ImagePickChoice>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera),
              title: const Text('Camera'),
              onTap: () => Navigator.of(context).pop(_ImagePickChoice.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Gallery (Multiple)'),
              onTap: () => Navigator.of(context).pop(_ImagePickChoice.gallery),
            ),
          ],
        ),
      ),
    );
    if (choice == null) return;

    _updateUi((state) => state.copyWith(saving: true));
    try {
      final uploads = <String>[];
      if (choice == _ImagePickChoice.camera) {
        final file = await picker.pickImage(source: ImageSource.camera);
        if (file == null) return;
        final bytes = await file.readAsBytes();
        final url = await ref.read(storageServiceProvider).uploadCatalogImage(
              businessId: widget.businessId,
              productId: widget.product.id,
              variantId: _variantId,
              fileName: file.name,
              bytes: bytes,
            );
        uploads.add(url);
      } else {
        final files = await picker.pickMultiImage();
        if (files.isEmpty) return;
        for (final file in files) {
          final bytes = await file.readAsBytes();
          final url = await ref.read(storageServiceProvider).uploadCatalogImage(
                businessId: widget.businessId,
                productId: widget.product.id,
                variantId: _variantId,
                fileName: file.name,
                bytes: bytes,
              );
          uploads.add(url);
        }
      }
      if (!mounted) return;
      _updateUi((state) {
        final next = [...state.imageUrls, ...uploads];
        return state.copyWith(imageUrls: next);
      });
    } finally {
      if (mounted) {
        _updateUi((state) => state.copyWith(saving: false));
      }
    }
  }

  Future<void> _saveVariant() async {
    final labelText = _labelController.text.trim();
    final baseValueInt = int.tryParse(_baseValueController.text.trim()) ?? 0;
    final baseUnitText = _baseUnitController.text.trim();
    final priceValue = double.tryParse(_priceController.text.trim()) ?? 0;
    if (labelText.isEmpty || baseValueInt <= 0 || baseUnitText.isEmpty) {
      return;
    }
    _updateUi((state) => state.copyWith(saving: true));
    try {
      final variantData = CatalogVariant(
        id: _variantId,
        businessId: widget.businessId,
        productId: widget.product.id,
        label: labelText,
        unitType: _unitType,
        baseValue: baseValueInt,
        baseUnit: baseUnitText,
        price: priceValue,
        mrp: double.tryParse(_mrpController.text.trim()),
        stockQty: int.tryParse(_stockController.text.trim()),
        isActive: _isActive,
        imageUrls: _imageUrls,
        createdAt: widget.variant?.createdAt ?? DateTime.now(),
      );
      if (widget.variant == null) {
        await ref.read(firestoreServiceProvider).createCatalogVariant(
              variantData,
            );
      } else {
        await ref
            .read(firestoreServiceProvider)
            .updateCatalogVariant(_variantId, variantData.toMap());
      }
      if (!mounted) return;
      Navigator.of(context).pop();
    } finally {
      if (mounted) {
        _updateUi((state) => state.copyWith(saving: false));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(_variantEditorUiProvider(_variantId));
    final isEdit = widget.variant != null;
    final baseUnits = switch (_unitType) {
      CatalogUnitType.volume => _volumeUnits,
      CatalogUnitType.weight => _weightUnits,
      CatalogUnitType.count => _countUnits,
    };
    final currentBaseUnit = _baseUnitController.text.trim();
    final unitOptions = currentBaseUnit.isNotEmpty &&
            !baseUnits.contains(currentBaseUnit)
        ? [...baseUnits, currentBaseUnit]
        : baseUnits;
    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? 'Edit Variant' : 'Add Variant'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              widget.product.name,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _labelController,
              decoration: const InputDecoration(
                labelText: 'Label',
                hintText: 'Small pack / 1 Liter bottle',
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<CatalogUnitType>(
              initialValue: _unitType,
              decoration: const InputDecoration(labelText: 'Unit Type'),
              items: CatalogUnitType.values
                  .map(
                    (value) => DropdownMenuItem(
                      value: value,
                      child: Text(value.name),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null) {
                  _updateUi((state) => state.copyWith(unitType: value));
                  if (!baseUnits.contains(_baseUnitController.text.trim())) {
                    _baseUnitController.text = baseUnits.first;
                  }
                }
              },
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _baseValueController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Base Value',
                      hintText: 'Example: 1000',
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: unitOptions.contains(currentBaseUnit)
                        ? currentBaseUnit
                        : unitOptions.first,
                    decoration: const InputDecoration(labelText: 'Base Unit'),
                    items: unitOptions
                        .map(
                          (unit) => DropdownMenuItem(
                            value: unit,
                            child: Text(unit),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value == null) return;
                      _baseUnitController.text = value;
                      _updateUi((state) => state.copyWith());
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _priceController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Price',
                      hintText: '100',
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _mrpController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'MRP',
                      hintText: '120',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _stockController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Stock Qty',
                hintText: '50',
              ),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Active'),
              value: _isActive,
              onChanged: (value) =>
                  _updateUi((state) => state.copyWith(isActive: value)),
            ),
            const SizedBox(height: 8),
            Text(
              'Images (${_imageUrls.length})',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            if (_imageUrls.isNotEmpty)
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _imageUrls
                    .map(
                      (url) => Stack(
                        alignment: Alignment.topRight,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              url,
                              width: 88,
                              height: 88,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => Container(
                                width: 88,
                                height: 88,
                                color: Colors.black12,
                                alignment: Alignment.center,
                                child: const Icon(
                                  Icons.image_not_supported_outlined,
                                ),
                              ),
                            ),
                          ),
                          InkWell(
                            onTap: _saving
                                ? null
                                : () => _updateUi((state) {
                                    final next = [...state.imageUrls]
                                      ..remove(url);
                                    return state.copyWith(imageUrls: next);
                                  }),
                            child: const CircleAvatar(
                              radius: 12,
                              backgroundColor: Colors.black54,
                              child: Icon(
                                Icons.close,
                                size: 14,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                    .toList(),
              ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _saving ? null : _pickImages,
              icon: const Icon(Icons.upload),
              label: const Text('Add Images'),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _saving ? null : _saveVariant,
              child: Text(_saving ? 'Saving...' : 'Save Variant'),
            ),
          ],
        ),
      ),
    );
  }
}

enum _ImagePickChoice { camera, gallery }
