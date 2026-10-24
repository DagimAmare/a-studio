import 'package:intl/intl.dart';

import 'ethiopian.dart';

final NumberFormat _thousands = NumberFormat('#,##0', 'en_US');

/// "Br 2,500".
String birr(num amount) => 'Br ${_thousands.format(amount.round())}';

/// "1 h 30 min" / "45 min".
String durationLabel(int minutes) {
  if (minutes < 60) return '$minutes min';
  final h = minutes ~/ 60;
  final m = minutes % 60;
  return m == 0 ? '$h h' : '$h h $m min';
}

/// "7:30 AM" from minutes after midnight.
String clockLabel(int minutesFromMidnight) {
  final h = minutesFromMidnight ~/ 60;
  final m = minutesFromMidnight % 60;
  final suffix = h < 12 ? 'AM' : 'PM';
  final hh = h % 12 == 0 ? 12 : h % 12;
  return '$hh:${m.toString().padLeft(2, '0')} $suffix';
}

/// Both clocks: "7:30 AM · ጠዋት 1:30".
String bothClocks(int minutesFromMidnight) =>
    '${clockLabel(minutesFromMidnight)} · ${ethClock(minutesFromMidnight ~/ 60, minutesFromMidnight % 60)}';

/// "Sat 31 Jan".
String dayLabel(DateTime d) => DateFormat('EEE d MMM', 'en_US').format(d);

/// "Sat 31 Jan 2027".
String dayLabelYear(DateTime d) =>
    DateFormat('EEE d MMM y', 'en_US').format(d);

/// "Sat 31 Jan · Tir 23" (Ethiopian month in Amharic when asked).
String bothDates(DateTime d, {bool amharic = false}) =>
    '${dayLabel(d)} · ${ethDayMonth(d, amharic: amharic)}';

/// Wall-clock time in Addis Ababa (UTC+3, no daylight saving), returned as
/// a DateTime whose fields read as Addis time.
DateTime addisNow() {
  final u = DateTime.now().toUtc().add(const Duration(hours: 3));
  return DateTime(u.year, u.month, u.day, u.hour, u.minute, u.second);
}

/// The UTC instant for [minutes] after midnight on [day] in Addis Ababa.
DateTime addisToUtc(DateTime day, int minutes) =>
    DateTime.utc(day.year, day.month, day.day, minutes ~/ 60, minutes % 60)
        .subtract(const Duration(hours: 3));

/// yyyy-MM-dd key used for bookings, busy days and blocked dates.
String dateKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

DateTime parseDateKey(String key) {
  final p = key.split('-');
  return DateTime(int.parse(p[0]), int.parse(p[1]), int.parse(p[2]));
}

/// "just now", "5 min", "3 h", "2 d", or a date.
String timeAgo(DateTime? t, {DateTime? now}) {
  if (t == null) return '';
  final n = now ?? DateTime.now();
  final diff = n.difference(t);
  if (diff.inSeconds < 60) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes} min';
  if (diff.inHours < 24) return '${diff.inHours} h';
  if (diff.inDays < 7) return '${diff.inDays} d';
  return DateFormat('d MMM', 'en_US').format(t);
}

/// Weekday key used in opening hours: mon..sun.
const List<String> kWeekdayKeys = ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'];
const List<String> kWeekdayEn = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const List<String> kWeekdayAm = ['ሰኞ', 'ማክሰኞ', 'ረቡዕ', 'ሐሙስ', 'ዓርብ', 'ቅዳሜ', 'እሑድ'];

String weekdayKey(DateTime d) => kWeekdayKeys[d.weekday - 1];

/// A short human booking reference: AS-4821.
String bookingRef(int seed) => 'AS-${(1000 + seed % 9000)}';
