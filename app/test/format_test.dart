import 'package:a_studio/core/format.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('money and durations', () {
    expect(birr(2500), 'Br 2,500');
    expect(durationLabel(45), '45 min');
    expect(durationLabel(90), '1 h 30 min');
    expect(durationLabel(120), '2 h');
  });

  test('clocks', () {
    expect(clockLabel(450), '7:30 AM');
    expect(clockLabel(12 * 60), '12:00 PM');
    expect(clockLabel(0), '12:00 AM');
    expect(bothClocks(5 * 60), '5:00 AM · ሌሊት 11:00');
  });

  test('Addis Ababa time is UTC+3', () {
    final utc = addisToUtc(DateTime(2027, 1, 31), 7 * 60);
    expect(utc, DateTime.utc(2027, 1, 31, 4, 0));
  });

  test('date keys', () {
    expect(dateKey(DateTime(2027, 1, 5)), '2027-01-05');
    expect(parseDateKey('2027-01-05'), DateTime(2027, 1, 5));
    expect(weekdayKey(DateTime(2026, 10, 24)), 'sat');
    expect(bookingRef(4821 - 1000), 'AS-4821');
  });
}
