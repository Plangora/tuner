import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:tuner/services/pitch_detector.dart';

/// Builds [length] samples of a sine wave at [frequency] Hz.
List<double> sineWave(
  double frequency,
  int sampleRate, {
  int length = 2048,
  double amplitude = 0.8,
}) {
  return List<double>.generate(
    length,
    (i) => amplitude * math.sin(2 * math.pi * frequency * i / sampleRate),
  );
}

/// Builds a sine wave with added harmonics, closer to a real plucked string.
List<double> harmonicWave(
  double frequency,
  int sampleRate, {
  int length = 2048,
}) {
  return List<double>.generate(length, (i) {
    final t = i / sampleRate;
    return 0.6 * math.sin(2 * math.pi * frequency * t) +
        0.3 * math.sin(2 * math.pi * 2 * frequency * t) +
        0.15 * math.sin(2 * math.pi * 3 * frequency * t);
  });
}

void main() {
  const sampleRate = 44100;

  group('PitchDetector.detectPitch', () {
    test('detects a 440 Hz sine wave within 5%', () {
      final detected =
          PitchDetector.detectPitch(sineWave(440, sampleRate), sampleRate);

      expect(detected, closeTo(440, 440 * 0.05));
    });

    test('detects the standard guitar strings within 2%', () {
      const strings = <String, double>{
        'E2': 82.41,
        'A2': 110.00,
        'D3': 146.83,
        'G3': 196.00,
        'B3': 246.94,
        'E4': 329.63,
      };

      strings.forEach((name, frequency) {
        final detected =
            PitchDetector.detectPitch(sineWave(frequency, sampleRate), sampleRate);

        expect(
          detected,
          closeTo(frequency, frequency * 0.02),
          reason: '$name ($frequency Hz) was detected as $detected Hz',
        );
      });
    });

    test('detects the fundamental of a harmonic-rich tone', () {
      final detected =
          PitchDetector.detectPitch(harmonicWave(146.83, sampleRate), sampleRate);

      expect(detected, closeTo(146.83, 146.83 * 0.02));
    });

    test('returns 0 for silence', () {
      final silence = List<double>.filled(2048, 0);

      expect(PitchDetector.detectPitch(silence, sampleRate), 0);
    });

    test('returns 0 for random noise', () {
      final random = math.Random(42);
      final noise =
          List<double>.generate(2048, (_) => random.nextDouble() * 2 - 1);

      expect(PitchDetector.detectPitch(noise, sampleRate), 0);
    });

    test('returns 0 when there are too few samples', () {
      expect(PitchDetector.detectPitch(const [], sampleRate), 0);
      expect(
        PitchDetector.detectPitch(sineWave(440, sampleRate, length: 256), sampleRate),
        0,
      );
    });

    test('returns 0 for a pitch below the guitar range', () {
      final detected =
          PitchDetector.detectPitch(sineWave(40, sampleRate), sampleRate);

      expect(detected, 0);
    });

    test('returns 0 for a non-positive sample rate', () {
      expect(PitchDetector.detectPitch(sineWave(440, sampleRate), 0), 0);
    });
  });
}
