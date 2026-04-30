part of 'admin_settings_screen.dart';

extension _AdminSettingsActions on _AdminSettingsScreenState {
  String _normalizeCode(String input) {
    return input
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'\s+'), '-')
        .replaceAll(RegExp(r'[^a-z0-9_-]'), '');
  }

  Future<void> _editOrderUnit(OrderUnit unit) async {
    final updated = await showDialog<OrderUnit>(
      context: context,
      builder: (_) =>
          _EditOrderUnitDialog(unit: unit, normalizeCode: _normalizeCode),
    );

    if (updated == null || !mounted) return;

    ref.read(_adminSettingsProcessingUnitCodeProvider.notifier).state = unit.code;
    try {
      await ref
          .read(firestoreServiceProvider)
          .renameOrderUnit(oldCode: unit.code, next: updated);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Order unit updated')));
    } catch (err) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to update unit: $err')));
    } finally {
      if (mounted) {
        ref.read(_adminSettingsProcessingUnitCodeProvider.notifier).state = null;
      }
    }
  }

  Future<void> _deleteOrderUnit(OrderUnit unit) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete Unit'),
          content: Text('Delete "${unit.displayLabel}"?'),
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
    if (confirm != true || !mounted) return;

    ref.read(_adminSettingsProcessingUnitCodeProvider.notifier).state = unit.code;
    try {
      await ref.read(firestoreServiceProvider).deleteOrderUnit(unit.code);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Order unit deleted')));
    } catch (err) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to delete unit: $err')));
    } finally {
      if (mounted) {
        ref.read(_adminSettingsProcessingUnitCodeProvider.notifier).state = null;
      }
    }
  }

  Future<void> _saveOrderUnit() async {
    final savingOrderUnit = ref.read(_adminSettingsSavingOrderUnitProvider);
    if (savingOrderUnit) return;
    final label = _unitLabelController.text.trim();
    final fallbackCode = _normalizeCode(label);
    final codeInput = _normalizeCode(_unitCodeController.text);
    final code = codeInput.isEmpty ? fallbackCode : codeInput;
    final symbolInput = _unitSymbolController.text.trim();
    final symbol = symbolInput.isEmpty ? label : symbolInput;
    final sortOrder = int.tryParse(_unitSortController.text.trim()) ?? 0;
    if (label.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Unit name is required')));
      return;
    }
    if (code.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter a valid unit name or code (letters/numbers)'),
        ),
      );
      return;
    }
    ref.read(_adminSettingsSavingOrderUnitProvider.notifier).state = true;
    try {
      await ref.read(firestoreServiceProvider).createOrderUnit(
            OrderUnit(
              code: code,
              label: label,
              symbol: symbol,
              sortOrder: sortOrder,
              isActive: true,
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            ),
          );
      if (!mounted) return;
      _unitCodeController.clear();
      _unitLabelController.clear();
      _unitSymbolController.clear();
      _unitSortController.text = '0';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Order unit added')));
    } catch (err) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to add unit: $err')));
    } finally {
      if (mounted) {
        ref.read(_adminSettingsSavingOrderUnitProvider.notifier).state = false;
      }
    }
  }

  void _initFromConfig(AppUpdateConfig? config) {
    if (_didInit) return;
    _didInit = true;
    if (config == null) return;
    _versionController.text = config.latestVersion;
    _storeUrlController.text = config.storeUrl;
    _notesController.text = config.notes ?? '';
  }

  Future<void> _save({
    required bool enabled,
    required bool showAdsAdmin,
    required bool showAdsBusiness,
    required bool showAdsCustomer,
    required bool showAdsDelivery,
  }) async {
    if (!_formKey.currentState!.validate()) return;
    ref.read(_adminSettingsSavingProvider.notifier).state = true;
    try {
      await ref.read(firestoreServiceProvider).setAppUpdateConfig(
            AppUpdateConfig(
              latestVersion: _versionController.text.trim(),
              storeUrl: _storeUrlController.text.trim(),
              notes: _notesController.text.trim().isEmpty
                  ? null
                  : _notesController.text.trim(),
              enabled: enabled,
              showAds:
                  showAdsAdmin ||
                  showAdsBusiness ||
                  showAdsCustomer ||
                  showAdsDelivery,
              showAdsAdmin: showAdsAdmin,
              showAdsBusiness: showAdsBusiness,
              showAdsCustomer: showAdsCustomer,
              showAdsDelivery: showAdsDelivery,
            ),
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('App update settings saved')),
      );
    } catch (err) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to save settings: $err')));
    } finally {
      if (mounted) {
        ref.read(_adminSettingsSavingProvider.notifier).state = false;
      }
    }
  }

  Future<void> _saveShowAds({
    required bool showAdsAdmin,
    required bool showAdsBusiness,
    required bool showAdsCustomer,
    required bool showAdsDelivery,
  }) async {
    ref.read(_adminSettingsSavingProvider.notifier).state = true;
    try {
      await ref.read(firestoreServiceProvider).setShowAdsConfig(
            showAdsAdmin: showAdsAdmin,
            showAdsBusiness: showAdsBusiness,
            showAdsCustomer: showAdsCustomer,
            showAdsDelivery: showAdsDelivery,
          );
      if (!mounted) return;
      final enabledCount = [
        showAdsAdmin,
        showAdsBusiness,
        showAdsCustomer,
        showAdsDelivery,
      ].where((e) => e).length;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            enabledCount == 0
                ? 'Ads hidden for all user categories'
                : 'Ads enabled for $enabledCount user categor${enabledCount == 1 ? 'y' : 'ies'}',
          ),
        ),
      );
    } catch (err) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save ad settings: $err')),
      );
    } finally {
      if (mounted) {
        ref.read(_adminSettingsSavingProvider.notifier).state = false;
      }
    }
  }
}
