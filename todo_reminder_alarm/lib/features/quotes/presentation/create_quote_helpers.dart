part of 'create_quote_screen.dart';

class _QuoteItemDraft {
  static const List<String> predefinedUnits = ['pcs', 'kg', 'lit'];

  _QuoteItemDraft({
    String title = '',
    String description = '',
    String quantity = '1',
    String unit = 'pcs',
    String unitPrice = '',
    String discount = '0',
    this.discountType = _QuoteDiscountType.percentage,
    String taxPercent = '0',
  }) : titleController = TextEditingController(text: title),
       descriptionController = TextEditingController(text: description),
       quantityController = TextEditingController(text: quantity),
       unitController = TextEditingController(text: unit),
       unitPriceController = TextEditingController(text: unitPrice),
       discountController = TextEditingController(text: discount),
       taxPercentController = TextEditingController(text: taxPercent);

  factory _QuoteItemDraft.fromQuoteLineItem(QuoteLineItem item) {
    return _QuoteItemDraft(
      title: item.title,
      description: item.description ?? '',
      quantity: _formatNumber(item.quantity),
      unit: item.unit ?? 'pcs',
      unitPrice: _formatNumber(item.unitPrice),
      discount: _formatNumber(item.discountAmount),
      discountType: _QuoteDiscountType.amount,
      taxPercent: _formatNumber(item.taxPercent),
    );
  }

  final TextEditingController titleController;
  final TextEditingController descriptionController;
  final TextEditingController quantityController;
  final TextEditingController unitController;
  final TextEditingController unitPriceController;
  final TextEditingController discountController;
  final TextEditingController taxPercentController;
  _QuoteDiscountType discountType;
  bool _didClearDiscountDefault = false;
  bool _didClearTaxDefault = false;

  bool get hasCustomUnit {
    final value = unitController.text.trim().toLowerCase();
    return value.isNotEmpty && !predefinedUnits.contains(value);
  }

  void clearDiscountDefaultOnFirstTap() {
    if (_didClearDiscountDefault) return;
    if (discountController.text.trim() == '0') {
      discountController.clear();
    }
    _didClearDiscountDefault = true;
  }

  void clearTaxDefaultOnFirstTap() {
    if (_didClearTaxDefault) return;
    if (taxPercentController.text.trim() == '0') {
      taxPercentController.clear();
    }
    _didClearTaxDefault = true;
  }

  QuoteLineItem toLineItem() {
    final quantity = double.tryParse(quantityController.text.trim()) ?? 0;
    final unitPrice = double.tryParse(unitPriceController.text.trim()) ?? 0;
    final rawDiscount = double.tryParse(discountController.text.trim()) ?? 0;
    final grossAmount = quantity * unitPrice;
    final discountAmount = switch (discountType) {
      _QuoteDiscountType.percentage =>
        ((rawDiscount < 0 ? 0 : rawDiscount) / 100) * grossAmount,
      _QuoteDiscountType.amount => rawDiscount < 0 ? 0 : rawDiscount,
    }.toDouble();
    return QuoteLineItem(
      title: titleController.text.trim(),
      description: descriptionController.text.trim().isEmpty
          ? null
          : descriptionController.text.trim(),
      quantity: quantity,
      unit: unitController.text.trim().isEmpty
          ? null
          : unitController.text.trim(),
      unitPrice: unitPrice,
      discountAmount: discountAmount > grossAmount
          ? grossAmount
          : discountAmount,
      taxPercent: double.tryParse(taxPercentController.text.trim()) ?? 0,
    );
  }

  void dispose() {
    titleController.dispose();
    descriptionController.dispose();
    quantityController.dispose();
    unitController.dispose();
    unitPriceController.dispose();
    discountController.dispose();
    taxPercentController.dispose();
  }

  static String _formatNumber(double value) {
    if (value == value.roundToDouble()) {
      return value.toStringAsFixed(0);
    }
    return value.toStringAsFixed(2);
  }
}

enum _QuoteDiscountType { percentage, amount }

class _QuoteItemCard extends StatelessWidget {
  const _QuoteItemCard({
    required this.index,
    required this.item,
    required this.taxLabel,
    required this.savedItemNames,
    required this.onRemove,
    required this.onChanged,
  });

  final int index;
  final _QuoteItemDraft item;
  final String taxLabel;
  final List<String> savedItemNames;
  final VoidCallback onRemove;
  final VoidCallback onChanged;

