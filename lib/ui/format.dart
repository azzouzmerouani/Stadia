import 'package:intl/intl.dart';

final _date = DateFormat('EEE d MMM');
final _dateLong = DateFormat('EEEE d MMMM');
final _time = DateFormat('HH:mm');

String formatMatchDate(DateTime d) => _date.format(d);
String formatMatchDateLong(DateTime d) => _dateLong.format(d);
String formatTime(DateTime d) => _time.format(d);

/// `1500` → `1 500 DA` (Algerian convention, thin no-break space).
String formatPrice(int dzd) {
  final digits = dzd.toString();
  final buf = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buf.write(' ');
    buf.write(digits[i]);
  }
  return '$buf DA';
}

String formatCount(int n) {
  final digits = n.toString();
  final buf = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buf.write(',');
    buf.write(digits[i]);
  }
  return buf.toString();
}
