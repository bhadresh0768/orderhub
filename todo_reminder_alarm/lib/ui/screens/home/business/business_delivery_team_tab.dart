part of 'business_home.dart';

class _DeliveryTeamTab extends ConsumerStatefulWidget {
  const _DeliveryTeamTab({required this.profile});

  final AppUser profile;

  @override
  ConsumerState<_DeliveryTeamTab> createState() => _DeliveryTeamTabState();
}

class _DeliveryTeamTabState extends ConsumerState<_DeliveryTeamTab> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  late final String _uiKey;

  _DeliveryTeamUiState get _ui => ref.read(_deliveryTeamUiProvider(_uiKey));
  void _updateUi(
    _DeliveryTeamUiState Function(_DeliveryTeamUiState state) update,
  ) {
    final notifier = ref.read(_deliveryTeamUiProvider(_uiKey).notifier);
    notifier.state = update(notifier.state);
  }

  @override
  void initState() {
    super.initState();
    _uiKey = widget.profile.businessId!;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _submitAgent() async {
    if (_ui.saving) return;
    final name = _nameController.text.trim();
    final phone = _normalizePhoneNumber(_phoneController.text);
    if (name.isEmpty || phone.isEmpty) {
      _updateUi((state) => state.copyWith(error: 'Enter delivery boy name and phone'));
      return;
    }
    _updateUi((state) => state.copyWith(saving: true, error: null));
    try {
      if (_ui.editingAgentId == null) {
        final agent = DeliveryAgent(
          id: const Uuid().v4(),
          businessId: widget.profile.businessId!,
          name: name,
          phone: phone,
          isActive: true,
        );
        await ref.read(firestoreServiceProvider).createDeliveryAgent(agent);
      } else {
        await ref.read(firestoreServiceProvider).updateDeliveryAgent(
          _ui.editingAgentId!,
          {'name': name, 'phone': phone, 'isActive': true},
        );
      }
      _nameController.clear();
      _phoneController.clear();
      _updateUi((state) => state.copyWith(editingAgentId: null, error: null));
    } catch (err) {
      _updateUi(
        (state) => state.copyWith(error: 'Failed to save delivery boy: $err'),
      );
    } finally {
      if (mounted) {
        _updateUi((state) => state.copyWith(saving: false));
      }
    }
  }

  String _normalizePhoneNumber(String value) {
    final raw = value.trim().replaceAll(RegExp(r'[\s-]'), '');
    if (raw.isEmpty) return '';
    if (raw.startsWith('+')) return raw;
    if (RegExp(r'^\d+$').hasMatch(raw)) {
      return '+${_ui.selectedCountry.phoneCode}$raw';
    }
    return value.trim();
  }

  void _editAgent(DeliveryAgent agent) {
    _nameController.text = agent.name;
    _phoneController.text = agent.phone;
    _updateUi((state) => state.copyWith(editingAgentId: agent.id, error: null));
  }

  Future<void> _setAgentActive(DeliveryAgent agent, bool isActive) async {
    await ref.read(firestoreServiceProvider).updateDeliveryAgent(agent.id, {
      'isActive': isActive,
    });
  }

  @override
  Widget build(BuildContext context) {
    final ui = ref.watch(_deliveryTeamUiProvider(_uiKey));
    final agentsAsync = ref.watch(
      deliveryAgentsForBusinessProvider(widget.profile.businessId!),
    );
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Delivery Team', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Delivery Boy Name',
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    SizedBox(
                      width: 132,
                      child: InkWell(
                        onTap: () {
                          showCountryPicker(
                            context: context,
                            showPhoneCode: true,
                            onSelect: (country) {
                              _updateUi(
                                (state) => state.copyWith(
                                  selectedCountry: country,
                                ),
                              );
                            },
                          );
                        },
                        child: InputDecorator(
                          decoration: const InputDecoration(labelText: 'Code'),
                          child: Text(
                            '${ui.selectedCountry.flagEmoji} +${ui.selectedCountry.phoneCode}',
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextFormField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(
                          labelText: 'Phone Number',
                          hintText: '9876543210',
                        ),
                      ),
                    ),
                  ],
                ),
                if (ui.error != null) ...[
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      ui.error!,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton(
                        onPressed: ui.saving ? null : _submitAgent,
                        child: Text(
                          ui.editingAgentId == null
                              ? 'Add Delivery Boy'
                              : 'Update Delivery Boy',
                        ),
                      ),
                    ),
                    if (ui.editingAgentId != null) ...[
                      const SizedBox(width: 8),
                      OutlinedButton(
                        onPressed: ui.saving
                            ? null
                            : () {
                                _nameController.clear();
                                _phoneController.clear();
                                _updateUi(
                                  (state) => state.copyWith(
                                    editingAgentId: null,
                                    error: null,
                                  ),
                                );
                              },
                        child: const Text('Cancel'),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        agentsAsync.when(
          data: (agents) {
            if (agents.isEmpty) {
              return const Text('No delivery boys yet.');
            }
            return Column(
              children: agents.map((agent) {
                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    title: Text(agent.name),
                    subtitle: Text(
                      '${agent.phone} • ${agent.isActive ? 'Active' : 'Inactive'}',
                    ),
                    trailing: Wrap(
                      spacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        IconButton(
                          onPressed: () => _editAgent(agent),
                          icon: const Icon(Icons.edit_outlined),
                        ),
                        Switch(
                          value: agent.isActive,
                          onChanged: (value) => _setAgentActive(agent, value),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) =>
              const Text('Something went wrong. Please retry.'),
        ),
      ],
    );
  }
}
