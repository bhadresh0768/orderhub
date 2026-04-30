part of 'admin_settings_screen.dart';

extension _AdminSettingsSections on _AdminSettingsScreenState {
  Widget _buildAppUpdateSettingsCard(
    BuildContext context, {
    required String? currentVersion,
    required bool enabled,
    required bool saving,
    required bool showAdsAdmin,
    required bool showAdsBusiness,
    required bool showAdsCustomer,
    required bool showAdsDelivery,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('App Update Settings', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              'When latest version is higher than installed version, users will see an update popup.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            Text(
              'Current app version: ${currentVersion ?? '-'}',
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
                      ref.read(_adminSettingsEnabledOverrideProvider.notifier).state = value;
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
                      if (!RegExp(r'^\d+(\.\d+){0,2}$').hasMatch(text)) {
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
                      hintText: 'https://play.google.com/store/apps/details?id=...',
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
                    textCapitalization: TextCapitalization.sentences,
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
                              child: CircularProgressIndicator(strokeWidth: 2),
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
    );
  }

  Widget _buildAdsSettingsCard(
    BuildContext context, {
    required bool saving,
    required bool showAdsAdmin,
    required bool showAdsBusiness,
    required bool showAdsCustomer,
    required bool showAdsDelivery,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Ads Settings', style: Theme.of(context).textTheme.titleLarge),
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
                      ref.read(_adminSettingsShowAdsAdminOverrideProvider.notifier).state = value;
                    },
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Show ads for Business'),
              value: showAdsBusiness,
              onChanged: saving
                  ? null
                  : (value) {
                      ref.read(_adminSettingsShowAdsBusinessOverrideProvider.notifier).state = value;
                    },
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Show ads for Customer'),
              value: showAdsCustomer,
              onChanged: saving
                  ? null
                  : (value) {
                      ref.read(_adminSettingsShowAdsCustomerOverrideProvider.notifier).state = value;
                    },
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Show ads for Delivery'),
              value: showAdsDelivery,
              onChanged: saving
                  ? null
                  : (value) {
                      ref.read(_adminSettingsShowAdsDeliveryOverrideProvider.notifier).state = value;
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
    );
  }

  Widget _buildOrderUnitsCard(
    BuildContext context, {
    required AsyncValue<List<OrderUnit>> orderUnitsAsync,
    required bool savingOrderUnit,
    required String? processingUnitCode,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Order Units', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              'Manage units used in order item dropdown (for example: piece, kg, liter, tray).',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 10),
            orderUnitsAsync.when(
              loading: () => const LinearProgressIndicator(minHeight: 2),
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
                      subtitle: Text('Code: ${unit.code} • Sort: ${unit.sortOrder}'),
                      trailing: SizedBox(
                        width: 96,
                        child: rowBusy
                            ? const Align(
                                alignment: Alignment.centerRight,
                                child: SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                ),
                              )
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  IconButton(
                                    tooltip: 'Edit',
                                    onPressed: () => _editOrderUnit(unit),
                                    icon: const Icon(Icons.edit),
                                  ),
                                  IconButton(
                                    tooltip: 'Delete',
                                    onPressed: () => _deleteOrderUnit(unit),
                                    icon: const Icon(Icons.delete_outline),
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
                label: Text(savingOrderUnit ? 'Saving...' : 'Add Unit'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
