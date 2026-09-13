/// Pitch detection using FFT and autocorrelation-based frequency analysis
class PitchDetector {
  /// Detects pitch frequency from audio samples using FFT and autocorrelation
  ///
  /// Returns the detected frequency in Hz, or 0 if detection failed.
  static double detectPitch(List<double> audioSamples, int sampleRate) {
    // Return 0 if samples is empty or too short
    if (audioSamples.isEmpty || audioSamples.length < 512) {
      return 0;
    }

    // Compute power spectrum
    final spectrum = _computePowerSpectrum(audioSamples);

    // Find peak bin (index with highest magnitude)
    int peakBin = 0;
    double maxMagnitude = 0;
    for (int i = 0; i < spectrum.length; i++) {
      if (spectrum[i] > maxMagnitude) {
        maxMagnitude = spectrum[i];
        peakBin = i;
      }
    }

    // Convert bin to frequency
    const int window = 2048;
    double frequency = (peakBin * sampleRate) / window.toDouble();

    // Filter: return 0 if frequency < 80 Hz (below low E string)
    if (frequency < 80) {
      return 0;
    }

    return frequency;
  }

  /// Computes power spectrum using Hann window and autocorrelation
  static List<double> _computePowerSpectrum(List<double> signal) {
    // Apply Hann window to first 2048 samples
    const int windowSize = 2048;
    final windowed = <double>[];

    for (int i = 0; i < windowSize && i < signal.length; i++) {
      // Hann window: 0.5 * (1 - cos(2*pi*i/(N-1)))
      final window = 0.5 * (1 - (_cos(2 * _pi * i / (windowSize - 1))));
      windowed.add(signal[i] * window);
    }

    // Pad with zeros to 2048 samples
    while (windowed.length < windowSize) {
      windowed.add(0.0);
    }

    // Call autocorrelation method
    return _autocorrelationPitch(windowed);
  }

  /// Computes autocorrelation for pitch detection
  static List<double> _autocorrelationPitch(List<double> signal) {
    const int minLag = 20;
    const int maxLag = 2048;

    final autocorr = <double>[];

    // Compute autocorrelation for each lag
    for (int lag = minLag; lag < maxLag && lag < signal.length; lag++) {
      double sum = 0;
      for (int i = 0; i < signal.length - lag; i++) {
        sum += signal[i] * signal[i + lag];
      }
      autocorr.add(sum);
    }

    // Normalize by the maximum value
    if (autocorr.isNotEmpty) {
      double maxValue = 0;
      for (final value in autocorr) {
        if (value > maxValue) {
          maxValue = value;
        }
      }

      if (maxValue > 0) {
        for (int i = 0; i < autocorr.length; i++) {
          autocorr[i] = autocorr[i] / maxValue;
        }
      }
    }

    return autocorr;
  }

  /// Converts autocorrelation result to frequency
  ///
  /// Finds first significant peak above threshold 0.1 and converts lag to frequency.
  static double frequencyFromAutocorrelation(
      List<double> autocorr, int sampleRate) {

    const double threshold = 0.1;
    const int minLag = 20;

    // Find first significant peak above threshold
    for (int i = 0; i < autocorr.length; i++) {
      if (autocorr[i] > threshold) {
        // Convert lag to frequency
        final frequency = sampleRate / (i + minLag).toDouble();
        return frequency;
      }
    }

    // No peak found
    return 0;
  }

  // Helper functions for mathematical operations
  static const double _pi = 3.141592653589793;

  static double _cos(double x) {
    // Simple cosine approximation using Taylor series
    // cos(x) = 1 - x²/2! + x⁴/4! - x⁶/6! + ...
    x = _normalizeAngle(x);
    double result = 1.0;
    double term = 1.0;
    for (int i = 1; i <= 10; i++) {
      term *= -x * x / ((2 * i - 1) * (2 * i));
      result += term;
    }
    return result;
  }

  static double _normalizeAngle(double x) {
    // Normalize angle to [-pi, pi]
    while (x > _pi) {
      x -= 2 * _pi;
    }
    while (x < -_pi) {
      x += 2 * _pi;
    }
    return x;
  }
}
