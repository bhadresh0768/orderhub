import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart' show StateProvider;

import '../../../models/app_user.dart';
import '../../../models/business.dart';
import '../../../models/catalog.dart';
import '../../../models/enums.dart';
import '../../../models/order.dart';
import '../../../providers.dart';
import '../orders/create_order_screen.dart';

final _customerCatalogUiProvider = StateProvider.autoDispose
    .family<_CustomerCatalogUiState, String>(
      (ref, _) => const _CustomerCatalogUiState(),
    );

class _CustomerCatalogUiState {
  const _CustomerCatalogUiState({this.selected = const {}});

  final Map<String, _SelectedVariant> selected;

  _CustomerCatalogUiState copyWith({Map<String, _SelectedVariant>? selected}) {
    return _CustomerCatalogUiState(selected: selected ?? this.selected);
  }
}

class CustomerCatalogScreen extends ConsumerWidget {
  const CustomerCatalogScreen({
    super.key,
    required this.business,
    required this.customer,
    this.requesterBusiness,
  });

  final BusinessProfile business;
  final AppUser customer;
  final BusinessProfile? requesterBusiness;

  String get _uiKey => '${business.id}_${customer.id}';

  int _selectedQty(
    Map<String, _SelectedVariant> selected,
    CatalogVariant variant,
  ) {
    return selected[variant.id]?.quantity ?? 0;
  }

  int _totalSelected(Map<String, _SelectedVariant> selected) {
    return selected.values.fold(0, (sum, item) => sum + item.quantity);
  }

  void _incrementVariant(
    WidgetRef ref,
    Map<String, _SelectedVariant> selected,
    CatalogProduct product,
    CatalogVariant variant,
  ) {
    final next = Map<String, _SelectedVariant>.from(selected);
    final existing = next[variant.id];
    if (existing == null) {
      next[variant.id] = _SelectedVariant(
        variantId: variant.id,
        productName: product.name,
        variantLabel: variant.label,
        baseValue: variant.baseValue,
        baseUnit: variant.baseUnit,
        unitType: variant.unitType,
        quantity: 1,
      );
    } else {
      next[variant.id] = existing.copyWith(quantity: existing.quantity + 1);
    }
    ref.read(_customerCatalogUiProvider(_uiKey).notifier).state =
        _CustomerCatalogUiState(selected: next);
  }

  void _decrementVariant(
    WidgetRef ref,
    Map<String, _SelectedVariant> selected,
    CatalogVariant variant,
  ) {
    final next = Map<String, _SelectedVariant>.from(selected);
    final existing = next[variant.id];
    if (existing == null) return;
    if (existing.quantity <= 1) {
      next.remove(variant.id);
    } else {
      next[variant.id] = existing.copyWith(quantity: existing.quantity - 1);
    }
    ref.read(_customerCatalogUiProvider(_uiKey).notifier).state =
        _CustomerCatalogUiState(selected: next);
  }

