import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

/// Dates, times, prices and counts for the current locale.
///
/// Arabic follows Algerian usage (`ar_DZ`): Latin digits, Maghreb month
/// names (جانفي، فيفري … جويلية، أوت) and prices in "د.ج". Requires
/// `initializeDateFormatting('ar_DZ')` once at start-up (see main.dart).
class StadiaFormat {
  const StadiaFormat._(this.arabic);

  factory StadiaFormat.of(BuildContext context) =>
      Localizations.localeOf(context).languageCode == 'ar' ? ar : en;

  static const en = StadiaFormat._(false);
  static const ar = StadiaFormat._(true);

  final bool arabic;

  String get _intl => arabic ? 'ar_DZ' : 'en';

  /// "Sat 28 Nov" / "السبت 28 نوفمبر".
  String matchDate(DateTime d) => DateFormat('EEE d MMM', _intl).format(d);

  /// "Saturday 28 November".
  String matchDateLong(DateTime d) =>
      DateFormat('EEEE d MMMM', _intl).format(d);

  String time(DateTime d) => DateFormat('HH:mm', _intl).format(d);

  String price(int dzd) => formatPrice(dzd, currency: arabic ? 'د.ج' : 'DA');

  /// 40320 -> "40,320" / "40 320" (ar_DZ's "40.320" reads like a decimal).
  String count(int n) => _group(n, arabic ? _thin : ',');
}

/// Narrow no-break space: groups digits and, being a common separator in
/// the bidi algorithm, keeps "1 500" in order inside Arabic text.
const _thin = ' ';

/// `1500` -> `1 500 DA` (Algerian convention).
String formatPrice(int dzd, {String currency = 'DA'}) =>
    '${_group(dzd, _thin)} $currency';

String formatCount(int n) => _group(n, ',');

String _group(int n, String separator) {
  final digits = n.toString();
  final buf = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buf.write(separator);
    buf.write(digits[i]);
  }
  return buf.toString();
}