  static const String _otherUnitValue = '__other__';

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Item ${index + 1}',
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              IconButton(
                onPressed: onRemove,
                icon: const Icon(Icons.delete_outline),
                tooltip: 'Remove item',
              ),
            ],
          ),
          if (savedItemNames.isEmpty)
            TextFormField(
              controller: item.titleController,
              textCapitalization: TextCapitalization.words,
              inputFormatters: const [_CapitalizeWordsFormatter()],
              decoration: const InputDecoration(labelText: 'Item Name'),
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Enter item name'
                  : null,
              onChanged: (_) => onChanged(),
            )
          else
            Autocomplete<String>(
              initialValue: TextEditingValue(text: item.titleController.text),
              optionsBuilder: (textEditingValue) {
                final query = textEditingValue.text.trim().toLowerCase();
                if (query.isEmpty) return savedItemNames.take(12);
                return savedItemNames
                    .where((name) => name.toLowerCase().contains(query))
                    .take(12);
              },
              onSelected: (selected) {
                item.titleController.text = selected;
                onChanged();
              },
              fieldViewBuilder:
                  (
                    context,
                    textEditingController,
                    focusNode,
                    onFieldSubmitted,
                  ) {
                    if (textEditingController.text !=
                        item.titleController.text) {
                      textEditingController.text = item.titleController.text;
                    }
                    textEditingController.addListener(() {
                      if (item.titleController.text !=
                          textEditingController.text) {
                        item.titleController.text = textEditingController.text;
                        onChanged();
                      }
                    });
                    return TextFormField(
                      controller: textEditingController,
                      focusNode: focusNode,
                      textCapitalization: TextCapitalization.words,
                      inputFormatters: const [_CapitalizeWordsFormatter()],
                      decoration: const InputDecoration(
                        labelText: 'Item Name',
                        hintText: 'Type to search saved items',
                      ),
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                          ? 'Enter item name'
                          : null,
                      onFieldSubmitted: (_) => onFieldSubmitted(),
                    );
                  },
              optionsViewBuilder: (context, onSelected, options) {
                final optionList = options.toList();
                return Align(
                  alignment: Alignment.topLeft,
                  child: Material(
                    elevation: 4,
                    borderRadius: BorderRadius.circular(10),
                    child: SizedBox(
                      width: MediaQuery.of(context).size.width * 0.78,
                      child: ListView.builder(
                        padding: EdgeInsets.zero,
                        shrinkWrap: true,
                        itemCount: optionList.length,
                        itemBuilder: (context, index) {
                          final option = optionList[index];
                          return ListTile(
                            dense: true,
                            title: Text(option),
                            onTap: () => onSelected(option),
                          );
                        },
                      ),
                    ),
                  ),
                );
              },
            ),
          const SizedBox(height: 10),
          TextFormField(
            controller: item.descriptionController,
            maxLines: 2,
            textCapitalization: TextCapitalization.sentences,
            inputFormatters: const [_CapitalizeSentencesFormatter()],
            decoration: const InputDecoration(labelText: 'Description'),
            onChanged: (_) => onChanged(),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: item.quantityController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(labelText: 'Quantity'),
                  validator: (value) {
                    final parsed = double.tryParse((value ?? '').trim());
                    if (parsed == null || parsed <= 0) {
                      return 'Qty?';
                    }
                    return null;
                  },
                  onChanged: (_) => onChanged(),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ValueListenableBuilder<TextEditingValue>(
                  valueListenable: item.unitController,
                  builder: (context, value, _) {
                    final unitText = value.text.trim().toLowerCase();
                    final selectedValue =
                        _QuoteItemDraft.predefinedUnits.contains(unitText)
                        ? unitText
                        : _otherUnitValue;
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        DropdownButtonFormField<String>(
                          initialValue: selectedValue,
                          decoration: const InputDecoration(labelText: 'Unit'),
                          items: const [
                            DropdownMenuItem(value: 'pcs', child: Text('pcs')),
                            DropdownMenuItem(value: 'kg', child: Text('kg')),
                            DropdownMenuItem(value: 'lit', child: Text('lit')),
                            DropdownMenuItem(
                              value: _otherUnitValue,
                              child: Text('Other'),
                            ),
                          ],
                          onChanged: (selected) {
                            if (selected == null) return;
                            if (selected == _otherUnitValue) {
                              if (_QuoteItemDraft.predefinedUnits.contains(
                                unitText,
                              )) {
                                item.unitController.clear();
                              }
                            } else {
                              item.unitController.text = selected;
                            }
                            onChanged();
                          },
                        ),
                        if (selectedValue == _otherUnitValue) ...[
                          const SizedBox(height: 10),
                          TextFormField(
                            controller: item.unitController,
                            textCapitalization: TextCapitalization.words,
                            inputFormatters: const [
                              _CapitalizeWordsFormatter(),
                            ],
                            decoration: const InputDecoration(
                              labelText: 'Custom Unit',
                              hintText: 'Enter unit',
                            ),
                            onChanged: (_) => onChanged(),
                          ),
                        ],
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: item.unitPriceController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(labelText: 'Unit Price'),
                  validator: (value) {
                    final parsed = double.tryParse((value ?? '').trim());
                    if (parsed == null || parsed < 0) {
                      return 'Invalid';
                    }
                    return null;
                  },
                  onChanged: (_) => onChanged(),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  children: [
                    TextFormField(
                      controller: item.discountController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: InputDecoration(
                        labelText: 'Discount',
                        suffixText:
                            item.discountType == _QuoteDiscountType.percentage
                            ? '%'
                            : 'Amt',
                      ),
                      onTap: item.clearDiscountDefaultOnFirstTap,
                      onChanged: (_) => onChanged(),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<_QuoteDiscountType>(
                      initialValue: item.discountType,
                      decoration: const InputDecoration(
                        labelText: 'Discount Type',
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: _QuoteDiscountType.percentage,
                          child: Text('%'),
                        ),
                        DropdownMenuItem(
                          value: _QuoteDiscountType.amount,
                          child: Text('Amount'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value == null) return;
                        item.discountType = value;
                        onChanged();
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: item.taxPercentController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(labelText: '$taxLabel %'),
            onTap: item.clearTaxDefaultOnFirstTap,
            onChanged: (_) => onChanged(),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child, this.trailing});

  final String title;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (trailing != null) ...[trailing!],
              ],
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

class _ReadOnlyField extends StatelessWidget {
  const _ReadOnlyField({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return InputDecorator(
      decoration: InputDecoration(labelText: label),
      child: Text(value),
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final DateTime value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          suffixIcon: const Icon(Icons.calendar_today_outlined),
        ),
        child: Text(DateFormat('dd MMM yyyy').format(value)),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    required this.value,
    this.emphasize = false,
  });

  final String label;
  final String value;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodyMedium?.copyWith(
      fontWeight: emphasize ? FontWeight.w700 : FontWeight.w500,
      fontSize: emphasize ? 16 : null,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(label, style: style)),
          Text(value, style: style),
        ],
      ),
    );
  }
}

