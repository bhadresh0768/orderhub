part of 'create_order_screen.dart';

extension _CreateOrderCatalogActions on _CreateOrderScreenState {
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
          (state) =>
              state.copyWith(itemSuggestions: local, loadingSuggestions: false),
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

  List<OrderUnit> _defaultOrderUnits() {
    return [
          QuantityUnit.piece,
          QuantityUnit.box,
          QuantityUnit.kilogram,
          QuantityUnit.gram,
          QuantityUnit.liter,
          QuantityUnit.ton,
          QuantityUnit.packet,
          QuantityUnit.bag,
          QuantityUnit.bottle,
          QuantityUnit.can,
          QuantityUnit.meter,
          QuantityUnit.foot,
          QuantityUnit.carton,
        ]
        .map(
          (unit) => OrderUnit(
            code: quantityUnitCode(unit),
            label: quantityUnitDefaultLabel(unit),
            symbol: quantityUnitDefaultSymbol(unit),
            isActive: true,
          ),
        )
        .toList();
  }

  List<OrderUnit> _mergedOrderUnits(List<OrderUnit> firebaseUnits) {
    final byCode = <String, OrderUnit>{};
    for (final unit in _defaultOrderUnits()) {
      byCode[unit.code] = unit;
    }
    for (final unit in firebaseUnits) {
      final code = unit.code.trim().toLowerCase();
      if (code.isEmpty) continue;
      byCode[code] = unit;
    }
    final units = byCode.values.toList();
    units.sort((a, b) {
      final byOrder = a.sortOrder.compareTo(b.sortOrder);
      if (byOrder != 0) return byOrder;
      return a.label.toLowerCase().compareTo(b.label.toLowerCase());
    });
    return units;
  }

  String _itemQuantityLabel(OrderItem item) {
    return '${_formatQuantity(item.quantity)} ${item.displayUnitSymbol}';
  }

  OrderUnit _resolveSelectedUnit(List<OrderUnit> availableUnits) {
    for (final unit in availableUnits) {
      if (unit.code == _ui.itemUnitCode) return unit;
    }
    final fallbackLabel = _ui.itemUnitLabel?.trim();
    final fallbackSymbol = _ui.itemUnitSymbol?.trim();
    return OrderUnit(
      code: _ui.itemUnitCode,
      label: (fallbackLabel == null || fallbackLabel.isEmpty)
          ? 'Custom Unit'
          : fallbackLabel,
      symbol: fallbackSymbol ?? '',
      isActive: true,
    );
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
}
