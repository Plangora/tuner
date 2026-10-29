import 'package:flutter_test/flutter_test.dart';
import 'package:tuner/services/tap_tempo.dart';

void main() {
  test(
    'fast edge taps clamp to the tempo limit instead of counting half-time',
    () {
      final tap = TapTempo();
      tap.tap(Duration.zero);
      expect(tap.tap(const Duration(milliseconds: 245)), 240);
      expect(tap.tap(const Duration(milliseconds: 490)), 240);
    },
  );
  test('tap uses recent intervals and resets after a long gap', () {
    final tap = TapTempo();
    expect(tap.tap(Duration.zero), isNull);
    expect(tap.tap(const Duration(milliseconds: 500)), 120);
    expect(tap.tap(const Duration(milliseconds: 1000)), 120);
    expect(tap.tap(const Duration(seconds: 5)), isNull);
    expect(tap.tap(const Duration(milliseconds: 6000)), 60);
  });
  test('accidental rapid taps do not poison the next valid interval', () {
    final tap = TapTempo();
    tap.tap(Duration.zero);
    expect(tap.tap(const Duration(milliseconds: 10)), isNull);
    expect(tap.tap(const Duration(milliseconds: 500)), 120);
  });
  test('uses only the latest five valid intervals', () {
    final tap = TapTempo();
    tap.tap(Duration.zero);
    var ms = 0;
    for (var i = 0; i < 5; i++) {
      ms += 1000;
      tap.tap(Duration(milliseconds: ms));
    }
    int? bpm;
    for (var i = 0; i < 5; i++) {
      ms += 500;
      bpm = tap.tap(Duration(milliseconds: ms));
    }
    expect(bpm, 120);
  });
}
