import 'package:flutter_test/flutter_test.dart';
import 'package:dnevnik_plus/security/pin_security.dart';

void main() {
  test('PIN accepts 6-12 numeric digits', () {
    expect(PinSecurity.validPin('123456'), true);
    expect(PinSecurity.validPin('123456789012'), true);
    expect(PinSecurity.validPin('12345'), false);
    expect(PinSecurity.validPin('1234567890123'), false);
    expect(PinSecurity.validPin('123abc'), false);
    expect(PinSecurity.validPin('123 456'), false);
  });
}
