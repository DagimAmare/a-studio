/// Ethiopian calendar and clock, written from scratch so a stale package can
/// never shift a holiday. Verified against known New Year anchors
/// (2016-2020 E.C.) and a 150-year round trip; see test/ethiopian_test.dart.
library;

class EthDate {
  final int year;
  final int month; // 1..13 (13 = Pagume)
  final int day;
  const EthDate(this.year, this.month, this.day);

  @override
  bool operator ==(Object other) =>
      other is EthDate &&
      other.year == year &&
      other.month == month &&
      other.day == day;

  @override
  int get hashCode => Object.hash(year, month, day);

  @override
  String toString() => '$year-$month-$day';
}

const List<String> kEthMonthsEn = [
  'Meskerem', 'Tikimt', 'Hidar', 'Tahsas', 'Tir', 'Yekatit', 'Megabit',
  'Miyazia', 'Ginbot', 'Sene', 'Hamle', 'Nehase', 'Pagume',
];

const List<String> kEthMonthsAm = [
  'መስከረም', 'ጥቅምት', 'ኅዳር', 'ታኅሣሥ', 'ጥር', 'የካቲት', 'መጋቢት',
  'ሚያዝያ', 'ግንቦት', 'ሰኔ', 'ሐምሌ', 'ነሐሴ', 'ጳጉሜ',
];

/// Julian Day Number of the Ethiopian (Amete Mihret) era offset.
const int _era = 1723856;

int jdnFromGregorian(int y, int m, int d) {
  final a = (14 - m) ~/ 12;
  final yy = y + 4800 - a;
  final mm = m + 12 * a - 3;
  return d +
      (153 * mm + 2) ~/ 5 +
      365 * yy +
      yy ~/ 4 -
      yy ~/ 100 +
      yy ~/ 400 -
      32045;
}

DateTime gregorianFromJdn(int jdn) {
  final a = jdn + 32044;
  final b = (4 * a + 3) ~/ 146097;
  final c = a - (146097 * b) ~/ 4;
  final d = (4 * c + 3) ~/ 1461;
  final e = c - (1461 * d) ~/ 4;
  final m = (5 * e + 2) ~/ 153;
  final day = e - (153 * m + 2) ~/ 5 + 1;
  final month = m + 3 - 12 * (m ~/ 10);
  final year = 100 * b + d - 4800 + m ~/ 10;
  return DateTime(year, month, day);
}

EthDate toEthiopian(DateTime g) {
  final j = jdnFromGregorian(g.year, g.month, g.day);
  final r = (j - _era) % 1461;
  final n = (r % 365) + 365 * (r ~/ 1460);
  final year = 4 * ((j - _era) ~/ 1461) + r ~/ 365 - r ~/ 1460;
  return EthDate(year, n ~/ 30 + 1, n % 30 + 1);
}

DateTime fromEthiopian(int year, int month, int day) {
  return gregorianFromJdn(
      _era + 365 + 365 * (year - 1) + year ~/ 4 + 30 * month + day - 31);
}

/// "Tir 23" / "ጥር 23".
String ethDayMonth(DateTime g, {bool amharic = false}) {
  final e = toEthiopian(g);
  final names = amharic ? kEthMonthsAm : kEthMonthsEn;
  return '${names[e.month - 1]} ${e.day}';
}

/// "Tir 23, 2019" / "ጥር 23 ቀን 2019".
String ethFull(DateTime g, {bool amharic = false}) {
  final e = toEthiopian(g);
  if (amharic) return '${kEthMonthsAm[e.month - 1]} ${e.day} ቀን ${e.year}';
  return '${kEthMonthsEn[e.month - 1]} ${e.day}, ${e.year}';
}

/// Ethiopian clock: hours count from 6 AM. 5:00 AM is "ሌሊት 11:00".
String ethClock(int hour24, int minute) {
  final h = (hour24 + 6) % 12;
  final eh = h == 0 ? 12 : h;
  final String period;
  if (hour24 < 6) {
    period = 'ሌሊት';
  } else if (hour24 < 12) {
    period = 'ጠዋት';
  } else if (hour24 < 18) {
    period = 'ከሰዓት';
  } else {
    period = 'ምሽት';
  }
  return '$period $eh:${minute.toString().padLeft(2, '0')}';
}

/// Orthodox (Julian) Easter as a Gregorian date. Valid 1900-2099.
DateTime orthodoxEaster(int year) {
  final a = year % 4;
  final b = year % 7;
  final c = year % 19;
  final d = (19 * c + 15) % 30;
  final e = (2 * a + 4 * b - d + 34) % 7;
  final month = (d + e + 114) ~/ 31;
  final day = ((d + e + 114) % 31) + 1;
  return DateTime(year, month, day + 13);
}

class GlamEvent {
  final String id;
  final String nameEn;
  final String nameAm;
  final DateTime start;
  final DateTime end;
  final String kind; // holiday | season | fast | personal
  final bool expected; // moon-sighting dates are estimates
  const GlamEvent({
    required this.id,
    required this.nameEn,
    required this.nameAm,
    required this.start,
    required this.end,
    required this.kind,
    this.expected = false,
  });

  bool get isSpan => end.isAfter(start);
}

/// Eid dates follow moon sighting; these are astronomical estimates the
/// admin can confirm later.
const Map<int, List<String>> _eid = {
  2026: ['2026-03-20', '2026-05-27'],
  2027: ['2027-03-10', '2027-05-16'],
  2028: ['2028-02-27', '2028-05-05'],
};

