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

part 'create_quote_form_body.dart';
part 'create_quote_helpers.dart';

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
                final savedCustomers =
                    savedCustomersAsync?.asData?.value ??
                    const <QuoteCustomer>[];
                return _buildQuoteFormBody(
                  business: business,
                  ui: ui,
                  savedCustomers: savedCustomers,
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
