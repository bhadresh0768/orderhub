part of 'profile_screen.dart';

class _UpgradeBusinessData {
  const _UpgradeBusinessData({
    required this.name,
    required this.category,
    required this.city,
    required this.country,
    required this.fiscalYearStartMonth,
    this.address,
    this.phone,
    this.gstNumber,
    required this.taxLabel,
    this.description,
  });

  final String name;
  final String category;
  final String city;
  final Country country;
  final int fiscalYearStartMonth;
  final String? address;
  final String? phone;
  final String? gstNumber;
  final String taxLabel;
  final String? description;
}

const List<String> _monthLabels = <String>[
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

class _UpgradeToBusinessOwnerDialog extends StatefulWidget {
  const _UpgradeToBusinessOwnerDialog({
    required this.initialShopName,
    required this.initialAddress,
    required this.initialCountry,
  });

  final String initialShopName;
  final String initialAddress;
  final Country initialCountry;

  @override
  State<_UpgradeToBusinessOwnerDialog> createState() =>
      _UpgradeToBusinessOwnerDialogState();
}

class _UpgradeToBusinessOwnerDialogState
    extends State<_UpgradeToBusinessOwnerDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _businessNameController;
  final _categoryController = TextEditingController();
  final _cityController = TextEditingController();
  late final TextEditingController _addressController;
  final _gstController = TextEditingController();
  final _phoneController = TextEditingController();
  final _descriptionController = TextEditingController();
  String _selectedTaxLabel = _ProfileScreenState._taxLabelOptions.first;
  late final ValueNotifier<Country> _selectedCountry;
  late final ValueNotifier<int> _fiscalYearStartMonth;

  @override
  void initState() {
    super.initState();
    _businessNameController = TextEditingController(
      text: widget.initialShopName,
    );
    _addressController = TextEditingController(text: widget.initialAddress);
    _selectedCountry = ValueNotifier<Country>(widget.initialCountry);
    _fiscalYearStartMonth = ValueNotifier<int>(
      defaultFiscalYearStartMonthForCountryCode(
        widget.initialCountry.countryCode,
      ),
    );
  }

  @override
  void dispose() {
    _businessNameController.dispose();
    _categoryController.dispose();
    _cityController.dispose();
    _addressController.dispose();
    _gstController.dispose();
    _phoneController.dispose();
    _descriptionController.dispose();
    _selectedCountry.dispose();
    _fiscalYearStartMonth.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.of(context).viewInsets;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 12, 16, 16 + viewInsets.bottom),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade400,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Switch to Business Owner',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text(
                    'After switching, your account will open Business Owner screens by default. This change applies immediately.',
                  ),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _businessNameController,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(labelText: 'Business Name'),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Enter business name'
                      : null,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _categoryController,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(labelText: 'Category'),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Enter category'
                      : null,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _cityController,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(labelText: 'City'),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Enter city'
                      : null,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _addressController,
                  maxLines: 2,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Business Address',
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
                              _selectedCountry.value = country;
                              _fiscalYearStartMonth.value =
                                  defaultFiscalYearStartMonthForCountryCode(
                                    country.countryCode,
                                  );
                            },
                          );
                        },
                        child: ValueListenableBuilder<Country>(
                          valueListenable: _selectedCountry,
                          builder: (context, selectedCountry, _) => InputDecorator(
                            decoration: const InputDecoration(
                              labelText: 'Code',
                            ),
                            child: Text(
                              '${selectedCountry.flagEmoji} +${selectedCountry.phoneCode}',
                            ),
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
                          labelText: 'Business Contact Number',
                          hintText: '9876543210',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _gstController,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(
                    labelText: 'Tax Registration Number',
                    hintText: 'e.g. 27ABCDE1234F1Z5',
                  ),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: _selectedTaxLabel,
                  decoration: const InputDecoration(labelText: 'Tax Label'),
                  items: _ProfileScreenState._taxLabelOptions
                      .map(
                        (label) => DropdownMenuItem<String>(
                          value: label,
                          child: Text(label),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() {
                      _selectedTaxLabel = value;
                    });
                  },
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _descriptionController,
                  maxLines: 3,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Business Description',
                  ),
                ),
                const SizedBox(height: 14),
                ValueListenableBuilder<int>(
                  valueListenable: _fiscalYearStartMonth,
                  builder: (context, fiscalYearStartMonth, _) {
                    return DropdownButtonFormField<int>(
                      initialValue: fiscalYearStartMonth,
                      decoration: const InputDecoration(
                        labelText: 'Financial Year Start Month',
                        helperText: 'Used for future order number reset',
                      ),
                      items: List.generate(12, (index) {
                        final month = index + 1;
                        return DropdownMenuItem<int>(
                          value: month,
                          child: Text(_monthLabels[index]),
                        );
                      }),
                      onChanged: (value) {
                        if (value != null) {
                          _fiscalYearStartMonth.value = value;
                        }
                      },
                    );
                  },
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton(
                        onPressed: () {
                          if (!_formKey.currentState!.validate()) return;
                          Navigator.of(context).pop(
                            _UpgradeBusinessData(
                              name: _businessNameController.text.trim(),
                              category: _categoryController.text.trim(),
                              city: _cityController.text.trim(),
                              country: _selectedCountry.value,
                              fiscalYearStartMonth: _fiscalYearStartMonth.value,
                              address: _addressController.text.trim().isEmpty
                                  ? null
                                  : _addressController.text.trim(),
                              phone: _phoneController.text.trim().isEmpty
                                  ? null
                                  : _phoneController.text.trim(),
                              gstNumber: _gstController.text.trim().isEmpty
                                  ? null
                                  : _gstController.text.trim().toUpperCase(),
                              taxLabel: _selectedTaxLabel,
                              description:
                                  _descriptionController.text.trim().isEmpty
                                  ? null
                                  : _descriptionController.text.trim(),
                            ),
                          );
                        },
                        child: const Text('Switch Role'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
