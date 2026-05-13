import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'money_format.dart';

class QuotePdfParty {
  const QuotePdfParty({
    required this.name,
    this.contactName,
    this.address,
    this.phone,
    this.email,
    this.taxRegistrationLabel,
    this.taxRegistrationNumber,
  });

  final String name;
  final String? contactName;
  final String? address;
  final String? phone;
  final String? email;
  final String? taxRegistrationLabel;
  final String? taxRegistrationNumber;
}

class QuotePdfLineItem {
  const QuotePdfLineItem({
    required this.title,
    required this.quantity,
    required this.unitPrice,
    this.description,
    this.unit,
    this.discountAmount = 0,
    this.taxPercent = 0,
  });

  final String title;
  final String? description;
  final double quantity;
  final String? unit;
  final double unitPrice;
  final double discountAmount;
  final double taxPercent;

  double get grossAmount => quantity * unitPrice;

  double get taxableAmount {
    final amount = grossAmount - discountAmount;
    return amount < 0 ? 0 : amount;
  }

  double get taxAmount => taxableAmount * (taxPercent / 100);

  double get totalAmount => taxableAmount + taxAmount;
}

class QuotePdfDocumentData {
  const QuotePdfDocumentData({
    required this.quoteNumber,
    required this.quoteDate,
    required this.validUntil,
    required this.business,
    required this.customer,
    required this.items,
    this.businessLogoUrl,
    this.currencySymbol = 'Rs.',
    this.preparedBy,
    this.extraCharges = 0,
    this.extraChargesLabel = 'Extra Charges',
    this.notes,
    this.paymentTerms,
    this.deliveryTimeline,
    this.additionalTerms = const <String>[],
    this.footerNote,
    this.showAcceptanceSection = true,
  });

  final String quoteNumber;
  final DateTime quoteDate;
  final DateTime validUntil;
  final QuotePdfParty business;
  final QuotePdfParty customer;
  final List<QuotePdfLineItem> items;
  final String? businessLogoUrl;
  final String currencySymbol;
  final String? preparedBy;
  final double extraCharges;
  final String extraChargesLabel;
  final String? notes;
  final String? paymentTerms;
  final String? deliveryTimeline;
  final List<String> additionalTerms;
  final String? footerNote;
  final bool showAcceptanceSection;

  double get subtotal => items.fold(0, (sum, item) => sum + item.grossAmount);

  double get discountTotal =>
      items.fold(0, (sum, item) => sum + item.discountAmount);

  double get taxableAmount =>
      items.fold(0, (sum, item) => sum + item.taxableAmount);

  double get taxAmount => items.fold(0, (sum, item) => sum + item.taxAmount);

  double get grandTotal => taxableAmount + taxAmount + extraCharges;

  List<String> get resolvedTerms {
    final customTerms = additionalTerms
        .map((term) => term.trim())
        .where((term) => term.isNotEmpty)
        .toList();
    if (customTerms.isNotEmpty) {
      return <String>[
        if ((paymentTerms ?? '').trim().isNotEmpty) paymentTerms!.trim(),
        if ((deliveryTimeline ?? '').trim().isNotEmpty)
          deliveryTimeline!.trim(),
        ...customTerms,
      ];
    }

    final terms = <String>[
      'Quotation valid until ${DateFormat('dd MMM yyyy').format(validUntil)}.',
      if ((paymentTerms ?? '').trim().isNotEmpty) paymentTerms!.trim(),
      if ((deliveryTimeline ?? '').trim().isNotEmpty) deliveryTimeline!.trim(),
      'Rates are subject to stock availability and final confirmation.',
      'Taxes ${taxAmount > 0 ? 'are included as shown above' : 'are extra if applicable'}.',
    ];
    return terms;
  }
}

class QuotePdfGenerator {
  QuotePdfGenerator._();

  static Future<Uint8List> buildQuotePdf(QuotePdfDocumentData data) async {
    final pdf = pw.Document();
    final businessLogoImage = await _loadBusinessLogo(data.businessLogoUrl);

    pdf.addPage(
      pw.MultiPage(
        margin: const pw.EdgeInsets.all(28),
        pageFormat: PdfPageFormat.a4,
        footer: (context) => pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text(
            'Page ${context.pageNumber} of ${context.pagesCount}',
            style: pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
          ),
        ),
        build: (context) => [
          _buildHeader(data, businessLogoImage),
          pw.SizedBox(height: 18),
          _buildQuoteMeta(data),
          pw.SizedBox(height: 18),
          _buildItemsTable(data),
          pw.SizedBox(height: 18),
          _buildTotalsSection(data),
          if ((data.notes ?? '').trim().isNotEmpty) ...[
            pw.SizedBox(height: 18),
            _buildNotesSection(data),
          ],
          pw.NewPage(freeSpace: 90),
          pw.SizedBox(height: 18),
          _buildTermsSection(data),
          if (data.showAcceptanceSection) ...[
            pw.SizedBox(height: 18),
            _buildAcceptanceSection(),
          ],
          pw.SizedBox(height: 20),
          _buildFooterNote(data),
        ],
      ),
    );

