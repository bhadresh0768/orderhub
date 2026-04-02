import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart' show StateProvider;

import 'package:todo_reminder_alarm/models/app_update_config.dart';
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

  bool _didInit = false;

  @override
  void dispose() {
    _versionController.dispose();
    _storeUrlController.dispose();
    _notesController.dispose();
    super.dispose();
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
              ],
            );
          },
        ),
      ),
    );
  }
}
