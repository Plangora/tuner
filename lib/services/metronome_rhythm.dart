import 'dart:typed_data';
import 'dart:math' as math;

import '../models/metronome_settings.dart';

class MetronomeRhythm {
  MetronomeRhythm(this.settings);
  final MetronomeSettings settings;
  static const sampleRate = 44100;
  // At least four seconds limits the repeating buffer's rounding bias to
  // <= 0.5 sample per four seconds. Pulse positions round absolute time.
  int get bars =>
      math.max(1, (4 * settings.bpm / (60 * settings.beatsPerBar)).ceil());
  int get pulseCount => bars * settings.beatsPerBar * settings.subdivision;
  int get frames =>
      (sampleRate * 60 * bars * settings.beatsPerBar / settings.bpm).round();
  List<int> get onsets => [
    for (var i = 0; i < pulseCount; i++)
      (i * sampleRate * 60 / (settings.bpm * settings.subdivision)).round(),
  ];
  Uint8List wav() {
    final bytes = Uint8List(44 + frames * 2);
    final data = ByteData.sublistView(bytes);
    void label(int at, String value) =>
        bytes.setRange(at, at + value.length, value.codeUnits);
    label(0, 'RIFF');
    data.setUint32(4, bytes.length - 8, Endian.little);
    label(8, 'WAVE');
    label(12, 'fmt ');
    data.setUint32(16, 16, Endian.little);
    data.setUint16(20, 1, Endian.little);
    data.setUint16(22, 1, Endian.little);
    data.setUint32(24, sampleRate, Endian.little);
    data.setUint32(28, sampleRate * 2, Endian.little);
    data.setUint16(32, 2, Endian.little);
    data.setUint16(34, 16, Endian.little);
    label(36, 'data');
    data.setUint32(40, frames * 2, Endian.little);
    final positions = onsets;
    for (var pulse = 0; pulse < pulseCount; pulse++) {
      final accent = pulse % (settings.beatsPerBar * settings.subdivision) == 0;
      final beat = pulse % settings.subdivision == 0;
      final amplitude = accent ? 24000 : (beat ? 14000 : 8000);
      final frequency = accent ? 1800 : (beat ? 1200 : 900);
      const clickFrames = 882; // 20ms, shorter than the fastest subdivision.
      for (var i = 0; i < clickFrames; i++) {
        final envelope = math.exp(-7 * i / clickFrames) * (1 - i / clickFrames);
        final sample =
            (amplitude *
                    envelope *
                    math.cos(2 * math.pi * frequency * i / sampleRate))
                .round();
        data.setInt16(44 + (positions[pulse] + i) * 2, sample, Endian.little);
      }
    }
    return bytes;
  }
}
