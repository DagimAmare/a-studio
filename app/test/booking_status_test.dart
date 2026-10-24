import 'package:a_studio/models/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('artist transitions match the security rules', () {
    expect(BookingStatus.artistMay('requested', 'accepted'), isTrue);
    expect(BookingStatus.artistMay('requested', 'confirmed'), isTrue);
    expect(BookingStatus.artistMay('requested', 'completed'), isFalse);
    expect(BookingStatus.artistMay('deposit_submitted', 'accepted'), isTrue);
    expect(BookingStatus.artistMay('confirmed', 'completed'), isTrue);
    expect(BookingStatus.artistMay('completed', 'confirmed'), isFalse);
  });

  test('client transitions match the security rules', () {
    expect(BookingStatus.clientMay('accepted', 'deposit_submitted'), isTrue);
    expect(BookingStatus.clientMay('requested', 'cancelled_client'), isTrue);
    expect(BookingStatus.clientMay('requested', 'confirmed'), isFalse);
    expect(BookingStatus.clientMay('completed', 'cancelled_client'), isFalse);
  });

  test('labels exist in both languages', () {
    for (final s in [...BookingStatus.open, ...BookingStatus.closed]) {
      expect(BookingStatus.label(s, false), isNot(s));
      expect(BookingStatus.label(s, true), isNot(s));
    }
  });
}
