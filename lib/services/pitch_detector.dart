import 'dart:math' as math;

/// Pitch detection using normalized autocorrelation.
///
/// The detector correlates a block of samples with delayed copies of itself.
/// The lag (in samples) that produces the strongest correlation is the period
/// of the signal, so the fundamental frequency is `sampleRate / lag`.
class PitchDetector {
  /// Maximum number of samples analysed per detection call.
  static const int windowSize = 2048;

  /// Lowest frequency the detector will report (Hz).
  ///
  /// Slightly below E2 (82.41 Hz), the lowest standard guitar string, so a
  /// very flat low E can still be detected.
  static const double minFrequency = 70.0;

  /// Highest frequency the detector will report (Hz).
  static const double maxFrequency = 1200.0;

  /// Minimum RMS amplitude required before a block is analysed.
  ///
  /// Blocks quieter than this are treated as silence.
  static const double silenceThreshold = 0.005;

  /// Minimum normalized correlation required to accept a pitch estimate.
  ///
  /// Noise produces correlations far below this value.
  static const double clarityThreshold = 0.4;

  /// Detects the fundamental frequency of [audioSamples] recorded at
  /// [sampleRate] Hz.
  ///
  /// Samples are expected to be normalized to the range [-1.0, 1.0].
  /// Returns the detected frequency in Hz, or 0 if no reliable pitch was found
  /// (too few samples, silence, noise, or a pitch outside
  /// [minFrequency]–[maxFrequency]).
  static double detectPitch(List<double> audioSamples, int sampleRate) {
    if (sampleRate <= 0 || audioSamples.length < 512) {
      return 0;
    }

    final samples = _prepare(audioSamples);
    if (samples == null) {
      return 0;
    }

    final n = samples.length;
    final minLag = math.max(2, (sampleRate / maxFrequency).floor());
    final maxLag = math.min(n ~/ 2, (sampleRate / minFrequency).ceil());
    if (maxLag <= minLag + 1) {
      return 0;
    }

    final correlation = _normalizedAutocorrelation(samples, minLag, maxLag);

    // Strongest correlation in the searched lag range.
    var bestLag = -1;
    var bestValue = 0.0;
    for (var lag = minLag; lag <= maxLag; lag++) {
      if (correlation[lag] > bestValue) {
        bestValue = correlation[lag];
        bestLag = lag;
      }
    }

    if (bestLag < 0 || bestValue < clarityThreshold) {
      return 0;
    }

    // Multiples of the true period correlate almost as strongly as the period
    // itself, so prefer the earliest peak that is nearly as strong as the best
    // one. This avoids reporting a note an octave (or more) too low.
    final peakThreshold = bestValue * 0.9;
    for (var lag = minLag + 1; lag < maxLag; lag++) {
      if (correlation[lag] >= peakThreshold &&
          correlation[lag] >= correlation[lag - 1] &&
          correlation[lag] >= correlation[lag + 1]) {
        bestLag = lag;
        break;
      }
    }

    final period = _interpolatePeak(correlation, bestLag, minLag, maxLag);
    if (period <= 0) {
      return 0;
    }

    final frequency = sampleRate / period;
    if (frequency < minFrequency || frequency > maxFrequency) {
      return 0;
    }

    return frequency;
  }

  /// Copies up to [windowSize] samples, removes the DC offset, and rejects
  /// blocks that are effectively silent.
  ///
  /// Returns null when the block is too quiet to analyse.
  static List<double>? _prepare(List<double> audioSamples) {
    final n = math.min(audioSamples.length, windowSize);

    var mean = 0.0;
    for (var i = 0; i < n; i++) {
      mean += audioSamples[i];
    }
    mean /= n;

    final samples = List<double>.filled(n, 0);
    var energy = 0.0;
    for (var i = 0; i < n; i++) {
      final value = audioSamples[i] - mean;
      samples[i] = value;
      energy += value * value;
    }

    if (math.sqrt(energy / n) < silenceThreshold) {
      return null;
    }

    return samples;
  }

  /// Computes the normalized autocorrelation of [samples] for every lag in
  /// [minLag]..[maxLag].
  ///
  /// Each value is divided by the energy of the two overlapping segments, so a
  /// perfectly periodic signal scores ~1.0 at its period regardless of lag.
  /// Lags outside the requested range are left at 0.
  static List<double> _normalizedAutocorrelation(
    List<double> samples,
    int minLag,
    int maxLag,
  ) {
    final n = samples.length;

    // Prefix sums of squares so segment energies are O(1) per lag.
    final energyPrefix = List<double>.filled(n + 1, 0);
    for (var i = 0; i < n; i++) {
      energyPrefix[i + 1] = energyPrefix[i] + samples[i] * samples[i];
    }

    final correlation = List<double>.filled(maxLag + 2, 0);
    for (var lag = minLag; lag <= maxLag; lag++) {
      var sum = 0.0;
      for (var i = 0; i < n - lag; i++) {
        sum += samples[i] * samples[i + lag];
      }

      final leadingEnergy = energyPrefix[n - lag];
      final trailingEnergy = energyPrefix[n] - energyPrefix[lag];
      final denominator = math.sqrt(leadingEnergy * trailingEnergy);
      correlation[lag] = denominator > 0 ? sum / denominator : 0;
    }

    return correlation;
  }

  /// Refines an integer peak [lag] to sub-sample accuracy by fitting a parabola
  /// through the peak and its two neighbours.
  static double _interpolatePeak(
    List<double> correlation,
    int lag,
    int minLag,
    int maxLag,
  ) {
    if (lag <= minLag || lag >= maxLag) {
      return lag.toDouble();
    }

    final previous = correlation[lag - 1];
    final peak = correlation[lag];
    final next = correlation[lag + 1];

    final denominator = previous - 2 * peak + next;
    if (denominator == 0) {
      return lag.toDouble();
    }

    final delta = 0.5 * (previous - next) / denominator;
    if (delta.abs() > 1) {
      return lag.toDouble();
    }

    return lag + delta;
  }
}