class _CapitalizeWordsFormatter extends TextInputFormatter {
  const _CapitalizeWordsFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final transformed = _capitalizeWords(newValue.text);
    return newValue.copyWith(
      text: transformed,
      selection: TextSelection.collapsed(offset: transformed.length),
    );
  }

  String _capitalizeWords(String value) {
    if (value.isEmpty) return value;
    final buffer = StringBuffer();
    var capitalizeNext = true;
    for (final char in value.split('')) {
      final isLetter = RegExp(r'[A-Za-z]').hasMatch(char);
      if (capitalizeNext && isLetter) {
        buffer.write(char.toUpperCase());
        capitalizeNext = false;
      } else {
        buffer.write(char);
        if (char.trim().isEmpty) {
          capitalizeNext = true;
        }
      }
    }
    return buffer.toString();
  }
}

class _CapitalizeSentencesFormatter extends TextInputFormatter {
  const _CapitalizeSentencesFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final transformed = _capitalizeSentences(newValue.text);
    return newValue.copyWith(
      text: transformed,
      selection: TextSelection.collapsed(offset: transformed.length),
    );
  }

  String _capitalizeSentences(String value) {
    if (value.isEmpty) return value;
    final buffer = StringBuffer();
    var capitalizeNext = true;
    for (final char in value.split('')) {
      final isLetter = RegExp(r'[A-Za-z]').hasMatch(char);
      if (capitalizeNext && isLetter) {
        buffer.write(char.toUpperCase());
        capitalizeNext = false;
      } else {
        buffer.write(char);
      }
      if (char == '.' || char == '!' || char == '?' || char == '\n') {
        capitalizeNext = true;
      }
    }
    return buffer.toString();
  }
}
