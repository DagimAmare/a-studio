/// Pure availability maths, unit-tested in test/slots_test.dart.
library;

/// Start times (minutes after midnight) where a service of [durationMin]
/// fits inside opening hours [openMin, closeMin), does not touch any busy
/// interval (padded by [bufferMin] on both sides), and starts no earlier
/// than [earliestMin].
List<int> availableStarts({
  required int openMin,
  required int closeMin,
  required int durationMin,
  int stepMin = 30,
  List<List<int>> busy = const [],
  int bufferMin = 0,
  int earliestMin = 0,
}) {
  if (durationMin <= 0 || closeMin <= openMin) return const [];
  final out = <int>[];
  for (var start = openMin; start + durationMin <= closeMin; start += stepMin) {
    if (start < earliestMin) continue;
    final end = start + durationMin;
    var clash = false;
    for (final b in busy) {
      if (b.length < 2) continue;
      final bs = b[0] - bufferMin;
      final be = b[1] + bufferMin;
      if (start < be && end > bs) {
        clash = true;
        break;
      }
    }
    if (!clash) out.add(start);
  }
  return out;
}

/// Minutes after midnight for [t] in local time.
int minutesOf(DateTime t) => t.hour * 60 + t.minute;

/// Rounds [minutes] up to the next multiple of [step].
int roundUp(int minutes, int step) =>
    minutes % step == 0 ? minutes : minutes + (step - minutes % step);
