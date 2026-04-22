import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart' show StateProvider;

import 'package:todo_reminder_alarm/models/app_update_config.dart';
import 'package:todo_reminder_alarm/models/order_unit.dart';
import 'package:todo_reminder_alarm/providers.dart';

final _adminSettingsSavingProvider = StateProvider.autoDispose<bool>(
  (ref) => false,
);
final _adminSettingsEnabledOverrideProvider = StateProvider.autoDispose<bool?>(
  (ref) => null,
);
final _adminSettingsShowAdsAdminOverrideProvider =
    StateProvider.autoDispose<bool?>((ref) => null);
final _adminSettingsShowAdsBusinessOverrideProvider =
    StateProvider.autoDispose<bool?>((ref) => null);
final _adminSettingsShowAdsCustomerOverrideProvider =
    StateProvider.autoDispose<bool?>((ref) => null);
final _adminSettingsShowAdsDeliveryOverrideProvider =
    StateProvider.autoDispose<bool?>((ref) => null);
final _adminSettingsSavingOrderUnitProvider = StateProvider.autoDispose<bool>(
  (ref) => false,
);
final _adminSettingsProcessingUnitCodeProvider =
    StateProvider.autoDispose<String?>((ref) => null);

class AdminSettingsScreen extends ConsumerStatefulWidget {
  const AdminSettingsScreen({super.key});

  @override
  ConsumerState<AdminSettingsScreen> createState() =>
      _AdminSettingsScreenState();
}

