import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:todo_reminder_alarm/models/app_update_config.dart';
import 'package:todo_reminder_alarm/providers.dart';

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
  bool _enabled = true;
  bool _saving = false;

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
    _enabled = config.enabled;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
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
              enabled: _enabled,
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
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final configAsync = ref.watch(appUpdateConfigProvider);
    final currentVersionAsync = ref.watch(appVersionProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Admin Settings')),
      body: SafeArea(
        top: false,
        child: configAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, _) => Center(child: Text('Error: $err')),
          data: (config) {
            _initFromConfig(config);
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
                          value: _enabled,
                          onChanged: _saving
                              ? null
                              : (value) => setState(() => _enabled = value),
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
                                decoration: const InputDecoration(
                                  labelText: 'Update Note (optional)',
                                  hintText: 'What is new in this update?',
                                ),
                              ),
                              const SizedBox(height: 14),
                              SizedBox(
                                width: double.infinity,
                                child: FilledButton(
                                  onPressed: _saving ? null : _save,
                                  child: _saving
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
              ],
            );
          },
        ),
      ),
    );
  }
}
