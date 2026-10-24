import 'package:a_studio/core/ethiopian.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('known Ethiopian dates', () {
    expect(toEthiopian(DateTime(2026, 9, 11)), const EthDate(2019, 1, 1));
    expect(toEthiopian(DateTime(2023, 9, 12)), const EthDate(2016, 1, 1));
    expect(toEthiopian(DateTime(2026, 10, 24)), const EthDate(2019, 2, 14));
    expect(toEthiopian(DateTime(2027, 1, 7)), const EthDate(2019, 4, 29));
    expect(ethDayMonth(DateTime(2027, 1, 31)), 'Tir 23');
    expect(ethDayMonth(DateTime(2027, 1, 19), amharic: true), 'ጥር 11');
  });

  test('round trip over 150 years', () {
    var g = DateTime(1950, 1, 1);
    for (var i = 0; i < 365 * 150; i += 3) {
      final e = toEthiopian(g);
      expect(fromEthiopian(e.year, e.month, e.day), g, reason: 'at $g');
      g = DateTime(g.year, g.month, g.day + 3);
    }
  });

  test('Orthodox Easter', () {
    expect(orthodoxEaster(2026), DateTime(2026, 4, 12));
    expect(orthodoxEaster(2027), DateTime(2027, 5, 2));
    expect(orthodoxEaster(2028), DateTime(2028, 4, 16));
  });

  test('Glam Calendar 2027', () {
    final ev = {for (final e in glamEventsForYear(2027)) e.id: e};
    expect(ev['genna-2027']!.start, DateTime(2027, 1, 7));
    expect(ev['timket-2027']!.start, DateTime(2027, 1, 19));
    expect(ev['fasika-2027']!.start, DateTime(2027, 5, 2));
    expect(ev['lent-2027']!.start, DateTime(2027, 3, 8));
    expect(ev['wedding2-2027']!.start, DateTime(2027, 5, 9));
    // 2019 E.C. has a sixth Pagume day, so the new year moves to 12 Sept.
    expect(ev['enkutatash-2027']!.start, DateTime(2027, 9, 12));
    expect(ev['meskel-2027']!.start, DateTime(2027, 9, 28));
  });

  test('Ethiopian clock', () {
    expect(ethClock(5, 0), 'ሌሊት 11:00');
    expect(ethClock(7, 30), 'ጠዋት 1:30');
    expect(ethClock(12, 0), 'ከሰዓት 6:00');
    expect(ethClock(18, 0), 'ምሽት 12:00');
  });
}
