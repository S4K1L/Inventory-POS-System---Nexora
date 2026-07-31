import 'package:intl/intl.dart';

/// Formatting helpers shared across modules.
class Fmt {
  Fmt._();

  /// Money with the company currency code, e.g. "BDT 1,250.00".
  static String money(num value, {String currency = 'BDT'}) {
    final f = NumberFormat.currency(
      symbol: '$currency ',
      decimalDigits: 2,
    );
    return f.format(value);
  }

  /// Compact quantity, dropping trailing ".0" for whole numbers.
  static String qty(num value) {
    if (value == value.roundToDouble()) return value.toInt().toString();
    return value.toString();
  }

  static String dateTime(DateTime dt) =>
      DateFormat('d MMM, h:mm a').format(dt);
}
