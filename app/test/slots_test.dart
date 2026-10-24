import 'package:a_studio/core/slots.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('fits inside opening hours', () {
    final s = availableStarts(openMin: 9 * 60, closeMin: 12 * 60, durationMin: 90);
    expect(s, [540, 570, 600, 630]);
  });

  test('avoids busy times with a buffer', () {
    final s = availableStarts(
      openMin: 9 * 60,
      closeMin: 13 * 60,
      durationMin: 60,
      busy: const [
        [600, 660]
      ],
      bufferMin: 30,
    );
    // 10:00-11:00 is taken; with a 30 min buffer nothing may touch 9:30-11:30.
    expect(s, [690, 720]);
  });

  test('respects the earliest start', () {
    final s = availableStarts(openMin: 9 * 60, closeMin: 12 * 60, durationMin: 60, earliestMin: 600);
    expect(s, [600, 630, 660]);
  });

  test('rounding', () {
    expect(roundUp(601, 30), 630);
    expect(roundUp(600, 30), 600);
  });
}