class _AdminSettingsScreenState extends ConsumerState<AdminSettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _versionController = TextEditingController();
  final _storeUrlController = TextEditingController();
  final _notesController = TextEditingController();
  final _unitCodeController = TextEditingController();
  final _unitLabelController = TextEditingController();
  final _unitSymbolController = TextEditingController();
  final _unitSortController = TextEditingController(text: '0');

  bool _didInit = false;
  @override
  void dispose() {
    _versionController.dispose();
    _storeUrlController.dispose();
    _notesController.dispose();
    _unitCodeController.dispose();
    _unitLabelController.dispose();
    _unitSymbolController.dispose();
    _unitSortController.dispose();
    super.dispose();
  }

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

    ref.read(_adminSettingsProcessingUnitCodeProvider.notifier).state =
        unit.code;
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
        ref.read(_adminSettingsProcessingUnitCodeProvider.notifier).state =
            null;
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

    ref.read(_adminSettingsProcessingUnitCodeProvider.notifier).state =
        unit.code;
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
        ref.read(_adminSettingsProcessingUnitCodeProvider.notifier).state =
            null;
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
      await ref
          .read(firestoreServiceProvider)
          .createOrderUnit(
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
      await ref
          .read(firestoreServiceProvider)
          .setAppUpdateConfig(
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
      await ref
          .read(firestoreServiceProvider)
          .setShowAdsConfig(
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

  @override
  Widget build(BuildContext context) {
    final configAsync = ref.watch(appUpdateConfigProvider);
    final currentVersionAsync = ref.watch(appVersionProvider);
    final saving = ref.watch(_adminSettingsSavingProvider);
    final enabledOverride = ref.watch(_adminSettingsEnabledOverrideProvider);
    final showAdsAdminOverride = ref.watch(
      _adminSettingsShowAdsAdminOverrideProvider,
    );
    final showAdsBusinessOverride = ref.watch(
      _adminSettingsShowAdsBusinessOverrideProvider,
    );
    final showAdsCustomerOverride = ref.watch(
      _adminSettingsShowAdsCustomerOverrideProvider,
    );
    final showAdsDeliveryOverride = ref.watch(
      _adminSettingsShowAdsDeliveryOverrideProvider,
    );
    final orderUnitsAsync = ref.watch(allOrderUnitsProvider);
    final savingOrderUnit = ref.watch(_adminSettingsSavingOrderUnitProvider);
    final processingUnitCode = ref.watch(
      _adminSettingsProcessingUnitCodeProvider,
    );
    return Scaffold(
      appBar: AppBar(title: const Text('Admin Settings')),
      body: SafeArea(
        top: false,
        child: configAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, _) => Center(child: Text('Error: $err')),
          data: (config) {
            _initFromConfig(config);
            final enabled = enabledOverride ?? config?.enabled ?? true;
            final legacyShowAds = config?.showAds ?? false;
            final showAdsAdmin =
                showAdsAdminOverride ?? config?.showAdsAdmin ?? legacyShowAds;
            final showAdsBusiness =
                showAdsBusinessOverride ??
                config?.showAdsBusiness ??
                legacyShowAds;
            final showAdsCustomer =
                showAdsCustomerOverride ??
                config?.showAdsCustomer ??
                legacyShowAds;
            final showAdsDelivery =
                showAdsDeliveryOverride ??
                config?.showAdsDelivery ??
                legacyShowAds;
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'App Update Settings',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'When latest version is higher than installed version, users will see an update popup.',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Current app version: ${currentVersionAsync.value ?? '-'}',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 10),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Enable update popup'),
                          value: enabled,
                          onChanged: saving
                              ? null
                              : (value) {
                                  ref
                                          .read(
                                            _adminSettingsEnabledOverrideProvider
                                                .notifier,
                                          )
                                          .state =
                                      value;
                                },
                        ),
                        Form(
                          key: _formKey,
                          child: Column(
                            children: [
                              TextFormField(
                                controller: _versionController,
                                decoration: const InputDecoration(
                                  labelText: 'Latest Version',
                                  hintText: 'e.g. 1.0.3',
                                ),
                                validator: (value) {
                                  final text = value?.trim() ?? '';
                                  if (text.isEmpty) {
                                    return 'Enter latest version';
                                  }
                                  if (!RegExp(
                                    r'^\d+(\.\d+){0,2}$',
                                  ).hasMatch(text)) {
                                    return 'Use version like 1.0.3';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 10),
                              TextFormField(
                                controller: _storeUrlController,
                                decoration: const InputDecoration(
                                  labelText: 'Store URL',
                                  hintText:
                                      'https://play.google.com/store/apps/details?id=...',
                                ),
                                validator: (value) {
                                  final text = value?.trim() ?? '';
                                  if (text.isEmpty) return 'Enter store URL';
                                  if (!text.startsWith('http')) {
                                    return 'Enter valid URL starting with http';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 10),
                              TextFormField(
                                controller: _notesController,
                                maxLines: 2,
                                textCapitalization:
                                    TextCapitalization.sentences,
                                decoration: const InputDecoration(
                                  labelText: 'Update Note (optional)',
                                  hintText: 'What is new in this update?',
                                ),
                              ),
                              const SizedBox(height: 14),
                              SizedBox(
                                width: double.infinity,
                                child: FilledButton(
                                  onPressed: saving
                                      ? null
                                      : () => _save(
                                          enabled: enabled,
                                          showAdsAdmin: showAdsAdmin,
                                          showAdsBusiness: showAdsBusiness,
                                          showAdsCustomer: showAdsCustomer,
                                          showAdsDelivery: showAdsDelivery,
                                        ),
                                  child: saving
                                      ? const SizedBox(
                                          height: 16,
                                          width: 16,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Text('Save Update Settings'),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Ads Settings',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Enable/disable bottom banner ads by user category.',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 10),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Show ads for Admin'),
                          value: showAdsAdmin,
                          onChanged: saving
                              ? null
                              : (value) {
                                  ref
                                          .read(
                                            _adminSettingsShowAdsAdminOverrideProvider
                                                .notifier,
                                          )
                                          .state =
                                      value;
                                },
                        ),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Show ads for Business'),
                          value: showAdsBusiness,
                          onChanged: saving
                              ? null
                              : (value) {
                                  ref
                                          .read(
                                            _adminSettingsShowAdsBusinessOverrideProvider
                                                .notifier,
                                          )
                                          .state =
                                      value;
                                },
                        ),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Show ads for Customer'),
                          value: showAdsCustomer,
                          onChanged: saving
                              ? null
                              : (value) {
                                  ref
                                          .read(
                                            _adminSettingsShowAdsCustomerOverrideProvider
                                                .notifier,
                                          )
                                          .state =
                                      value;
                                },
                        ),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Show ads for Delivery'),
                          value: showAdsDelivery,
                          onChanged: saving
                              ? null
                              : (value) {
                                  ref
                                          .read(
                                            _adminSettingsShowAdsDeliveryOverrideProvider
                                                .notifier,
                                          )
                                          .state =
                                      value;
                                },
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            onPressed: saving
                                ? null
                                : () => _saveShowAds(
                                    showAdsAdmin: showAdsAdmin,
                                    showAdsBusiness: showAdsBusiness,
                                    showAdsCustomer: showAdsCustomer,
                                    showAdsDelivery: showAdsDelivery,
                                  ),
                            child: const Text('Save Ads Settings'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Order Units',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Manage units used in order item dropdown (for example: piece, kg, liter, tray).',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 10),
                        orderUnitsAsync.when(
                          loading: () =>
                              const LinearProgressIndicator(minHeight: 2),
                          error: (err, _) => Text(
                            'Unable to load units: $err',
                            style: const TextStyle(color: Colors.red),
                          ),
                          data: (units) {
                            if (units.isEmpty) {
                              return const Text('No units configured yet.');
                            }
                            return Column(
                              children: units.map((unit) {
                                final rowBusy = processingUnitCode == unit.code;
                                return ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: Text(unit.displayLabel),
                                  subtitle: Text(
                                    'Code: ${unit.code} • Sort: ${unit.sortOrder}',
                                  ),
                                  trailing: SizedBox(
                                    width: 96,
                                    child: rowBusy
                                        ? const Align(
                                            alignment: Alignment.centerRight,
                                            child: SizedBox(
                                              width: 20,
                                              height: 20,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                              ),
                                            ),
                                          )
                                        : Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.end,
                                            children: [
                                              IconButton(
                                                tooltip: 'Edit',
                                                onPressed: () =>
                                                    _editOrderUnit(unit),
                                                icon: const Icon(Icons.edit),
                                              ),
                                              IconButton(
                                                tooltip: 'Delete',
                                                onPressed: () =>
                                                    _deleteOrderUnit(unit),
                                                icon: const Icon(
                                                  Icons.delete_outline,
                                                ),
                                              ),
                                            ],
                                          ),
                                  ),
                                );
                              }).toList(),
                            );
                          },
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _unitLabelController,
                          textCapitalization: TextCapitalization.words,
                          decoration: const InputDecoration(
                            labelText: 'Unit Name',
                            hintText: 'Example: Tray',
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: _unitCodeController,
                          textCapitalization: TextCapitalization.none,
                          decoration: const InputDecoration(
                            labelText: 'Unit Code (optional)',
                            hintText: 'Auto from name if empty',
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: _unitSymbolController,
                          decoration: const InputDecoration(
                            labelText: 'Unit Symbol (optional)',
                            hintText: 'Defaults to unit name if empty',
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: _unitSortController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Sort Order (optional)',
                            hintText: '0',
                          ),
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: savingOrderUnit ? null : _saveOrderUnit,
                            icon: const Icon(Icons.add),
                            label: Text(
                              savingOrderUnit ? 'Saving...' : 'Add Unit',
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
        ),
      ),
    );
  }
}

class _EditOrderUnitDialog extends StatefulWidget {
  const _EditOrderUnitDialog({required this.unit, required this.normalizeCode});

  final OrderUnit unit;
  final String Function(String input) normalizeCode;

  @override
  State<_EditOrderUnitDialog> createState() => _EditOrderUnitDialogState();
}

class _EditOrderUnitDialogState extends State<_EditOrderUnitDialog> {
  late final TextEditingController _codeController;
  late final TextEditingController _labelController;
  late final TextEditingController _symbolController;
  late final TextEditingController _sortController;

  @override
  void initState() {
    super.initState();
    _codeController = TextEditingController(text: widget.unit.code);
    _labelController = TextEditingController(text: widget.unit.label);
    _symbolController = TextEditingController(text: widget.unit.symbol);
    _sortController = TextEditingController(
      text: widget.unit.sortOrder.toString(),
    );
  }

  @override
  void dispose() {
    _codeController.dispose();
    _labelController.dispose();
    _symbolController.dispose();
    _sortController.dispose();
    super.dispose();
  }

  void _save() {
    final label = _labelController.text.trim();
    if (label.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Unit name is required')));
      return;
    }
    final fallbackCode = widget.normalizeCode(label);
    final codeInput = widget.normalizeCode(_codeController.text);
    final code = codeInput.isEmpty ? fallbackCode : codeInput;
    if (code.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter a valid unit name or code (letters/numbers)'),
        ),
      );
      return;
    }
    final symbol = _symbolController.text.trim().isEmpty
        ? label
        : _symbolController.text.trim();
    final sortOrder = int.tryParse(_sortController.text.trim()) ?? 0;
    Navigator.of(context).pop(
      OrderUnit(
        code: code,
        label: label,
        symbol: symbol,
        sortOrder: sortOrder,
        isActive: widget.unit.isActive,
        createdAt: widget.unit.createdAt,
        updatedAt: DateTime.now(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit Unit'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _labelController,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Unit Name',
                hintText: 'Example: Tray',
              ),
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _codeController,
              textCapitalization: TextCapitalization.none,
              decoration: const InputDecoration(
                labelText: 'Unit Code (optional)',
                hintText: 'Auto from name if empty',
              ),
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _symbolController,
              decoration: const InputDecoration(
                labelText: 'Unit Symbol (optional)',
                hintText: 'Defaults to unit name if empty',
              ),
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _sortController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Sort Order (optional)',
                hintText: '0',
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _save, child: const Text('Save')),
      ],
    );
  }
}