    return pdf.save();
  }

  static pw.Widget _buildHeader(
    QuotePdfDocumentData data,
    pw.MemoryImage? businessLogoImage,
  ) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(bottom: 10),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          bottom: pw.BorderSide(color: PdfColors.blueGrey100, width: 1),
        ),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      data.business.name,
                      style: pw.TextStyle(
                        fontSize: 20,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.blueGrey900,
                      ),
                    ),
                    if ((data.business.address ?? '').trim().isNotEmpty)
                      pw.Padding(
                        padding: const pw.EdgeInsets.only(top: 3),
                        child: pw.Text(
                          data.business.address!.trim(),
                          style: const pw.TextStyle(
                            fontSize: 10,
                            color: PdfColors.blueGrey700,
                          ),
                        ),
                      ),
                    if ((data.business.phone ?? '').trim().isNotEmpty)
                      pw.Padding(
                        padding: const pw.EdgeInsets.only(top: 2),
                        child: pw.Text(
                          'Mobile: ${data.business.phone!.trim()}',
                          style: const pw.TextStyle(
                            fontSize: 10,
                            color: PdfColors.blueGrey700,
                          ),
                        ),
                      ),
                    if ((data.business.email ?? '').trim().isNotEmpty)
                      pw.Padding(
                        padding: const pw.EdgeInsets.only(top: 2),
                        child: pw.Text(
                          'Email: ${data.business.email!.trim()}',
                          style: const pw.TextStyle(
                            fontSize: 10,
                            color: PdfColors.blueGrey700,
                          ),
                        ),
                      ),
                    if ((data.business.taxRegistrationNumber ?? '')
                        .trim()
                        .isNotEmpty)
                      pw.Padding(
                        padding: const pw.EdgeInsets.only(top: 2),
                        child: pw.Text(
                          '${((data.business.taxRegistrationLabel ?? '').trim().isEmpty ? 'Tax ID' : data.business.taxRegistrationLabel!.trim())}: ${data.business.taxRegistrationNumber!.trim()}',
                          style: const pw.TextStyle(
                            fontSize: 10,
                            color: PdfColors.blueGrey700,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              pw.SizedBox(width: 10),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  if (businessLogoImage != null)
                    pw.Container(
                      height: 60,
                      width: 60,
                      decoration: pw.BoxDecoration(
                        border: pw.Border.all(color: PdfColors.grey300),
                        borderRadius: pw.BorderRadius.circular(8),
                      ),
                      padding: const pw.EdgeInsets.all(5),
                      child: pw.Image(
                        businessLogoImage,
                        fit: pw.BoxFit.contain,
                      ),
                    ),
                  pw.SizedBox(height: 8),
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 7,
                    ),
                    decoration: pw.BoxDecoration(
                      color: PdfColors.blueGrey900,
                      borderRadius: pw.BorderRadius.circular(10),
                    ),
                    child: pw.Text(
                      'QUOTATION',
                      style: pw.TextStyle(
                        color: PdfColors.white,
                        fontWeight: pw.FontWeight.bold,
                        letterSpacing: 1.2,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildQuoteMeta(QuotePdfDocumentData data) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Expanded(
          flex: 4,
          child: _infoCard(
            title: 'Quote Details',
            rows: [
              ('Quote Number', data.quoteNumber),
              ('Quote Date', DateFormat('dd MMM yyyy').format(data.quoteDate)),
              (
                'Valid Until',
                DateFormat('dd MMM yyyy').format(data.validUntil),
              ),
              if ((data.preparedBy ?? '').trim().isNotEmpty)
                ('Prepared By', data.preparedBy!.trim()),
            ],
          ),
        ),
        pw.SizedBox(width: 12),
        pw.Expanded(flex: 5, child: _buildPartySection(data)),
      ],
    );
  }

  static pw.Widget _buildPartySection(QuotePdfDocumentData data) {
    return _addressCard(title: 'Customer & Bill To', party: data.customer);
  }

  static pw.Widget _buildItemsTable(QuotePdfDocumentData data) {
    final hasAnyDiscount = data.items.any((item) => item.discountAmount > 0);
    final headerStyle = pw.TextStyle(
      fontWeight: pw.FontWeight.bold,
      color: PdfColors.white,
      fontSize: 9,
    );
    final cellStyle = const pw.TextStyle(fontSize: 9);

    return pw.TableHelper.fromTextArray(
      headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey800),
      headerStyle: headerStyle,
      cellStyle: cellStyle,
      cellAlignment: pw.Alignment.centerLeft,
      headers: [
        'No',
        'Item',
        'Qty',
        'Unit Price',
        if (hasAnyDiscount) 'Discount',
        'Tax %',
        'Amount',
      ],
      columnWidths: {
        0: const pw.FixedColumnWidth(22),
        1: const pw.FlexColumnWidth(3.4),
        2: const pw.FlexColumnWidth(1),
        3: const pw.FlexColumnWidth(1.3),
        if (hasAnyDiscount) 4: const pw.FlexColumnWidth(1.2),
        hasAnyDiscount ? 5 : 4: const pw.FlexColumnWidth(0.9),
        hasAnyDiscount ? 6 : 5: const pw.FlexColumnWidth(1.3),
      },
      rowDecoration: const pw.BoxDecoration(
        border: pw.Border(
          bottom: pw.BorderSide(color: PdfColors.blueGrey50, width: .5),
        ),
      ),
      data: List<List<String>>.generate(data.items.length, (index) {
        final item = data.items[index];
        final unitSuffix = (item.unit ?? '').trim().isEmpty
            ? ''
            : ' ${item.unit!.trim()}';
        final description = (item.description ?? '').trim();
        final itemLabel = description.isEmpty
            ? item.title
            : '${item.title}\n$description';
        return [
          '${index + 1}',
          itemLabel,
          '${_formatNumber(item.quantity)}$unitSuffix',
          _money(data.currencySymbol, item.unitPrice),
          if (hasAnyDiscount)
            item.discountAmount > 0
                ? _money(data.currencySymbol, item.discountAmount)
                : '',
          _formatNumber(item.taxPercent),
          _money(data.currencySymbol, item.totalAmount),
        ];
      }),
    );
  }

  static pw.Widget _buildTotalsSection(QuotePdfDocumentData data) {
    return pw.Align(
      alignment: pw.Alignment.centerRight,
      child: pw.Container(
        width: 240,
        padding: const pw.EdgeInsets.all(14),
        decoration: pw.BoxDecoration(
          color: PdfColors.blueGrey50,
          borderRadius: pw.BorderRadius.circular(10),
        ),
        child: pw.Column(
          children: [
            _totalRow('Subtotal', _money(data.currencySymbol, data.subtotal)),
            if (data.discountTotal > 0)
              _totalRow(
                'Discount',
                _money(data.currencySymbol, data.discountTotal),
              ),
            _totalRow(
              'Taxable Amount',
              _money(data.currencySymbol, data.taxableAmount),
            ),
            if (data.taxAmount > 0)
              _totalRow('Tax', _money(data.currencySymbol, data.taxAmount)),
            if (data.extraCharges > 0)
              _totalRow(
                data.extraChargesLabel,
                _money(data.currencySymbol, data.extraCharges),
              ),
            pw.Divider(color: PdfColors.blueGrey200),
            _totalRow(
              'Grand Total',
              _money(data.currencySymbol, data.grandTotal),
              highlight: true,
            ),
          ],
        ),
      ),
    );
  }

  static pw.Widget _buildNotesSection(QuotePdfDocumentData data) {
    return _sectionCard(
      title: 'Notes',
      child: pw.Text(
        data.notes!.trim(),
        style: const pw.TextStyle(fontSize: 10, color: PdfColors.red),
      ),
    );
  }

  static pw.Widget _buildTermsSection(QuotePdfDocumentData data) {
    return _sectionCard(
      title: 'Terms and Conditions',
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: List.generate(data.resolvedTerms.length, (index) {
          return pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 6),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  '${index + 1}. ',
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                ),
                pw.Expanded(
                  child: pw.Text(
                    data.resolvedTerms[index],
                    style: const pw.TextStyle(
                      fontSize: 10,
                      color: PdfColors.blueGrey800,
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }

  static pw.Widget _buildAcceptanceSection() {
    return _sectionCard(
      title: 'Customer Acceptance',
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'Accepted by customer',
            style: pw.TextStyle(fontSize: 10, color: PdfColors.blueGrey800),
          ),
          pw.SizedBox(height: 24),
          pw.Row(
            children: [
              pw.Expanded(child: _signatureLine('Customer Signature')),
              pw.SizedBox(width: 20),
              pw.Expanded(child: _signatureLine('Authorized Signature')),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildFooterNote(QuotePdfDocumentData data) {
    final note = (data.footerNote ?? '').trim().isEmpty
        ? 'This is a system-generated quotation.'
        : data.footerNote!.trim();
    return pw.Align(
      alignment: pw.Alignment.center,
      child: pw.Text(
        note,
        textAlign: pw.TextAlign.center,
        style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
      ),
    );
  }

  static pw.Widget _infoCard({
    required String title,
    required List<(String, String)> rows,
  }) {
    return _sectionCard(
      title: title,
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: rows.map((row) {
          return pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 5),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.SizedBox(
                  width: 72,
                  child: pw.Text(
                    row.$1,
                    style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.blueGrey800,
                      fontSize: 10,
                    ),
                  ),
                ),
                pw.Expanded(
                  child: pw.Text(
                    row.$2,
                    style: const pw.TextStyle(
                      fontSize: 10,
                      color: PdfColors.blueGrey700,
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  static pw.Widget _addressCard({
    required String title,
    required QuotePdfParty party,
  }) {
    return _sectionCard(
      title: title,
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: _partyLines(party).map((line) {
          return pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 4),
            child: pw.Text(
              line,
              style: const pw.TextStyle(
                fontSize: 10,
                color: PdfColors.blueGrey800,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  static List<String> _partyLines(QuotePdfParty party) {
    return [
      if ((party.contactName ?? '').trim().isNotEmpty)
        'Contact: ${party.contactName!.trim()}',
      if ((party.address ?? '').trim().isNotEmpty) party.address!.trim(),
      if ((party.phone ?? '').trim().isNotEmpty)
        'Phone: ${party.phone!.trim()}',
      if ((party.email ?? '').trim().isNotEmpty)
        'Email: ${party.email!.trim()}',
      if ((party.taxRegistrationNumber ?? '').trim().isNotEmpty)
        '${((party.taxRegistrationLabel ?? '').trim().isEmpty ? 'Tax ID' : party.taxRegistrationLabel!.trim())}: ${party.taxRegistrationNumber!.trim()}',
    ];
  }

  static pw.Widget _sectionCard({
    required String title,
    required pw.Widget child,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        borderRadius: pw.BorderRadius.circular(10),
        border: pw.Border.all(color: PdfColors.blueGrey100),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            title,
            style: pw.TextStyle(
              fontSize: 11,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.blueGrey900,
            ),
          ),
          pw.SizedBox(height: 10),
          child,
        ],
      ),
    );
  }

  static pw.Widget _totalRow(
    String label,
    String value, {
    bool highlight = false,
  }) {
    final style = pw.TextStyle(
      fontSize: highlight ? 12 : 10,
      fontWeight: highlight ? pw.FontWeight.bold : pw.FontWeight.normal,
      color: highlight ? PdfColors.blueGrey900 : PdfColors.blueGrey800,
    );
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 6),
      child: pw.Row(
        children: [
          pw.Expanded(child: pw.Text(label, style: style)),
          pw.Text(value, style: style),
        ],
      ),
    );
  }

  static pw.Widget _signatureLine(String label) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Container(height: 1, color: PdfColors.blueGrey300),
        pw.SizedBox(height: 5),
        pw.Text(
          label,
          style: const pw.TextStyle(fontSize: 9, color: PdfColors.blueGrey700),
        ),
      ],
    );
  }

  static String _money(String currencySymbol, double amount) {
    return formatMoney(amount, currencySymbol: currencySymbol);
  }

  static String _formatNumber(double value) {
    if (value == value.roundToDouble()) {
      return value.toStringAsFixed(0);
    }
    return value.toStringAsFixed(2);
  }

  static Future<pw.MemoryImage?> _loadBusinessLogo(String? logoUrl) async {
    final url = (logoUrl ?? '').trim();
    if (url.isEmpty) return null;
    try {
      final uri = Uri.parse(url);
      if (!(uri.scheme == 'http' || uri.scheme == 'https')) return null;
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 8);
      final request = await client.getUrl(uri);
      final response = await request.close();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        client.close(force: true);
        return null;
      }
      final bytes = await consolidateHttpClientResponseBytes(response);
      client.close(force: true);
      if (bytes.isEmpty) return null;
      return pw.MemoryImage(bytes);
    } catch (_) {
      return null;
    }
  }
}
