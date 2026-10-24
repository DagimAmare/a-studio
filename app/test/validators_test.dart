import 'package:a_studio/core/validators.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('handles', () {
    expect(normalizeHandle(' Hana Glam! '), 'hanaglam');
    expect(handleProblem('hana'), isNull);
    expect(handleProblem('hana.glam_1'), isNull);
    expect(handleProblem('ab'), isNotNull);
    expect(handleProblem('-hana'), isNotNull);
    expect(handleProblem('shop'), isNotNull);
    expect(handleProblem('desk'), isNotNull);
  });

  test('phones', () {
    expect(normalizeEthiopianPhone('0911 234 567'), '+251911234567');
    expect(normalizeEthiopianPhone('+251 711 234 567'), '+251711234567');
    expect(normalizeEthiopianPhone('911234567'), '+251911234567');
    expect(normalizeEthiopianPhone('0811234567'), isNull);
    expect(whatsappDigits('0911234567'), '251911234567');
    expect(whatsappDigits('+1 (202) 555-0100'), '12025550100');
  });

  test('email and telegram', () {
    expect(isEmail('selam@example.com'), isTrue);
    expect(isEmail('selam@'), isFalse);
    expect(telegramUsername('@hana_glam'), 'hana_glam');
    expect(telegramUsername('https://t.me/hana_glam'), 'hana_glam');
  });
}
