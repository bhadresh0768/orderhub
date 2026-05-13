import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/order.dart';
import 'currency_defaults.dart';
import 'money_format.dart';

class OrderBillPdfGenerator {
  OrderBillPdfGenerator._();

  static Future<Uint8List> build({
    required Order order,
    required String businessName,
    String? businessAddress,
    String? businessPhone,
    String? businessLogoUrl,
    String? currencySymbol,
    String? taxLabel,
  }) async {
    final pdf = pw.Document();
    final businessLogoImage = await _loadBusinessLogo(businessLogoUrl);
    final includedItems = order.items.where((item) => item.isIncluded ?? true).toList();
    final subtotal = order.subtotalAmount ?? 0;
    final gstPercent = order.gstPercent ?? 0;
    final gstAmount = order.gstAmount ?? 0;
    final extra = order.extraCharges ?? 0;
    final grandTotal = order.totalAmount ?? order.payment.amount ?? 0;
    final resolvedTaxLabel = (taxLabel ?? '').trim().isEmpty
        ? 'TAX'
        : taxLabel!.trim();
    final resolvedCurrencySymbol =
        (currencySymbol ?? '').trim().isNotEmpty
        ? currencySymbol!.trim()
        : defaultCurrencySymbolForCountryCode(
            ui.PlatformDispatcher.instance.locale.countryCode,
          );

    String fmtAmount(double value) {
      return formatMoney(value, currencySymbol: resolvedCurrencySymbol);
    }

    String fmtDate(DateTime? date) {
      if (date == null) return '-';
      return DateFormat('dd MMM yyyy, hh:mm a').format(date.toLocal());
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        build: (context) => [
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    if (businessLogoImage != null) ...[
                      pw.Container(
                        height: 56,
                        width: 56,
                        decoration: pw.BoxDecoration(
                          border: pw.Border.all(color: PdfColors.grey300),
                          borderRadius: pw.BorderRadius.circular(6),
                        ),
                        padding: const pw.EdgeInsets.all(4),
                        child: pw.Image(
                          businessLogoImage,
                          fit: pw.BoxFit.contain,
                        ),
                      ),
                      pw.SizedBox(width: 10),
                    ],
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            businessName,
                            style: pw.TextStyle(
                              fontSize: 20,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                          if ((businessAddress ?? '').trim().isNotEmpty)
                            pw.Text(businessAddress!.trim()),
                          if ((businessPhone ?? '').trim().isNotEmpty)
                            pw.Text('Phone: ${businessPhone!.trim()}'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey300,
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Text(
                  'BILL / INVOICE',
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 16),
          pw.Text('Order No: ${order.displayOrderNumber}'),
          pw.Text('Order ID: ${order.id}'),
          pw.Text('Customer: ${order.customerName}'),
          pw.Text('Created: ${fmtDate(order.createdAt)}'),
          pw.Text('Delivered: ${fmtDate(order.delivery.deliveredAt)}'),
          pw.SizedBox(height: 12),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey400),
            columnWidths: {
              0: const pw.FlexColumnWidth(4),
              1: const pw.FlexColumnWidth(1.6),
              2: const pw.FlexColumnWidth(1.8),
              3: const pw.FlexColumnWidth(2),
            },
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                children: [
                  _cell('Item', isHeader: true),
                  _cell('Qty', isHeader: true),
                  _cell('Unit Price', isHeader: true),
                  _cell('Line Total', isHeader: true),
                ],
              ),
              ...includedItems.map((item) {
                final unitPrice = item.unitPrice ?? 0;
                final lineBase = unitPrice * item.quantity;
                final lineGst = (item.gstIncluded ?? false) && gstPercent > 0
                    ? lineBase * (gstPercent / 100)
                    : 0;
                final lineTotal = lineBase + lineGst;
                return pw.TableRow(
                  children: [
                    _cell(item.title),
                    _cell(item.quantity.toStringAsFixed(item.quantity.truncateToDouble() == item.quantity ? 0 : 2)),
                    _cell(fmtAmount(unitPrice)),
                    _cell(fmtAmount(lineTotal)),
                  ],
                );
              }),
            ],
          ),
          pw.SizedBox(height: 14),
          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Container(
              width: 230,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                children: [
                  _summaryRow('Subtotal', fmtAmount(subtotal)),
                  _summaryRow(
                    '$resolvedTaxLabel ($gstPercent%)',
                    fmtAmount(gstAmount),
                  ),
                  _summaryRow('Extra Charges', fmtAmount(extra)),
                  pw.Divider(),
                  _summaryRow('Grand Total', fmtAmount(grandTotal), bold: true),
                ],
              ),
            ),
          ),
        ],
      ),
    );

    return pdf.save();
  }

  static pw.Widget _cell(String text, {bool isHeader = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Text(
        text,
        style: pw.TextStyle(fontWeight: isHeader ? pw.FontWeight.bold : null),
      ),
    );
  }

  static pw.Widget _summaryRow(String label, String value, {bool bold = false}) {
    final style = pw.TextStyle(fontWeight: bold ? pw.FontWeight.bold : null);
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        children: [
          pw.Expanded(child: pw.Text(label, style: style)),
          pw.Text(value, style: style),
        ],
      ),
    );
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
