import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart' show StateProvider;
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';

import '../../../models/app_user.dart';
import '../../../models/business.dart';
import '../../../models/quote.dart';
import '../../../models/quote_customer.dart';
import '../../../providers.dart';
import '../../../utils/quote_pdf_generator.dart';

final _createQuoteUiProvider = StateProvider.autoDispose
    .family<_CreateQuoteUiState, String>((ref, _) {
      final now = DateTime.now();
      return _CreateQuoteUiState(
        quoteDate: now,
        validUntil: now.add(const Duration(days: 7)),
      );
    });

class _CreateQuoteUiState {
  const _CreateQuoteUiState({
    required this.quoteDate,
    required this.validUntil,
    this.items = const [],
    this.savingPdf = false,
    this.savingQuote = false,
    this.refreshTick = 0,
  });

  final DateTime quoteDate;
  final DateTime validUntil;
  final List<_QuoteItemDraft> items;
  final bool savingPdf;
  final bool savingQuote;
  final int refreshTick;

  _CreateQuoteUiState copyWith({
    DateTime? quoteDate,
    DateTime? validUntil,
    List<_QuoteItemDraft>? items,
    bool? savingPdf,
    bool? savingQuote,
    int? refreshTick,
  }) {
    return _CreateQuoteUiState(
      quoteDate: quoteDate ?? this.quoteDate,
      validUntil: validUntil ?? this.validUntil,
      items: items ?? this.items,
      savingPdf: savingPdf ?? this.savingPdf,
      savingQuote: savingQuote ?? this.savingQuote,
      refreshTick: refreshTick ?? this.refreshTick,
    );
  }
}

class CreateQuoteScreen extends ConsumerStatefulWidget {
  const CreateQuoteScreen({
    super.key,
    required this.profile,
    this.initialQuote,
  });

  final AppUser profile;
  final Quote? initialQuote;

  @override
  ConsumerState<CreateQuoteScreen> createState() => _CreateQuoteScreenState();
}

class _CreateQuoteScreenState extends ConsumerState<CreateQuoteScreen> {
  final _formKey = GlobalKey<FormState>();
  final _customerNameController = TextEditingController();
  final _customerContactController = TextEditingController();
  final _customerPhoneController = TextEditingController();
  final _customerEmailController = TextEditingController();
  final _customerAddressController = TextEditingController();
  final _preparedByController = TextEditingController();
  final _paymentTermsController = TextEditingController(
    text: '50% advance, balance on delivery',
  );
  final _deliveryTimelineController = TextEditingController(
    text: 'Delivery within 3 to 5 working days from confirmation',
  );
  final _extraChargesController = TextEditingController(text: '0');
  final _extraChargesLabelController = TextEditingController(
    text: 'Extra Charges',
  );
  final _notesController = TextEditingController();
  final _additionalTermsController = TextEditingController();
  final _currencySymbolController = TextEditingController(text: 'Rs.');

  static const _uuid = Uuid();

  late final String _quoteDraftId;
  late final Set<TextEditingController> _clearOnFirstTapControllers;
  List<_QuoteItemDraft> _draftItemsForDispose = const [];
  bool _didSeedPreparedBy = false;

  bool get _isEditing => widget.initialQuote != null;
  _CreateQuoteUiState get _ui =>
      ref.read(_createQuoteUiProvider(_quoteDraftId));

  void _updateUi(
    _CreateQuoteUiState Function(_CreateQuoteUiState state) update,
  ) {
    final notifier = ref.read(_createQuoteUiProvider(_quoteDraftId).notifier);
    final nextState = update(notifier.state);
    _draftItemsForDispose = nextState.items;
    notifier.state = nextState;
  }

  void _touchUi() {
    _updateUi((state) => state.copyWith(refreshTick: state.refreshTick + 1));
  }

