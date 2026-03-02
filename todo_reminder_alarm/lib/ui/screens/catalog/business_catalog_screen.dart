import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../models/catalog.dart';
import '../../../providers.dart';
import 'variant_editor_screen.dart';

class BusinessCatalogScreen extends ConsumerWidget {
  const BusinessCatalogScreen({super.key, required this.businessId});

  final String businessId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          const TabBar(
            tabs: [
              Tab(text: 'Products'),
              Tab(text: 'Categories'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _ProductsTab(businessId: businessId),
                _CategoriesTab(businessId: businessId),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoriesTab extends ConsumerWidget {
  const _CategoriesTab({required this.businessId});

  final String businessId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoriesAsync = ref.watch(catalogCategoriesProvider(businessId));
    return categoriesAsync.when(
      data: (categories) {
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Categories',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                FilledButton.icon(
                  onPressed: () =>
                      _showCategoryDialog(context, ref, businessId: businessId),
                  icon: const Icon(Icons.add),
                  label: const Text('Add'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (categories.isEmpty) const Text('No categories yet.'),
            ...categories.map(
              (category) => Card(
                child: ListTile(
                  title: Text(category.name),
                  subtitle: Text(
                    'Sort: ${category.sortOrder} • ${category.isActive ? 'Active' : 'Inactive'}',
                  ),
                  trailing: PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'edit') {
                        _showCategoryDialog(
                          context,
                          ref,
                          businessId: businessId,
                          category: category,
                        );
                      } else if (value == 'delete') {
                        ref
                            .read(firestoreServiceProvider)
                            .deleteCatalogCategory(category.id);
                      }
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'edit', child: Text('Edit')),
                      PopupMenuItem(value: 'delete', child: Text('Delete')),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) =>
          Center(child: Text('Something went wrong. Please retry.')),
    );
  }
}

class _ProductsTab extends ConsumerWidget {
  const _ProductsTab({required this.businessId});

  final String businessId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productsAsync = ref.watch(catalogProductsProvider(businessId));
    final categoriesAsync = ref.watch(catalogCategoriesProvider(businessId));
    return productsAsync.when(
      data: (products) {
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Products',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                FilledButton.icon(
                  onPressed: () => _showProductDialog(
                    context,
                    ref,
                    businessId: businessId,
                    categories: categoriesAsync.value ?? const [],
                  ),
                  icon: const Icon(Icons.add),
                  label: const Text('Add'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (products.isEmpty) const Text('No products yet.'),
            ...products.map(
              (product) => Card(
                child: Column(
                  children: [
                    ListTile(
                      title: Text(product.name),
                      subtitle: Text(
                        'Category: ${_categoryName(categoriesAsync.value, product.categoryId)} • '
                        '${product.isActive ? 'Active' : 'Inactive'}',
                      ),
                      trailing: PopupMenuButton<String>(
                        onSelected: (value) {
                          if (value == 'edit') {
                            _showProductDialog(
                              context,
                              ref,
                              businessId: businessId,
                              categories: categoriesAsync.value ?? const [],
                              product: product,
                            );
                          } else if (value == 'variants') {
                            _showVariantsSheet(
                              context,
                              ref,
                              businessId: businessId,
                              product: product,
                            );
                          } else if (value == 'delete') {
                            ref
                                .read(firestoreServiceProvider)
                                .deleteCatalogProduct(product.id);
                          }
                        },
                        itemBuilder: (_) => const [
                          PopupMenuItem(value: 'edit', child: Text('Edit')),
                          PopupMenuItem(
                            value: 'variants',
                            child: Text('Variants'),
                          ),
                          PopupMenuItem(value: 'delete', child: Text('Delete')),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Consumer(
                          builder: (context, ref, _) {
                            final variantsAsync = ref.watch(
                              catalogVariantsProvider(product.id),
                            );
                            return variantsAsync.when(
                              data: (variants) =>
                                  Text('Variants: ${variants.length}'),
                              loading: () => const Text('Variants: ...'),
                              error: (_, _) =>
                                  const Text('Variants unavailable'),
                            );
                          },
                        ),
                      ),
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
    );
  }
}

Future<void> _showCategoryDialog(
  BuildContext context,
  WidgetRef ref, {
  required String businessId,
  CatalogCategory? category,
}) async {
  final name = TextEditingController(text: category?.name ?? '');
  final sortOrder = TextEditingController(
    text: category?.sortOrder.toString() ?? '0',
  );
  var isActive = category?.isActive ?? true;
  await showDialog<void>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setLocal) => AlertDialog(
        title: Text(category == null ? 'Add Category' : 'Edit Category'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: name,
                decoration: const InputDecoration(labelText: 'Name'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: sortOrder,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Sort Order'),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Active'),
                value: isActive,
                onChanged: (value) => setLocal(() => isActive = value),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final trimmed = name.text.trim();
              if (trimmed.isEmpty) return;
              final sort = int.tryParse(sortOrder.text.trim()) ?? 0;
              if (category == null) {
                final id = const Uuid().v4();
                await ref
                    .read(firestoreServiceProvider)
                    .createCatalogCategory(
                      CatalogCategory(
                        id: id,
                        businessId: businessId,
                        name: trimmed,
                        sortOrder: sort,
                        isActive: isActive,
                        createdAt: DateTime.now(),
                      ),
                    );
              } else {
                await ref.read(firestoreServiceProvider).updateCatalogCategory(
                  category.id,
                  {'name': trimmed, 'sortOrder': sort, 'isActive': isActive},
                );
              }
              if (!context.mounted) return;
              Navigator.of(context).pop();
            },
            child: const Text('Save'),
          ),
        ],
      ),
    ),
  );
}

Future<void> _showProductDialog(
  BuildContext context,
  WidgetRef ref, {
  required String businessId,
  required List<CatalogCategory> categories,
  CatalogProduct? product,
}) async {
  final name = TextEditingController(text: product?.name ?? '');
  final description = TextEditingController(text: product?.description ?? '');
  String? categoryId = product?.categoryId;
  var isActive = product?.isActive ?? true;
  await showDialog<void>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setLocal) => AlertDialog(
        title: Text(product == null ? 'Add Product' : 'Edit Product'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: name,
                decoration: const InputDecoration(labelText: 'Name'),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String?>(
                initialValue: categoryId,
                decoration: const InputDecoration(labelText: 'Category'),
                items: [
                  const DropdownMenuItem(value: null, child: Text('None')),
                  ...categories.map(
                    (c) => DropdownMenuItem(value: c.id, child: Text(c.name)),
                  ),
                ],
                onChanged: (value) => setLocal(() => categoryId = value),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: description,
                decoration: const InputDecoration(labelText: 'Description'),
                maxLines: 3,
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Active'),
                value: isActive,
                onChanged: (value) => setLocal(() => isActive = value),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final trimmed = name.text.trim();
              if (trimmed.isEmpty) return;
              final keywords = _buildSearchKeywords(trimmed);
              if (product == null) {
                final id = const Uuid().v4();
                await ref
                    .read(firestoreServiceProvider)
                    .createCatalogProduct(
                      CatalogProduct(
                        id: id,
                        businessId: businessId,
                        name: trimmed,
                        categoryId: categoryId,
                        description: description.text.trim().isEmpty
                            ? null
                            : description.text.trim(),
                        isActive: isActive,
                        searchKeywords: keywords,
                        createdAt: DateTime.now(),
                      ),
                    );
              } else {
                await ref
                    .read(firestoreServiceProvider)
                    .updateCatalogProduct(product.id, {
                      'name': trimmed,
                      'categoryId': categoryId,
                      'description': description.text.trim().isEmpty
                          ? null
                          : description.text.trim(),
                      'isActive': isActive,
                      'searchKeywords': keywords,
                    });
              }
              if (!context.mounted) return;
              Navigator.of(context).pop();
            },
            child: const Text('Save'),
          ),
        ],
      ),
    ),
  );
}

Future<void> _showVariantsSheet(
  BuildContext context,
  WidgetRef ref, {
  required String businessId,
  required CatalogProduct product,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (context) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      builder: (context, controller) {
        final variantsAsync = ref.watch(catalogVariantsProvider(product.id));
        return Material(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Variants • ${product.name}',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    FilledButton.icon(
                      onPressed: () => _openVariantScreen(
                        context,
                        ref,
                        businessId: businessId,
                        product: product,
                      ),
                      icon: const Icon(Icons.add),
                      label: const Text('Add'),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: variantsAsync.when(
                  data: (variants) {
                    if (variants.isEmpty) {
                      return const Center(child: Text('No variants yet.'));
                    }
                    return ListView(
                      controller: controller,
                      children: variants.map((variant) {
                        final imageCount = variant.imageUrls.length;
                        return Card(
                          margin: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          child: ListTile(
                            leading: _VariantThumb(
                              imageUrls: variant.imageUrls,
                              onTap: imageCount == 0
                                  ? null
                                  : () => _showVariantImageGallery(
                                      context,
                                      variant.imageUrls,
                                      0,
                                    ),
                            ),
                            title: Text(variant.label),
                            subtitle: Text(
                              '${variant.baseValue} ${variant.baseUnit} • Price: ${variant.price}'
                              '${imageCount > 0 ? ' • Images: $imageCount' : ''}',
                            ),
                            trailing: PopupMenuButton<String>(
                              onSelected: (value) {
                                if (value == 'edit') {
                                  _openVariantScreen(
                                    context,
                                    ref,
                                    businessId: businessId,
                                    product: product,
                                    variant: variant,
                                  );
                                } else if (value == 'delete') {
                                  ref
                                      .read(firestoreServiceProvider)
                                      .deleteCatalogVariant(variant.id);
                                }
                              },
                              itemBuilder: (_) => const [
                                PopupMenuItem(
                                  value: 'edit',
                                  child: Text('Edit'),
                                ),
                                PopupMenuItem(
                                  value: 'delete',
                                  child: Text('Delete'),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    );
                  },
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (_, _) => Center(
                    child: Text('Something went wrong. Please retry.'),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    ),
  );
}

Future<void> _openVariantScreen(
  BuildContext context,
  WidgetRef ref, {
  required String businessId,
  required CatalogProduct product,
  CatalogVariant? variant,
}) async {
  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => VariantEditorScreen(
        businessId: businessId,
        product: product,
        variant: variant,
      ),
    ),
  );
}

List<String> _buildSearchKeywords(String value) {
  final normalized = value.trim().toLowerCase();
  if (normalized.isEmpty) return const [];
  final parts = normalized.split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
  return parts.toSet().toList();
}

String _categoryName(List<CatalogCategory>? categories, String? categoryId) {
  if (categoryId == null || categoryId.isEmpty) return '-';
  if (categories == null || categories.isEmpty) return categoryId;
  final match = categories.where((c) => c.id == categoryId).toList();
  if (match.isEmpty) return categoryId;
  return match.first.name;
}

class _VariantThumb extends StatelessWidget {
  const _VariantThumb({required this.imageUrls, this.onTap});

  final List<String> imageUrls;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    if (imageUrls.isEmpty) {
      return const CircleAvatar(radius: 24, child: Icon(Icons.image_outlined));
    }
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.network(
              imageUrls.first,
              width: 48,
              height: 48,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => const SizedBox(
                width: 48,
                height: 48,
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

Future<void> _showVariantImageGallery(
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
