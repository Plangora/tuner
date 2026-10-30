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

  static final _woodblockAccent = _woodblock(1950, 24000);
  static final _woodblockBeat = _woodblock(1550, 14000);
  static final _woodblockSubdivision = _woodblock(1550, 8000);

  static List<int> _woodblock(double frequency, int amplitude) {
    const clickFrames = 1323; // 30 ms, below the shortest supported pulse.
    final samples = <int>[];
    for (var i = 0; i < clickFrames; i++) {
      final seconds = i / sampleRate;
      final attack = 1 - math.exp(-seconds / .00015);
      final end = ((.030 - seconds) / .003).clamp(0.0, 1.0);
      final body =
          .72 *
              math.sin(2 * math.pi * frequency * seconds) *
              math.exp(-math.max(0, seconds - .004) / .008) +
          .29 *
              math.sin(2 * math.pi * frequency * 1.72 * seconds) *
              math.exp(-math.max(0, seconds - .002) / .006) +
          .16 *
              math.sin(2 * math.pi * frequency * 2.61 * seconds) *
              math.exp(-seconds / .002);
      // Each timbre is peak-normalized so the stored peak controls its gain.
      samples.add((attack * end * body * 32767).round());
    }
    final peak = samples.map((v) => v.abs()).reduce(math.max);
    return [for (final sample in samples) (sample * amplitude / peak).round()];
  }

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
      final beat = pulse % settings.subdivision == 0;
      final firstBeat =
          pulse % (settings.beatsPerBar * settings.subdivision) == 0;
      final click = !beat
          ? _woodblockSubdivision
          : (settings.accentFirstBeat && firstBeat
                ? _woodblockAccent
                : _woodblockBeat);
      for (var i = 0; i < click.length; i++) {
        data.setInt16(44 + (positions[pulse] + i) * 2, click[i], Endian.little);
      }
    }
    return bytes;
  }
}