DateTime _d(int y, int m, int d) => DateTime(y, m, d);

/// Calendar-day arithmetic. Adding Durations to local dates drifts by an
/// hour across daylight-saving changes (seen on a UK computer), so days are
/// always added through the constructor.
DateTime plusDays(DateTime d, int days) => DateTime(d.year, d.month, d.day + days);

/// Every Glam Calendar event touching Gregorian [year].
List<GlamEvent> glamEventsForYear(int year) {
  final easter = orthodoxEaster(year);
  final lentStart = plusDays(easter, -55);
  final pentecost = plusDays(easter, 49);
  final eth = toEthiopian(_d(year, 9, 20)).year; // E.C. year starting this Sept
  final ethPrev = eth - 1; // E.C. year running Jan..Aug of [year]

  final events = <GlamEvent>[
    GlamEvent(
        id: 'genna-$year',
        nameEn: 'Genna',
        nameAm: 'ገና',
        start: _d(year, 1, 7),
        end: _d(year, 1, 7),
        kind: 'holiday'),
    GlamEvent(
        id: 'timket-$year',
        nameEn: 'Timket',
        nameAm: 'ጥምቀት',
        start: fromEthiopian(ethPrev, 5, 11),
        end: fromEthiopian(ethPrev, 5, 11),
        kind: 'holiday'),
    GlamEvent(
        id: 'wedding1-$year',
        nameEn: 'Wedding season',
        nameAm: 'የሠርግ ወቅት',
        start: _d(year, 1, 8),
        end: plusDays(lentStart, -1),
        kind: 'season'),
    GlamEvent(
        id: 'valentines-$year',
        nameEn: "Valentine's Day",
        nameAm: 'የፍቅረኞች ቀን',
        start: _d(year, 2, 14),
        end: _d(year, 2, 14),
        kind: 'holiday'),
    GlamEvent(
        id: 'womens-day-$year',
        nameEn: "International Women's Day",
        nameAm: 'የሴቶች ቀን',
        start: _d(year, 3, 8),
        end: _d(year, 3, 8),
        kind: 'holiday'),
    GlamEvent(
        id: 'lent-$year',
        nameEn: 'Lent (Abiy Tsom)',
        nameAm: 'ዐቢይ ጾም',
        start: lentStart,
        end: plusDays(easter, -1),
        kind: 'fast'),
    GlamEvent(
        id: 'fasika-$year',
        nameEn: 'Fasika',
        nameAm: 'ፋሲካ',
        start: easter,
        end: easter,
        kind: 'holiday'),
    GlamEvent(
        id: 'wedding2-$year',
        nameEn: 'Wedding season',
        nameAm: 'የሠርግ ወቅት',
        start: plusDays(easter, 7),
        end: pentecost,
        kind: 'season'),
    GlamEvent(
        id: 'graduation-$year',
        nameEn: 'Graduation season',
        nameAm: 'የምረቃ ወቅት',
        start: fromEthiopian(ethPrev, 11, 1),
        end: plusDays(fromEthiopian(ethPrev, 12, 1), -1),
        kind: 'season'),
    GlamEvent(
        id: 'ashenda-$year',
        nameEn: 'Ashenda',
        nameAm: 'አሸንዳ',
        start: fromEthiopian(ethPrev, 12, 16),
        end: fromEthiopian(ethPrev, 12, 16),
        kind: 'holiday'),
    GlamEvent(
        id: 'enkutatash-$year',
        nameEn: 'Enkutatash',
        nameAm: 'እንቁጣጣሽ',
        start: fromEthiopian(eth, 1, 1),
        end: fromEthiopian(eth, 1, 1),
        kind: 'holiday'),
    GlamEvent(
        id: 'meskel-$year',
        nameEn: 'Meskel',
        nameAm: 'መስቀል',
        start: fromEthiopian(eth, 1, 17),
        end: fromEthiopian(eth, 1, 17),
        kind: 'holiday'),
  ];
  final eid = _eid[year];
  if (eid != null) {
    events.add(GlamEvent(
        id: 'eid-fitr-$year',
        nameEn: 'Eid al-Fitr',
        nameAm: 'ዒድ አል ፈጥር',
        start: DateTime.parse(eid[0]),
        end: DateTime.parse(eid[0]),
        kind: 'holiday',
        expected: true));
    events.add(GlamEvent(
        id: 'eid-adha-$year',
        nameEn: 'Eid al-Adha',
        nameAm: 'ዒድ አል አድሐ',
        start: DateTime.parse(eid[1]),
        end: DateTime.parse(eid[1]),
        kind: 'holiday',
        expected: true));
  }
  events.sort((a, b) => a.start.compareTo(b.start));
  return events;
}

/// Events that end on or after [from] and start within [days] days.
List<GlamEvent> upcomingGlamEvents(DateTime from, {int days = 60}) {
  final today = DateTime(from.year, from.month, from.day);
  final horizon = plusDays(today, days);
  final all = [
    ...glamEventsForYear(today.year),
    ...glamEventsForYear(today.year + 1),
  ];
  return all
      .where((e) => !e.end.isBefore(today) && !e.start.isAfter(horizon))
      .toList()
    ..sort((a, b) => a.start.compareTo(b.start));
}
