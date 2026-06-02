import 'package:flutter_test/flutter_test.dart';
import 'package:p_guard_mobile/utils/thai_baht_text.dart';

void main() {
  group('bahtText', () {
    final cases = <num, String>{
      0: 'ศูนย์บาทถ้วน',
      1: 'หนึ่งบาทถ้วน',
      10: 'สิบบาทถ้วน',
      11: 'สิบเอ็ดบาทถ้วน',
      20: 'ยี่สิบบาทถ้วน',
      21: 'ยี่สิบเอ็ดบาทถ้วน',
      25: 'ยี่สิบห้าบาทถ้วน',
      100: 'หนึ่งร้อยบาทถ้วน',
      101: 'หนึ่งร้อยเอ็ดบาทถ้วน',
      111: 'หนึ่งร้อยสิบเอ็ดบาทถ้วน',
      2500: 'สองพันห้าร้อยบาทถ้วน',
      2675.50: 'สองพันหกร้อยเจ็ดสิบห้าบาทห้าสิบสตางค์',
      1000000: 'หนึ่งล้านบาทถ้วน',
      0.75: 'เจ็ดสิบห้าสตางค์',
      0.01: 'หนึ่งสตางค์',
      1234567.89:
          'หนึ่งล้านสองแสนสามหมื่นสี่พันห้าร้อยหกสิบเจ็ดบาทแปดสิบเก้าสตางค์',
    };

    cases.forEach((amount, expected) {
      test('$amount -> $expected', () {
        expect(bahtText(amount), expected);
      });
    });

    test('rounds 99.999 satang rollover up to next baht', () {
      expect(bahtText(2.999), 'สามบาทถ้วน');
    });

    test('negative prefixes ลบ', () {
      expect(bahtText(-50), 'ลบห้าสิบบาทถ้วน');
    });
  });
}
