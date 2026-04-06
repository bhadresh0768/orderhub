import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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

  late DateTime _quoteDate;
  late DateTime _validUntil;
  late List<_QuoteItemDraft> _items;
  late final Set<TextEditingController> _clearOnFirstTapControllers;
  bool _savingPdf = false;
  bool _savingQuote = false;
  bool _didSeedPreparedBy = false;

  bool get _isEditing => widget.initialQuote != null;

  @override
  void initState() {
    super.initState();
    final quote = widget.initialQuote;
    _quoteDate = quote?.quoteDate ?? DateTime.now();
    _validUntil = quote?.validUntil ?? _quoteDate.add(const Duration(days: 7));
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
    _items = quote == null || quote.items.isEmpty
        ? [_QuoteItemDraft()]
        : quote.items.map(_QuoteItemDraft.fromQuoteLineItem).toList();
    _clearOnFirstTapControllers = {
      if (quote == null) ...{
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
    for (final item in _items) {
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
      setState(() {
        onSelected(picked);
      });
    }
  }

  void _addItem() {
    setState(() {
      _items = [..._items, _QuoteItemDraft()];
    });
  }

  void _removeItem(int index) {
    if (_items.length == 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('At least one item is required')),
      );
      return;
    }
    final item = _items[index];
    setState(() {
      _items = [..._items]..removeAt(index);
    });
    item.dispose();
  }

  double _parseAmount(TextEditingController controller) {
    return double.tryParse(controller.text.trim()) ?? 0;
  }

  List<QuoteLineItem> _lineItems() {
    return _items.map((draft) => draft.toLineItem()).toList();
  }

  void _clearDefaultOnFirstTap(TextEditingController controller) {
    if (!_clearOnFirstTapControllers.remove(controller)) return;
    controller.clear();
  }

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
      quoteDate: _quoteDate,
      validUntil: _validUntil,
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
    setState(() {
      _customerNameController.text = customer.name;
      _customerContactController.text = customer.contactName ?? '';
      _customerPhoneController.text = customer.phone ?? '';
      _customerEmailController.text = customer.email ?? '';
      _customerAddressController.text = customer.address ?? '';
    });
  }

  Future<void> _pickSavedCustomer(String businessId) async {
    final customers = await ref.read(
      quoteCustomersForBusinessProvider(businessId).future,
    );
    if (!mounted) return;
    if (customers.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('No saved customers yet')));
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
                        labelText: 'Search Saved Customers',
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
                                child: Text('No matching customer found'),
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
        'Customer: ${quote.customerName}\n'
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

    setState(() {
      _savingQuote = true;
    });
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
        setState(() {
          _savingQuote = false;
        });
      }
    }
  }

  Future<void> _generatePdf(BusinessProfile business) async {
    final quote = await _saveQuote(business, showSnackBar: false);
    if (quote == null) return;

    setState(() {
      _savingPdf = true;
    });

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
        setState(() {
          _savingPdf = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final businessId = widget.profile.businessId;
    final businessAsync = businessId == null
        ? null
        : ref.watch(businessByIdProvider(businessId));

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
                                      value: _quoteDate,
                                      onTap: () => _pickDate(
                                        initialDate: _quoteDate,
                                        onSelected: (date) => _quoteDate = date,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: _DateField(
                                      label: 'Valid Until',
                                      value: _validUntil,
                                      onTap: () => _pickDate(
                                        initialDate: _validUntil,
                                        onSelected: (date) =>
                                            _validUntil = date,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              TextFormField(
                                controller: _preparedByController,
                                decoration: const InputDecoration(
                                  labelText: 'Prepared By',
                                ),
                              ),
                              const SizedBox(height: 10),
                              TextFormField(
                                controller: _currencySymbolController,
                                decoration: const InputDecoration(
                                  labelText: 'Currency Symbol',
                                  hintText: 'Rs.',
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        _SectionCard(
                          title: 'Customer Details',
                          trailing: OutlinedButton.icon(
                            onPressed: () => _pickSavedCustomer(business.id),
                            icon: const Icon(Icons.person_search_outlined),
                            label: const Text('Saved Customers'),
                          ),
                          child: Column(
                            children: [
                              TextFormField(
                                controller: _customerNameController,
                                decoration: const InputDecoration(
                                  labelText: 'Customer Name',
                                ),
                                validator: (value) =>
                                    value == null || value.trim().isEmpty
                                    ? 'Enter customer name'
                                    : null,
                              ),
                              const SizedBox(height: 10),
                              TextFormField(
                                controller: _customerContactController,
                                decoration: const InputDecoration(
                                  labelText: 'Contact Person',
                                ),
                              ),
                              const SizedBox(height: 10),
                              TextFormField(
                                controller: _customerPhoneController,
                                keyboardType: TextInputType.phone,
                                decoration: const InputDecoration(
                                  labelText: 'Phone Number',
                                ),
                              ),
                              const SizedBox(height: 10),
                              TextFormField(
                                controller: _customerEmailController,
                                keyboardType: TextInputType.emailAddress,
                                decoration: const InputDecoration(
                                  labelText: 'Email',
                                ),
                              ),
                              const SizedBox(height: 10),
                              TextFormField(
                                controller: _customerAddressController,
                                maxLines: 3,
                                decoration: const InputDecoration(
                                  labelText: 'Address',
                                ),
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
                            children: List.generate(_items.length, (index) {
                              final item = _items[index];
                              return Padding(
                                padding: EdgeInsets.only(
                                  bottom: index == _items.length - 1 ? 0 : 12,
                                ),
                                child: _QuoteItemCard(
                                  index: index,
                                  item: item,
                                  onRemove: () => _removeItem(index),
                                  onChanged: () => setState(() {}),
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
                                      decoration: const InputDecoration(
                                        labelText: 'Extra Charge Label',
                                      ),
                                      onTap: () => _clearDefaultOnFirstTap(
                                        _extraChargesLabelController,
                                      ),
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
                                      onChanged: (_) => setState(() {}),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              TextFormField(
                                controller: _notesController,
                                maxLines: 3,
                                decoration: const InputDecoration(
                                  labelText: 'Notes',
                                ),
                              ),
                              const SizedBox(height: 10),
                              TextFormField(
                                controller: _additionalTermsController,
                                maxLines: 4,
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
                                onPressed: _savingQuote || _savingPdf
                                    ? null
                                    : () => _saveQuote(business),
                                icon: _savingQuote
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(Icons.save_outlined),
                                label: Text(
                                  _savingQuote
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
                                onPressed: _savingPdf || _savingQuote
                                    ? null
                                    : () => _generatePdf(business),
                                icon: _savingPdf
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(Icons.picture_as_pdf_outlined),
                                label: Text(
                                  _savingPdf ? 'Generating...' : 'Generate PDF',
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Customer details and quotation lines are saved to Firestore so you can edit them later from Quotation History.',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodySmall,
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
  _QuoteItemDraft({
    String title = '',
    String description = '',
    String quantity = '1',
    String unit = 'pcs',
    String unitPrice = '',
    String discount = '0',
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

  QuoteLineItem toLineItem() {
    return QuoteLineItem(
      title: titleController.text.trim(),
      description: descriptionController.text.trim().isEmpty
          ? null
          : descriptionController.text.trim(),
      quantity: double.tryParse(quantityController.text.trim()) ?? 0,
      unit: unitController.text.trim().isEmpty
          ? null
          : unitController.text.trim(),
      unitPrice: double.tryParse(unitPriceController.text.trim()) ?? 0,
      discountAmount: double.tryParse(discountController.text.trim()) ?? 0,
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
                child: TextFormField(
                  controller: item.unitController,
                  decoration: const InputDecoration(labelText: 'Unit'),
                  onChanged: (_) => onChanged(),
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
                child: TextFormField(
                  controller: item.discountController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(labelText: 'Discount'),
                  onChanged: (_) => onChanged(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: item.taxPercentController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Tax %'),
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
