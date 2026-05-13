import 'package:intl/intl.dart';

String formatMoney(
  double? value, {
  String? currencySymbol,
  String notSetLabel = 'Not set',
}) {
  if (value == null) return notSetLabel;
  final amountText = NumberFormat('#,##0.00').format(value);
  final symbol = currencySymbol?.trim() ?? '';
  if (symbol.isEmpty) return amountText;
  return '$symbol $amountText';
}