  Future<void> _proceedToOrder(
    BuildContext context,
    WidgetRef ref,
    Map<String, _SelectedVariant> selected,
  ) async {
    if (selected.isEmpty) return;
    final items = selected.values.map((entry) {
      final packSize = '${entry.baseValue} ${entry.baseUnit}';
      return OrderItem(
        title: '${entry.productName} • ${entry.variantLabel}',
        quantity: entry.quantity.toDouble(),
        unit: QuantityUnit.piece,
        packSize: packSize,
        note: null,
        attachments: const [],
        unitPrice: null,
        gstIncluded: null,
        isIncluded: true,
        unavailableReason: null,
      );
    }).toList();
    final orderId = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => CreateOrderScreen(
          business: business,
          customer: customer,
          requesterBusiness: requesterBusiness,
          initialItems: items,
        ),
      ),
    );
    if (!context.mounted || orderId == null) return;
    ref.read(_customerCatalogUiProvider(_uiKey).notifier).state =
        const _CustomerCatalogUiState();
    Navigator.of(context).pop(orderId);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ui = ref.watch(_customerCatalogUiProvider(_uiKey));
    final selected = ui.selected;
    final productsAsync = ref.watch(catalogProductsProvider(business.id));
    final categoriesAsync = ref.watch(catalogCategoriesProvider(business.id));
    return Scaffold(
      appBar: AppBar(title: Text('${business.name} Catalog')),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: FilledButton(
            onPressed: selected.isEmpty
                ? null
                : () => _proceedToOrder(context, ref, selected),
            child: Text(
              selected.isEmpty
                  ? 'Select items to proceed'
                  : 'Proceed to Order (${_totalSelected(selected)} items)',
            ),
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        child: productsAsync.when(
          data: (products) {
            if (products.isEmpty) {
              return const Center(child: Text('No catalog items yet.'));
            }
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                ...products.map(
                  (product) => Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ExpansionTile(
                      title: Text(product.name),
                      subtitle: Text(
                        'Category: ${_categoryName(categoriesAsync.value, product.categoryId)}',
                      ),
                      children: [
                        if ((product.description ?? '').trim().isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                            child: Text(product.description!.trim()),
                          ),
                        _ProductVariantsList(
                          product: product,
                          selectedQty: (variant) =>
                              _selectedQty(selected, variant),
                          onAdd: (p, variant) =>
                              _incrementVariant(ref, selected, p, variant),
                          onRemove: (variant) =>
                              _decrementVariant(ref, selected, variant),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) =>
              Center(child: Text('Something went wrong. Please retry.')),
        ),
      ),
    );
  }
}

class _ProductVariantsList extends ConsumerWidget {
  const _ProductVariantsList({
    required this.product,
    required this.selectedQty,
    required this.onAdd,
    required this.onRemove,
  });

  final CatalogProduct product;
  final int Function(CatalogVariant variant) selectedQty;
  final void Function(CatalogProduct product, CatalogVariant variant) onAdd;
  final void Function(CatalogVariant variant) onRemove;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final variantsAsync = ref.watch(catalogVariantsProvider(product.id));
    return variantsAsync.when(
      data: (variants) {
        if (variants.isEmpty) {
          return const Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Text('No variants available.'),
          );
        }
        return Column(
          children: variants.map((variant) {
            final unitLabel = '${variant.baseValue} ${variant.baseUnit}';
            final qty = selectedQty(variant);
            return ListTile(
              leading: _VariantImagePreview(imageUrls: variant.imageUrls),
              title: Text(variant.label),
              subtitle: Text(unitLabel),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    onPressed: qty > 0 ? () => onRemove(variant) : null,
                    icon: const Icon(Icons.remove_circle_outline),
                  ),
                  Text(qty.toString()),
                  IconButton(
                    onPressed: () => onAdd(product, variant),
                    icon: const Icon(Icons.add_circle_outline),
                  ),
                ],
              ),
            );
          }).toList(),
        );
      },
      loading: () => const Padding(
        padding: EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: Text('Loading variants...'),
      ),
      error: (_, _) => const Padding(
        padding: EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: Text('Variants unavailable'),
      ),
    );
  }
}

String _categoryName(List<CatalogCategory>? categories, String? categoryId) {
  if (categoryId == null || categoryId.isEmpty) return '-';
  if (categories == null || categories.isEmpty) return categoryId;
  final match = categories.where((c) => c.id == categoryId).toList();
  if (match.isEmpty) return categoryId;
  return match.first.name;
}

class _SelectedVariant {
  const _SelectedVariant({
    required this.variantId,
    required this.productName,
    required this.variantLabel,
    required this.baseValue,
    required this.baseUnit,
    required this.unitType,
    required this.quantity,
  });

  final String variantId;
  final String productName;
  final String variantLabel;
  final int baseValue;
  final String baseUnit;
  final CatalogUnitType unitType;
  final int quantity;

  _SelectedVariant copyWith({int? quantity}) {
    return _SelectedVariant(
      variantId: variantId,
      productName: productName,
      variantLabel: variantLabel,
      baseValue: baseValue,
      baseUnit: baseUnit,
      unitType: unitType,
      quantity: quantity ?? this.quantity,
    );
  }
}

class _VariantImagePreview extends StatelessWidget {
  const _VariantImagePreview({required this.imageUrls});

  final List<String> imageUrls;

  @override
  Widget build(BuildContext context) {
    if (imageUrls.isEmpty) {
      return const CircleAvatar(radius: 22, child: Icon(Icons.image_outlined));
    }
    return GestureDetector(
      onTap: () => _showCatalogImageGallery(context, imageUrls, 0),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(
              imageUrls.first,
              width: 44,
              height: 44,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => const SizedBox(
                width: 44,
                height: 44,
                child: Icon(Icons.broken_image_outlined),
              ),
            ),
          ),
          if (imageUrls.length > 1)
            Positioned(
              right: 2,
              top: 2,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.black87,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  child: Text(
                    '${imageUrls.length}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

Future<void> _showCatalogImageGallery(
  BuildContext context,
  List<String> imageUrls,
  int initialIndex,
) async {
  var currentIndex = initialIndex;
  await showDialog<void>(
    context: context,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setLocal) => Dialog.fullscreen(
          child: Stack(
            children: [
              PageView.builder(
                controller: PageController(initialPage: initialIndex),
                itemCount: imageUrls.length,
                onPageChanged: (index) => setLocal(() => currentIndex = index),
                itemBuilder: (context, index) {
                  return Center(
                    child: InteractiveViewer(
                      child: Image.network(
                        imageUrls[index],
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
              Positioned(
                top: 16,
                right: 16,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    child: Text(
                      '${currentIndex + 1} / ${imageUrls.length}',
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