  @override
  void initState() {
    super.initState();
    final quote = widget.initialQuote;
    _quoteDraftId = quote?.id ?? _uuid.v4();
    final quoteDate = quote?.quoteDate ?? DateTime.now();
    final validUntil =
        quote?.validUntil ?? quoteDate.add(const Duration(days: 7));
    _preparedByController.text = quote?.preparedBy ?? widget.profile.name;
    _customerNameController.text = quote?.customerName ?? '';
    _customerContactController.text = quote?.customerContact ?? '';
    _customerPhoneController.text = quote?.customerPhone ?? '';
    _customerEmailController.text = quote?.customerEmail ?? '';
    _customerAddressController.text = quote?.customerAddress ?? '';
    _paymentTermsController.text =
        quote?.paymentTerms ?? '50% advance, balance on delivery';
    _deliveryTimelineController.text =
        quote?.deliveryTimeline ??
        'Delivery within 3 to 5 working days from confirmation';
    _extraChargesController.text = (quote?.extraCharges ?? 0).toString();
    _extraChargesLabelController.text =
        quote?.extraChargesLabel ?? 'Extra Charges';
    _notesController.text = quote?.notes ?? '';
    _additionalTermsController.text = (quote?.additionalTerms ?? []).join('\n');
    _currencySymbolController.text = quote?.currencySymbol ?? 'Rs.';
    final initialItems = quote == null || quote.items.isEmpty
        ? [_QuoteItemDraft()]
        : quote.items.map(_QuoteItemDraft.fromQuoteLineItem).toList();
    _draftItemsForDispose = initialItems;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _updateUi(
        (state) => state.copyWith(
          quoteDate: quoteDate,
          validUntil: validUntil,
          items: initialItems,
        ),
      );
    });
    _clearOnFirstTapControllers = {
      if (quote == null) ...{
        _preparedByController,
        _paymentTermsController,
        _deliveryTimelineController,
        _extraChargesController,
        _extraChargesLabelController,
      },
    };
  }

  @override
  void dispose() {
    _customerNameController.dispose();
    _customerContactController.dispose();
    _customerPhoneController.dispose();
    _customerEmailController.dispose();
    _customerAddressController.dispose();
    _preparedByController.dispose();
    _paymentTermsController.dispose();
    _deliveryTimelineController.dispose();
    _extraChargesController.dispose();
    _extraChargesLabelController.dispose();
    _notesController.dispose();
    _additionalTermsController.dispose();
    _currencySymbolController.dispose();
    for (final item in _draftItemsForDispose) {
      item.dispose();
    }
    super.dispose();
  }

  void _seedBusinessDefaults(BusinessProfile business) {
    if (_didSeedPreparedBy || _isEditing) return;
    if (_preparedByController.text.trim().isEmpty) {
      _preparedByController.text = widget.profile.name.isNotEmpty
          ? widget.profile.name
          : business.name;
    }
    _didSeedPreparedBy = true;
  }

  Future<void> _pickDate({
    required DateTime initialDate,
    required ValueChanged<DateTime> onSelected,
  }) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year + 10),
    );
    if (picked != null && mounted) {
      onSelected(picked);
    }
  }

  void _addItem() {
    _updateUi(
      (state) => state.copyWith(items: [...state.items, _QuoteItemDraft()]),
    );
  }

  void _removeItem(int index) {
    if (_ui.items.length == 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('At least one item is required')),
      );
      return;
    }
    final item = _ui.items[index];
    final nextItems = [..._ui.items]..removeAt(index);
    _updateUi((state) => state.copyWith(items: nextItems));
    item.dispose();
  }

  double _parseAmount(TextEditingController controller) {
    return double.tryParse(controller.text.trim()) ?? 0;
  }

  List<QuoteLineItem> _lineItems() {
    return _ui.items.map((draft) => draft.toLineItem()).toList();
  }

  void _clearDefaultOnFirstTap(TextEditingController controller) {
    if (!_clearOnFirstTapControllers.remove(controller)) return;
    controller.clear();
    _touchUi();
  }

  List<TextInputFormatter> get _capitalizeWordsFormatters => const [
    _CapitalizeWordsFormatter(),
  ];

  List<TextInputFormatter> get _capitalizeSentencesFormatters => const [
    _CapitalizeSentencesFormatter(),
  ];

  String _buildQuoteNumber() {
    if (_isEditing) {
      return widget.initialQuote!.quoteNumber;
    }
    final now = DateTime.now();
    return 'Q-${DateFormat('yyyyMMdd-HHmm').format(now)}';
  }

  Quote _buildQuote(BusinessProfile business) {
    final lineItems = _lineItems();
    final subtotal = lineItems.fold<double>(
      0,
      (sum, item) => sum + item.grossAmount,
    );
    final discountTotal = lineItems.fold<double>(
      0,
      (sum, item) => sum + item.discountAmount,
    );
    final taxableAmount = lineItems.fold<double>(
      0,
      (sum, item) => sum + item.taxableAmount,
    );
    final taxAmount = lineItems.fold<double>(
      0,
      (sum, item) => sum + item.taxAmount,
    );
    final extraCharges = _parseAmount(_extraChargesController);
    final grandTotal = taxableAmount + taxAmount + extraCharges;
    final existing = widget.initialQuote;

    return Quote(
      id: existing?.id ?? _uuid.v4(),
      businessId: business.id,
      businessName: business.name,
      quoteNumber: _buildQuoteNumber(),
      customerName: _customerNameController.text.trim(),
      customerContact: _customerContactController.text.trim().isEmpty
          ? null
          : _customerContactController.text.trim(),
      customerPhone: _customerPhoneController.text.trim().isEmpty
          ? null
          : _customerPhoneController.text.trim(),
      customerEmail: _customerEmailController.text.trim().isEmpty
          ? null
          : _customerEmailController.text.trim(),
      customerAddress: _customerAddressController.text.trim().isEmpty
          ? null
          : _customerAddressController.text.trim(),
      quoteDate: _ui.quoteDate,
      validUntil: _ui.validUntil,
      preparedBy: _preparedByController.text.trim().isEmpty
          ? widget.profile.name
          : _preparedByController.text.trim(),
      currencySymbol: _currencySymbolController.text.trim().isEmpty
          ? 'Rs.'
          : _currencySymbolController.text.trim(),
      paymentTerms: _paymentTermsController.text.trim().isEmpty
          ? null
          : _paymentTermsController.text.trim(),
      deliveryTimeline: _deliveryTimelineController.text.trim().isEmpty
          ? null
          : _deliveryTimelineController.text.trim(),
      extraCharges: extraCharges,
      extraChargesLabel: _extraChargesLabelController.text.trim().isEmpty
          ? 'Extra Charges'
          : _extraChargesLabelController.text.trim(),
      notes: _notesController.text.trim().isEmpty
          ? null
          : _notesController.text.trim(),
      additionalTerms: _additionalTermsController.text
          .split('\n')
          .map((term) => term.trim())
          .where((term) => term.isNotEmpty)
          .toList(),
      items: lineItems,
      subtotal: subtotal,
      discountTotal: discountTotal,
      taxableAmount: taxableAmount,
      taxAmount: taxAmount,
      grandTotal: grandTotal,
      createdByUserId: existing?.createdByUserId ?? widget.profile.id,
      createdByName: existing?.createdByName ?? widget.profile.name,
      createdAt: existing?.createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  QuoteCustomer _buildQuoteCustomer(BusinessProfile business) {
    final keySeed = [
      business.id.trim().toLowerCase(),
      _customerNameController.text.trim().toLowerCase(),
      _customerPhoneController.text.trim().toLowerCase(),
      _customerEmailController.text.trim().toLowerCase(),
    ].join('|');
    return QuoteCustomer(
      id: keySeed.hashCode.toUnsigned(32).toString(),
      businessId: business.id,
      name: _customerNameController.text.trim(),
      contactName: _customerContactController.text.trim().isEmpty
          ? null
          : _customerContactController.text.trim(),
      phone: _customerPhoneController.text.trim().isEmpty
          ? null
          : _customerPhoneController.text.trim(),
      email: _customerEmailController.text.trim().isEmpty
          ? null
          : _customerEmailController.text.trim(),
      address: _customerAddressController.text.trim().isEmpty
          ? null
          : _customerAddressController.text.trim(),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  void _applyCustomer(QuoteCustomer customer) {
    _customerNameController.text = customer.name;
    _customerContactController.text = customer.contactName ?? '';
    _customerPhoneController.text = customer.phone ?? '';
    _customerEmailController.text = customer.email ?? '';
    _customerAddressController.text = customer.address ?? '';
    _touchUi();
  }

  void _applySavedCustomerIfExactMatch(List<QuoteCustomer> customers) {
    final query = _customerNameController.text.trim().toLowerCase();
    if (query.isEmpty) return;
    QuoteCustomer? match;
    for (final customer in customers) {
      if (customer.name.trim().toLowerCase() == query) {
        match = customer;
        break;
      }
    }
    if (match == null) return;
    final alreadyApplied =
        _customerContactController.text.trim() == (match.contactName ?? '') &&
        _customerPhoneController.text.trim() == (match.phone ?? '') &&
        _customerEmailController.text.trim() == (match.email ?? '') &&
        _customerAddressController.text.trim() == (match.address ?? '');
    if (alreadyApplied) return;
    _applyCustomer(match);
  }

  Future<void> _pickSavedCustomer(String businessId) async {
    final customers = await ref.read(
      quoteCustomersForBusinessProvider(businessId).future,
    );
    if (!mounted) return;
    if (customers.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('No saved businesses yet')));
      return;
    }
    final selected = await showModalBottomSheet<QuoteCustomer>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) {
        final searchController = TextEditingController();
        var filteredCustomers = customers;
        return StatefulBuilder(
          builder: (context, setLocalState) {
            return SafeArea(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  16,
                  8,
                  16,
                  16 + MediaQuery.of(context).viewInsets.bottom,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: searchController,
                      decoration: const InputDecoration(
                        labelText: 'Search Saved Businesses',
                        prefixIcon: Icon(Icons.search),
                      ),
                      onChanged: (value) {
                        final query = value.trim().toLowerCase();
                        setLocalState(() {
                          filteredCustomers = customers.where((customer) {
                            final haystack = [
                              customer.name,
                              customer.contactName ?? '',
                              customer.phone ?? '',
                              customer.email ?? '',
                            ].join(' ').toLowerCase();
                            return haystack.contains(query);
                          }).toList();
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    Flexible(
                      child: filteredCustomers.isEmpty
                          ? const Center(
                              child: Padding(
                                padding: EdgeInsets.all(24),
                                child: Text('No matching business found'),
                              ),
                            )
                          : ListView.separated(
                              shrinkWrap: true,
                              itemCount: filteredCustomers.length,
                              separatorBuilder: (_, _) =>
                                  const Divider(height: 1),
                              itemBuilder: (context, index) {
                                final customer = filteredCustomers[index];
                                final subtitleParts = <String>[
                                  if ((customer.contactName ?? '')
                                      .trim()
                                      .isNotEmpty)
                                    customer.contactName!.trim(),
                                  if ((customer.phone ?? '').trim().isNotEmpty)
                                    customer.phone!.trim(),
                                ];
                                return ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: Text(customer.name),
                                  subtitle: subtitleParts.isEmpty
                                      ? null
                                      : Text(subtitleParts.join(' • ')),
                                  onTap: () =>
                                      Navigator.of(context).pop(customer),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
    if (selected != null && mounted) {
      _applyCustomer(selected);
    }
  }

  String _quoteShareMessage(Quote quote) {
    return 'Quotation ${quote.quoteNumber}\n'
        'Business: ${quote.customerName}\n'
        'Valid Until: ${DateFormat('dd MMM yyyy').format(quote.validUntil)}\n'
        'Total: ${quote.currencySymbol} ${NumberFormat('#,##0.00').format(quote.grandTotal)}';
  }

  Future<void> _shareGeneratedPdf(File file, Quote quote) async {
    await SharePlus.instance.share(
      ShareParams(
        text: _quoteShareMessage(quote),
        files: [XFile(file.path)],
        subject: 'Quotation ${quote.quoteNumber}',
      ),
    );
  }

  Future<void> _shareQuoteOnWhatsApp(File file, Quote quote) async {
    final message = _quoteShareMessage(quote);
    await Clipboard.setData(ClipboardData(text: file.path));
    final uri = Uri.parse(
      'https://wa.me/?text=${Uri.encodeComponent('$message\n\nPDF file path copied for quick attach.')}',
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'WhatsApp opened and PDF file path copied. Attach the PDF from your device.',
          ),
        ),
      );
      return;
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('WhatsApp is not available on this device')),
    );
  }

  QuotePdfDocumentData _buildPdfDocument(
    Quote quote,
    BusinessProfile business,
  ) {
    return QuotePdfDocumentData(
      quoteNumber: quote.quoteNumber,
      quoteDate: quote.quoteDate,
      validUntil: quote.validUntil,
      currencySymbol: quote.currencySymbol,
      preparedBy: quote.preparedBy,
      business: QuotePdfParty(
        name: business.name,
        address: business.address,
        phone: business.phone ?? business.ownerPhone,
        taxRegistrationNumber: business.gstNumber,
      ),
      customer: QuotePdfParty(
        name: quote.customerName,
        contactName: quote.customerContact,
        address: quote.customerAddress,
        phone: quote.customerPhone,
        email: quote.customerEmail,
      ),
      items: quote.items
          .map(
            (item) => QuotePdfLineItem(
              title: item.title,
              description: item.description,
              quantity: item.quantity,
              unit: item.unit,
              unitPrice: item.unitPrice,
              discountAmount: item.discountAmount,
              taxPercent: item.taxPercent,
            ),
          )
          .toList(),
      extraCharges: quote.extraCharges,
      extraChargesLabel: quote.extraChargesLabel,
      notes: quote.notes,
      paymentTerms: quote.paymentTerms,
      deliveryTimeline: quote.deliveryTimeline,
      additionalTerms: quote.additionalTerms,
    );
  }

  Future<Quote?> _saveQuote(
    BusinessProfile business, {
    bool showSnackBar = true,
  }) async {
    if (!_formKey.currentState!.validate()) return null;
    final lineItems = _lineItems();
    if (lineItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add at least one quotation item')),
      );
      return null;
    }

    _updateUi((state) => state.copyWith(savingQuote: true));
    try {
      final quote = _buildQuote(business);
      await ref.read(firestoreServiceProvider).createQuote(quote);
      await ref
          .read(firestoreServiceProvider)
          .upsertQuoteCustomer(_buildQuoteCustomer(business));
      if (!mounted) return quote;
      if (showSnackBar) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isEditing ? 'Quotation updated' : 'Quotation saved'),
          ),
        );
      }
      return quote;
    } catch (err) {
      if (!mounted) return null;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to save quotation: $err')));
      return null;
    } finally {
      if (mounted) {
        _updateUi((state) => state.copyWith(savingQuote: false));
      }
    }
  }

  Future<void> _generatePdf(BusinessProfile business) async {
    final quote = await _saveQuote(business, showSnackBar: false);
    if (quote == null) return;

    _updateUi((state) => state.copyWith(savingPdf: true));

    try {
      final pdfBytes = await QuotePdfGenerator.buildQuotePdf(
        _buildPdfDocument(quote, business),
      );
      final fileName =
          'quote_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.pdf';
      final file = File('${Directory.systemTemp.path}/$fileName');
      await file.writeAsBytes(pdfBytes, flush: true);

      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Quotation PDF Generated'),
          content: Text(
            'Quotation ${quote.quoteNumber} has been saved and the PDF has been generated successfully.\n\nSaved file: $fileName',
          ),
          actions: [
            TextButton(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: file.path));
                if (!context.mounted) return;
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('PDF file path copied')),
                );
              },
              child: const Text('Copy File Path'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await _shareQuoteOnWhatsApp(file, quote);
              },
              child: const Text('WhatsApp'),
            ),
            FilledButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await _shareGeneratedPdf(file, quote);
              },
              child: const Text('Share PDF'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    } catch (err) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to generate quotation PDF: $err')),
      );
    } finally {
      if (mounted) {
        _updateUi((state) => state.copyWith(savingPdf: false));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ui = ref.watch(_createQuoteUiProvider(_quoteDraftId));
    final businessId = widget.profile.businessId;
    final businessAsync = businessId == null
        ? null
        : ref.watch(businessByIdProvider(businessId));
    final savedCustomersAsync = businessId == null
        ? null
        : ref.watch(quoteCustomersForBusinessProvider(businessId));

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Quotation' : 'Create Quotation'),
      ),
      body: businessId == null
          ? const Center(child: Text('No business linked'))
          : businessAsync!.when(
              data: (business) {
                if (business == null) {
                  return const Center(child: Text('Business not found'));
                }
                _seedBusinessDefaults(business);
                final lineItems = _lineItems();
                final savedCustomers =
                    savedCustomersAsync?.asData?.value ??
                    const <QuoteCustomer>[];
                final customerQuery = _customerNameController.text
                    .trim()
                    .toLowerCase();
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
                  (customer) =>
                      customer.name.trim().toLowerCase() == customerQuery,
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
                final tax = lineItems.fold<double>(
                  0,
                  (sum, item) => sum + item.taxAmount,
                );
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
                              _ReadOnlyField(
                                label: 'Business',
                                value: business.name,
                              ),
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
                                          (state) =>
                                              state.copyWith(quoteDate: date),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: _DateField(
                                      label: 'Valid Until',
                                      value: ui.validUntil,
                                      onTap: () => _pickDate(
                                        initialDate: ui.validUntil,
                                        onSelected: (date) => _updateUi(
                                          (state) =>
                                              state.copyWith(validUntil: date),
                                        ),
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
                                decoration: const InputDecoration(
                                  labelText: 'Prepared By',
                                ),
                                onTap: () => _clearDefaultOnFirstTap(
                                  _preparedByController,
                                ),
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
                                          onPressed: () =>
                                              _pickSavedCustomer(business.id),
                                          icon: const Icon(Icons.search),
                                          tooltip: 'Select saved business',
                                        ),
                                ),
                                onTap: () => _clearDefaultOnFirstTap(
                                  _customerNameController,
                                ),
                                onChanged: (_) {
                                  _applySavedCustomerIfExactMatch(
                                    savedCustomers,
                                  );
                                  _touchUi();
                                },
                                validator: (value) =>
                                    value == null || value.trim().isEmpty
                                    ? 'Enter business name'
                                    : null,
                              ),
                              if (filteredCustomers.isNotEmpty &&
                                  !hasExactCustomerMatch) ...[
                                const SizedBox(height: 8),
                                Container(
                                  width: double.infinity,
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      color: Colors.grey.shade300,
                                    ),
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
                                            onTap: () =>
                                                _applyCustomer(customer),
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
                                onTap: () => _clearDefaultOnFirstTap(
                                  _customerContactController,
                                ),
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
                                decoration: const InputDecoration(
                                  labelText: 'Email',
                                ),
                                onChanged: (_) => _touchUi(),
                              ),
                              const SizedBox(height: 10),
                              TextFormField(
                                controller: _customerAddressController,
                                maxLines: 3,
                                textCapitalization:
                                    TextCapitalization.sentences,
                                inputFormatters: _capitalizeSentencesFormatters,
                                decoration: const InputDecoration(
                                  labelText: 'Address',
                                ),
                                onTap: () => _clearDefaultOnFirstTap(
                                  _customerAddressController,
                                ),
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
                                textCapitalization:
                                    TextCapitalization.sentences,
                                inputFormatters: _capitalizeSentencesFormatters,
                                decoration: const InputDecoration(
                                  labelText: 'Payment Terms',
                                ),
                                onTap: () => _clearDefaultOnFirstTap(
                                  _paymentTermsController,
                                ),
                              ),
                              const SizedBox(height: 10),
                              TextFormField(
                                controller: _deliveryTimelineController,
                                maxLines: 2,
                                textCapitalization:
                                    TextCapitalization.sentences,
                                inputFormatters: _capitalizeSentencesFormatters,
                                decoration: const InputDecoration(
                                  labelText: 'Delivery Timeline',
                                ),
                                onTap: () => _clearDefaultOnFirstTap(
                                  _deliveryTimelineController,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Expanded(
                                    flex: 2,
                                    child: TextFormField(
                                      controller: _extraChargesLabelController,
                                      textCapitalization:
                                          TextCapitalization.words,
                                      inputFormatters:
                                          _capitalizeWordsFormatters,
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
                                      keyboardType:
                                          const TextInputType.numberWithOptions(
                                            decimal: true,
                                          ),
                                      decoration: const InputDecoration(
                                        labelText: 'Amount',
                                      ),
                                      onTap: () => _clearDefaultOnFirstTap(
                                        _extraChargesController,
                                      ),
                                      onChanged: (_) => _touchUi(),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              TextFormField(
                                controller: _notesController,
                                maxLines: 3,
                                textCapitalization:
                                    TextCapitalization.sentences,
                                inputFormatters: _capitalizeSentencesFormatters,
                                decoration: const InputDecoration(
                                  labelText: 'Notes',
                                ),
                              ),
                              const SizedBox(height: 10),
                              TextFormField(
                                controller: _additionalTermsController,
                                maxLines: 4,
                                textCapitalization:
                                    TextCapitalization.sentences,
                                inputFormatters: _capitalizeSentencesFormatters,
                                decoration: const InputDecoration(
                                  labelText: 'Additional Terms',
                                  helperText:
                                      'Write one condition per line if needed',
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
                              _SummaryRow(
                                label: 'Subtotal',
                                value: _money(subtotal),
                              ),
                              _SummaryRow(
                                label: 'Discount',
                                value: _money(discount),
                              ),
                              _SummaryRow(
                                label: 'Taxable Amount',
                                value: _money(taxable),
                              ),
                              _SummaryRow(label: 'Tax', value: _money(tax)),
                              _SummaryRow(
                                label:
                                    _extraChargesLabelController.text
                                        .trim()
                                        .isEmpty
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
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(Icons.save_outlined),
                                label: Text(
                                  ui.savingQuote
                                      ? 'Saving...'
                                      : (_isEditing
                                            ? 'Update Quote'
                                            : 'Save Quote'),
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
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(Icons.picture_as_pdf_outlined),
                                label: Text(
                                  ui.savingPdf
                                      ? 'Generating...'
                                      : 'Generate PDF',
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) =>
                  Center(child: Text('Failed to load business: $err')),
            ),
    );
  }

  String _money(double value) {
    final symbol = _currencySymbolController.text.trim().isEmpty
        ? 'Rs.'
        : _currencySymbolController.text.trim();
    return '$symbol ${NumberFormat('#,##0.00').format(value)}';
  }
}

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
    required this.onRemove,
    required this.onChanged,
  });

  final int index;
  final _QuoteItemDraft item;
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
          TextFormField(
            controller: item.titleController,
            textCapitalization: TextCapitalization.words,
            inputFormatters: const [_CapitalizeWordsFormatter()],
            decoration: const InputDecoration(labelText: 'Item Name'),
            validator: (value) => value == null || value.trim().isEmpty
                ? 'Enter item name'
                : null,
            onChanged: (_) => onChanged(),
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
            decoration: const InputDecoration(labelText: 'Tax %'),
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
