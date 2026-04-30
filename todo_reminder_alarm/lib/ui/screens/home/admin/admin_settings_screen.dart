import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart' show StateProvider;

import 'package:todo_reminder_alarm/models/app_update_config.dart';
import 'package:todo_reminder_alarm/models/order_unit.dart';
import 'package:todo_reminder_alarm/providers.dart';

part 'admin_settings_actions.dart';
part 'admin_settings_sections.dart';
part 'admin_settings_edit_order_unit_dialog.dart';

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
                _buildAppUpdateSettingsCard(
                  context,
                  currentVersion: currentVersionAsync.value,
                  enabled: enabled,
                  saving: saving,
                  showAdsAdmin: showAdsAdmin,
                  showAdsBusiness: showAdsBusiness,
                  showAdsCustomer: showAdsCustomer,
                  showAdsDelivery: showAdsDelivery,
                ),
                const SizedBox(height: 12),
                _buildAdsSettingsCard(
                  context,
                  saving: saving,
                  showAdsAdmin: showAdsAdmin,
                  showAdsBusiness: showAdsBusiness,
                  showAdsCustomer: showAdsCustomer,
                  showAdsDelivery: showAdsDelivery,
                ),
                const SizedBox(height: 12),
                _buildOrderUnitsCard(
                  context,
                  orderUnitsAsync: orderUnitsAsync,
                  savingOrderUnit: savingOrderUnit,
                  processingUnitCode: processingUnitCode,
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
