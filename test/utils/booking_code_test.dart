import 'package:flutter_test/flutter_test.dart';
import 'package:kedotaapp/utils/booking_code.dart';

void main() {
  group('booking_code', () {
    test('treats empty and KDT codes as legacy', () {
      expect(isLegacyKdtBookingCode(null), isTrue);
      expect(isLegacyKdtBookingCode(''), isTrue);
      expect(isLegacyKdtBookingCode('KDT-2026000007'), isTrue);
      expect(isLegacyKdtBookingCode('EMR-9759-10092026'), isFalse);
    });

    test('builds a stable EMR-####-######## code from an appointment id', () {
      const id = 'aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee';
      final code = appointmentBookingCode(id);
      expect(code, matches(RegExp(r'^EMR-\d{4}-\d{8}$')));
      expect(appointmentBookingCode(id), code);
    });
  });
}
