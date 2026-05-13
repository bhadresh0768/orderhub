part of 'create_quote_screen.dart';

extension _CreateQuoteFormBody on _CreateQuoteScreenState {
  Widget _buildQuoteFormBody({
    required BusinessProfile business,
    required _CreateQuoteUiState ui,
    required List<QuoteCustomer> savedCustomers,
    required List<String> savedItemNames,
  }) {
    final taxLabel = (business.taxLabel ?? '').trim().isEmpty
        ? 'TAX'
        : business.taxLabel!.trim();
    final lineItems = _lineItems();
    final customerQuery = _customerNameController.text.trim().toLowerCase();
    final filteredCustomers = customerQuery.isEmpty
        ? const <QuoteCustomer>[]
        : savedCustomers
              .where((customer) {
                final haystack = [
                  customer.name,
                  customer.contactName ?? '',
                  customer.phone ?? '',
                  customer.email ?? '',
                ].join(' ').toLowerCase();
                return haystack.contains(customerQuery);
              })
              .take(5)
              .toList();
    final hasExactCustomerMatch = filteredCustomers.any(
      (customer) => customer.name.trim().toLowerCase() == customerQuery,
    );
    final subtotal = lineItems.fold<double>(
      0,
      (sum, item) => sum + item.grossAmount,
    );
    final discount = lineItems.fold<double>(
      0,
      (sum, item) => sum + item.discountAmount,
    );
    final taxable = lineItems.fold<double>(
      0,
      (sum, item) => sum + item.taxableAmount,
    );
    final tax = lineItems.fold<double>(0, (sum, item) => sum + item.taxAmount);
    final extraCharges = _parseAmount(_extraChargesController);
    final grandTotal = taxable + tax + extraCharges;

    return SafeArea(
      top: false,
      child: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _SectionCard(
              title: 'Quote Details',
              child: Column(
                children: [
                  _ReadOnlyField(label: 'Business', value: business.name),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _DateField(
                          label: 'Quote Date',
                          value: ui.quoteDate,
                          onTap: () => _pickDate(
                            initialDate: ui.quoteDate,
                            onSelected: (date) => _updateUi(
                              (state) => state.copyWith(quoteDate: date),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextFormField(
                          controller: _validUntilController,
                          readOnly: true,
                          decoration: InputDecoration(
                            labelText: 'Valid Until',
                            suffixIcon: IconButton(
                              onPressed: () => _pickDate(
                                initialDate: ui.validUntil,
                                onSelected: (date) {
                                  _validUntilController.text = DateFormat(
                                    'dd MMM yyyy',
                                  ).format(date);
                                  _updateUi(
                                    (state) => state.copyWith(validUntil: date),
                                  );
                                },
                              ),
                              icon: const Icon(Icons.calendar_today_outlined),
                            ),
                          ),
                          onTap: () => _pickDate(
                            initialDate: ui.validUntil,
                            onSelected: (date) {
                              _validUntilController.text = DateFormat(
                                'dd MMM yyyy',
                              ).format(date);
                              _updateUi(
                                (state) => state.copyWith(validUntil: date),
                              );
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _preparedByController,
                    textCapitalization: TextCapitalization.words,
                    inputFormatters: _capitalizeWordsFormatters,
                    decoration: const InputDecoration(labelText: 'Prepared By'),
                    onTap: () => _clearDefaultOnFirstTap(_preparedByController),
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _currencySymbolController,
                    decoration: const InputDecoration(
                      labelText: 'Currency Symbol',
                      hintText: 'Rs.',
                    ),
                    onChanged: (_) => _touchUi(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _SectionCard(
              title: 'Business Details',
              child: Column(
                children: [
                  TextFormField(
                    controller: _customerNameController,
                    textCapitalization: TextCapitalization.words,
                    inputFormatters: _capitalizeWordsFormatters,
                    decoration: InputDecoration(
                      labelText: 'Business Name',
                      suffixIcon: savedCustomers.isEmpty
                          ? null
                          : IconButton(
                              onPressed: () => _pickSavedCustomer(business.id),
                              icon: const Icon(Icons.search),
                              tooltip: 'Select saved business',
                            ),
                    ),
                    onTap: () =>
                        _clearDefaultOnFirstTap(_customerNameController),
                    onChanged: (_) {
                      _applySavedCustomerIfExactMatch(savedCustomers);
                      _touchUi();
                    },
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Enter business name'
                        : null,
                  ),
                  if (filteredCustomers.isNotEmpty &&
                      !hasExactCustomerMatch) ...[
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: filteredCustomers
                            .map(
                              (customer) => ListTile(
                                dense: true,
                                title: Text(customer.name),
                                subtitle: Text(
                                  [
                                    if ((customer.contactName ?? '')
                                        .trim()
                                        .isNotEmpty)
                                      customer.contactName!.trim(),
                                    if ((customer.phone ?? '')
                                        .trim()
                                        .isNotEmpty)
                                      customer.phone!.trim(),
                                  ].join(' • '),
                                ),
                                onTap: () => _applyCustomer(customer),
                              ),
                            )
                            .toList(),
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _customerContactController,
                    textCapitalization: TextCapitalization.words,
                    inputFormatters: _capitalizeWordsFormatters,
                    decoration: const InputDecoration(
                      labelText: 'Contact Person',
                    ),
                    onTap: () =>
                        _clearDefaultOnFirstTap(_customerContactController),
                    onChanged: (_) => _touchUi(),
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _customerPhoneController,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Phone Number',
                    ),
                    onChanged: (_) => _touchUi(),
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _customerEmailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(labelText: 'Email'),
                    onChanged: (_) => _touchUi(),
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _customerAddressController,
                    maxLines: 3,
                    textCapitalization: TextCapitalization.sentences,
                    inputFormatters: _capitalizeSentencesFormatters,
                    decoration: const InputDecoration(labelText: 'Address'),
                    onTap: () =>
                        _clearDefaultOnFirstTap(_customerAddressController),
                    onChanged: (_) => _touchUi(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _SectionCard(
              title: 'Items',
              trailing: OutlinedButton.icon(
                onPressed: _addItem,
                icon: const Icon(Icons.add),
                label: const Text('Add Item'),
              ),
              child: Column(
                children: List.generate(ui.items.length, (index) {
                  final item = ui.items[index];
                  return Padding(
                    padding: EdgeInsets.only(
                      bottom: index == ui.items.length - 1 ? 0 : 12,
                    ),
                    child: _QuoteItemCard(
                      index: index,
                      item: item,
                      taxLabel: taxLabel,
                      savedItemNames: savedItemNames,
                      onRemove: () => _removeItem(index),
                      onChanged: _touchUi,
                    ),
                  );
                }),
              ),
            ),
            const SizedBox(height: 16),
            _SectionCard(
              title: 'Terms and Notes',
              child: Column(
                children: [
                  TextFormField(
                    controller: _paymentTermsController,
                    maxLines: 2,
                    textCapitalization: TextCapitalization.sentences,
                    inputFormatters: _capitalizeSentencesFormatters,
                    decoration: const InputDecoration(
                      labelText: 'Payment Terms',
                    ),
                    onTap: () =>
                        _clearDefaultOnFirstTap(_paymentTermsController),
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _deliveryTimelineController,
                    maxLines: 2,
                    textCapitalization: TextCapitalization.sentences,
                    inputFormatters: _capitalizeSentencesFormatters,
                    decoration: const InputDecoration(
                      labelText: 'Delivery Timeline',
                    ),
                    onTap: () =>
                        _clearDefaultOnFirstTap(_deliveryTimelineController),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: TextFormField(
                          controller: _extraChargesLabelController,
                          textCapitalization: TextCapitalization.words,
                          inputFormatters: _capitalizeWordsFormatters,
                          decoration: const InputDecoration(
                            labelText: 'Extra Charge Label',
                          ),
                          onTap: () => _clearDefaultOnFirstTap(
                            _extraChargesLabelController,
                          ),
                          onChanged: (_) => _touchUi(),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextFormField(
                          controller: _extraChargesController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'Amount',
                          ),
                          onTap: () =>
                              _clearDefaultOnFirstTap(_extraChargesController),
                          onChanged: (_) => _touchUi(),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _notesController,
                    maxLines: 3,
                    textCapitalization: TextCapitalization.sentences,
                    inputFormatters: _capitalizeSentencesFormatters,
                    decoration: const InputDecoration(labelText: 'Notes'),
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _additionalTermsController,
                    maxLines: 4,
                    textCapitalization: TextCapitalization.sentences,
                    inputFormatters: _capitalizeSentencesFormatters,
                    decoration: const InputDecoration(
                      labelText: 'Additional Terms',
                      helperText: 'Write one condition per line if needed',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _SectionCard(
              title: 'Summary',
              child: Column(
                children: [
                  _SummaryRow(label: 'Subtotal', value: _money(subtotal)),
                  _SummaryRow(label: 'Discount', value: _money(discount)),
                  _SummaryRow(label: 'Taxable Amount', value: _money(taxable)),
                  _SummaryRow(label: '$taxLabel Amount', value: _money(tax)),
                  _SummaryRow(
                    label: _extraChargesLabelController.text.trim().isEmpty
                        ? 'Extra Charges'
                        : _extraChargesLabelController.text.trim(),
                    value: _money(extraCharges),
                  ),
                  const Divider(),
                  _SummaryRow(
                    label: 'Grand Total',
                    value: _money(grandTotal),
                    emphasize: true,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: ui.savingQuote || ui.savingPdf
                        ? null
                        : () => _saveQuote(business),
                    icon: ui.savingQuote
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save_outlined),
                    label: Text(
                      ui.savingQuote
                          ? 'Saving...'
                          : (_isEditing ? 'Update Quote' : 'Save Quote'),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: ui.savingPdf || ui.savingQuote
                        ? null
                        : () => _generatePdf(business),
                    icon: ui.savingPdf
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.picture_as_pdf_outlined),
                    label: Text(
                      ui.savingPdf ? 'Generating...' : 'Generate PDF',
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
