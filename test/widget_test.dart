import 'package:connect_call/core/utils/formatters.dart';
import 'package:connect_call/core/utils/validators.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Validators', () {
    test('rejects empty and invalid emails', () {
      expect(Validators.email(null), isNotNull);
      expect(Validators.email('not-an-email'), isNotNull);
      expect(Validators.email('user@connectcall.app'), isNull);
    });

    test('enforces password length', () {
      expect(Validators.password('123'), isNotNull);
      expect(Validators.password('secret1'), isNull);
    });

    test('confirms password match', () {
      expect(Validators.confirmPassword('a', 'b'), isNotNull);
      expect(Validators.confirmPassword('secret1', 'secret1'), isNull);
    });
  });

  test('formats call duration', () {
    expect(formatCallDuration(const Duration(seconds: 5)), '00:05');
    expect(formatCallDuration(const Duration(minutes: 2, seconds: 9)), '02:09');
  });
}
