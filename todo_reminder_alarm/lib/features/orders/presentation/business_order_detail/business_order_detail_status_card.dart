part of 'business_order_detail_screen.dart';

extension _BusinessOrderDetailStatusCard on _BusinessOrderDetailScreenState {
  Widget _buildQuickStatusCard(
    BuildContext context,
    AsyncValue<List<DeliveryAgent>> agentsAsync,
  ) {
    final isLocked = _isLocked;
    final isAccepted = _isAccepted;
    final canEditAfterAccept = !isLocked && isAccepted;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Quick Status Update',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            agentsAsync.when(
              data: (agents) {
                final activeAgents = agents.where((agent) => agent.isActive).toList();
                final hasSelectedAgent =
                    _selectedDeliveryAgentId == null ||
                    activeAgents.any((agent) => agent.id == _selectedDeliveryAgentId);
                final selectedDeliveryAgentId = hasSelectedAgent
                    ? _selectedDeliveryAgentId
                    : null;
                if (!hasSelectedAgent) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    _updateUi(
                      (state) => state.copyWith(selectedDeliveryAgentId: null),
                    );
                  });
                }
                return Column(
                  children: [
                    DropdownButtonFormField<String?>(
                      isExpanded: true,
                      initialValue: selectedDeliveryAgentId,
                      decoration: const InputDecoration(
                        labelText: 'Assign Delivery Agent',
                      ),
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('Unassigned'),
                        ),
                        ...activeAgents.map(
                          (agent) => DropdownMenuItem<String?>(
                            value: agent.id,
                            child: Text('${agent.name} • ${agent.phone}'),
                          ),
                        ),
                      ],
                      onChanged: canEditAfterAccept
                          ? (value) => _updateUi(
                              (state) =>
                                  state.copyWith(selectedDeliveryAgentId: value),
                            )
                          : null,
                    ),
                    const SizedBox(height: 6),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      value: _collectPaymentOnAssign,
                      title: const Text('Collect payment now (optional)'),
                      onChanged: canEditAfterAccept
                          ? (value) => _updateUi(
                              (state) => state.copyWith(
                                collectPaymentOnAssign: value ?? false,
                              ),
                            )
                          : null,
                    ),
                    const SizedBox(height: 8),
                    if (canEditAfterAccept && selectedDeliveryAgentId == null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Select a delivery agent to enable save.',
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(color: Colors.red[700]),
                          ),
                        ),
                      ),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: _saving
                            ? null
                            : !canEditAfterAccept
                            ? null
                            : selectedDeliveryAgentId == null
                            ? null
                            : () => _assignDeliveryAgent(activeAgents),
                        child: const Text('Save Delivery Agent'),
                      ),
                    ),
                  ],
                );
              },
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: LinearProgressIndicator(),
              ),
              error: (err, _) => Text('Delivery agent load failed: $err'),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<PaymentStatus>(
              isExpanded: true,
              initialValue: _selectedPaymentStatus,
              decoration: const InputDecoration(labelText: 'Payment Status'),
              items: PaymentStatus.values
                  .map(
                    (status) => DropdownMenuItem(
                      value: status,
                      child: Text(_paymentStatusLabel(status)),
                    ),
                  )
                  .toList(),
              onChanged: canEditAfterAccept
                  ? (value) {
                      if (value == null) return;
                      _updateUi(
                        (state) => state.copyWith(selectedPaymentStatus: value),
                      );
                    }
                  : null,
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<PaymentMethod>(
              isExpanded: true,
              initialValue: _selectedPaymentMethod,
              decoration: const InputDecoration(labelText: 'Payment Method'),
              items: PaymentMethod.values
                  .map(
                    (method) => DropdownMenuItem(
                      value: method,
                      child: Text(_paymentMethodLabel(method)),
                    ),
                  )
                  .toList(),
              onChanged: canEditAfterAccept
                  ? (value) {
                      if (value == null) return;
                      _updateUi(
                        (state) => state.copyWith(selectedPaymentMethod: value),
                      );
                    }
                  : null,
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _paymentAmountController,
              enabled: canEditAfterAccept,
              onTap: () => _clearDefaultNumericOnTap(_paymentAmountController),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Order Amount',
                hintText: 'e.g. 1250',
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: (_saving || !canEditAfterAccept)
                    ? null
                    : _saveStatusUpdates,
                child: Text(_saving ? 'Saving...' : 'Update Payment'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
