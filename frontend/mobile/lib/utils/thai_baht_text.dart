/// Convert a numeric amount to its Thai "bahttext" reading
/// (e.g. 2,675.50 → "สองพันหกร้อยเจ็ดสิบห้าบาทห้าสิบสตางค์").
///
/// Handles the standard Thai number rules: "เอ็ด" for a trailing 1 in a
/// multi-digit number, "ยี่สิบ" for 20, bare "สิบ" for 10, and "ล้าน" grouping
/// for values ≥ 1,000,000. Satang are rounded to 2 decimals; 0 satang reads as
/// "...บาทถ้วน".
String bahtText(num amount) {
  if (amount == 0) return 'ศูนย์บาทถ้วน';
  final negative = amount < 0;
  final abs = amount.abs();
  final baht = abs.floor();
  // Round satang to nearest unit; guard the 99.999→100 rollover.
  var satang = ((abs - baht) * 100).round();
  var wholeBaht = baht;
  if (satang == 100) {
    wholeBaht += 1;
    satang = 0;
  }

  final sb = StringBuffer();
  if (wholeBaht > 0) {
    sb.write(_intToThaiWords(wholeBaht));
    sb.write('บาท');
  }
  if (satang > 0) {
    sb.write(_intToThaiWords(satang));
    sb.write('สตางค์');
  } else {
    sb.write('ถ้วน');
  }
  return (negative ? 'ลบ' : '') + sb.toString();
}

const List<String> _thaiDigits = [
  '',
  'หนึ่ง',
  'สอง',
  'สาม',
  'สี่',
  'ห้า',
  'หก',
  'เจ็ด',
  'แปด',
  'เก้า',
];

const List<String> _thaiPlaces = ['', 'สิบ', 'ร้อย', 'พัน', 'หมื่น', 'แสน'];

/// Convert a non-negative integer to Thai words (no "บาท" suffix).
String _intToThaiWords(int number) {
  if (number == 0) return 'ศูนย์';

  // Group by millions: <n>ล้าน<remainder>.
  if (number >= 1000000) {
    final millions = number ~/ 1000000;
    final remainder = number % 1000000;
    final head = '${_intToThaiWords(millions)}ล้าน';
    return remainder > 0 ? head + _intToThaiWords(remainder) : head;
  }

  final digits = number.toString();
  final len = digits.length;
  final buf = StringBuffer();
  for (var i = 0; i < len; i++) {
    final d = digits.codeUnitAt(i) - 0x30;
    final place = len - i - 1; // 0 = units, 1 = tens, ...
    if (d == 0) continue;
    if (place == 1) {
      // tens place: 1→สิบ, 2→ยี่สิบ, else <digit>สิบ
      if (d == 1) {
        buf.write('สิบ');
      } else if (d == 2) {
        buf.write('ยี่สิบ');
      } else {
        buf.write('${_thaiDigits[d]}สิบ');
      }
    } else if (place == 0) {
      // units place: trailing 1 in a multi-digit number reads "เอ็ด"
      buf.write(d == 1 && len > 1 ? 'เอ็ด' : _thaiDigits[d]);
    } else {
      buf.write('${_thaiDigits[d]}${_thaiPlaces[place]}');
    }
  }
  return buf.toString();
}
