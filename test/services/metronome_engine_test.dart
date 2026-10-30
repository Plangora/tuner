import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:tuner/models/metronome_settings.dart';
import 'package:tuner/services/metronome_rhythm.dart';

void main() {
  test('PCM loop has accented bars and evenly spaced subdivisions', () {
    final rhythm = MetronomeRhythm(MetronomeSettings(subdivision: 2));
    // Four seconds / two bars at 120 BPM. Sixteen pulses, 11025 frames apart.
    expect(rhythm.frames, 176400);
    expect(rhythm.onsets, [for (var i = 0; i < 16; i++) i * 11025]);
    final wav = rhythm.wav();
    final data = ByteData.sublistView(wav);
    expect(wav.length, 44 + 176400 * 2);
    expect(data.getUint32(40, Endian.little), 352800);
    int peakAt(int frame) => [
      for (var i = 0; i < 1323; i++)
        data.getInt16(44 + (frame + i) * 2, Endian.little).abs(),
    ].reduce((a, b) => a > b ? a : b);
    final accent = peakAt(0);
    final subdivision = peakAt(11025);
    final beat = peakAt(22050);
    expect(accent, greaterThan(beat));
    expect(beat, greaterThan(subdivision));
    expect(peakAt(88200), accent);
    expect(data.getInt16(wav.length - 2, Endian.little), 0);
  });
  test('woodblock A keeps all beats identical when accent is disabled', () {
    final settings = MetronomeSettings(
      bpm: 120,
      beatsPerBar: 3,
      subdivision: 2,
      accentFirstBeat: false,
    );
    final rhythm = MetronomeRhythm(settings);
    final data = ByteData.sublistView(rhythm.wav());
    final beatFrames = MetronomeRhythm.sampleRate * 60 ~/ settings.bpm;
    final samplesPerClick = 1323;
    List<int> clickAt(int onset) => [
      for (var frame = 0; frame < samplesPerClick; frame++)
        data.getInt16(44 + (onset + frame) * 2, Endian.little),
    ];
    final first = clickAt(rhythm.onsets[0]);
    expect(clickAt(beatFrames), first);
    expect(clickAt(beatFrames * 2), first);
  });
  test('woodblock A gives the first beat a stronger sound when enabled', () {
    final rhythm = MetronomeRhythm(
      MetronomeSettings(bpm: 120, beatsPerBar: 3, subdivision: 2),
    );
    final wav = rhythm.wav();
    final data = ByteData.sublistView(wav);
    final first = [
      for (var i = 0; i < 1323; i++) data.getInt16(44 + i * 2, Endian.little),
    ];
    final secondOnset = rhythm.onsets[2];
    final second = [
      for (var i = 0; i < 1323; i++)
        data.getInt16(44 + (secondOnset + i) * 2, Endian.little),
    ];
    expect(first, isNot(second));
    expect(
      first.map((v) => v.abs()).reduce((a, b) => a > b ? a : b),
      greaterThan(second.map((v) => v.abs()).reduce((a, b) => a > b ? a : b)),
    );
    expect(wav, isNotEmpty);
  });
  test('woodblock PCM keeps full-scale headroom at maximum app volume', () {
    for (final accentFirstBeat in [true, false]) {
      final rhythm = MetronomeRhythm(
        MetronomeSettings(
          bpm: 240,
          beatsPerBar: 1,
          subdivision: 4,
          volume: 1,
          accentFirstBeat: accentFirstBeat,
        ),
      );
      final data = ByteData.sublistView(rhythm.wav());
      var peak = 0;
      for (var frame = 0; frame < rhythm.frames; frame++) {
        final sample = data.getInt16(44 + frame * 2, Endian.little).abs();
        if (sample > peak) peak = sample;
      }
      expect(peak, lessThanOrEqualTo(24000));
      expect(peak, lessThan(32768));
    }
  });
  test(
    'absolute frame rounding controls fractional tempo and loop-seam error',
    () {
      final rhythm = MetronomeRhythm(
        MetronomeSettings(bpm: 137, beatsPerBar: 1, subdivision: 3),
      );
      expect(rhythm.frames, greaterThanOrEqualTo(176400));
      for (var i = 0; i < rhythm.onsets.length; i++) {
        final ideal = i * 44100 * 60 / (137 * 3);
        expect((rhythm.onsets[i] - ideal).abs(), lessThanOrEqualTo(.5));
      }
      final idealLength = rhythm.onsets.length * 44100 * 60 / (137 * 3);
      expect((rhythm.frames - idealLength).abs(), lessThanOrEqualTo(.5));
      // No burst, omitted pulse, or extra padding at the loop seam.
      final seam = rhythm.frames - rhythm.onsets.last;
      expect((seam - 44100 * 60 / (137 * 3)).abs(), lessThanOrEqualTo(1));
    },
  );
  test(
    'slow large patterns stay bounded and fastest clicks fit between pulses',
    () {
      final slow = MetronomeRhythm(
        MetronomeSettings(bpm: 40, beatsPerBar: 12, subdivision: 4),
      );
      expect(slow.frames, 793800);
      expect(slow.wav().length, 44 + 793800 * 2);
      final fast = MetronomeRhythm(
        MetronomeSettings(bpm: 240, beatsPerBar: 1, subdivision: 4),
      );
      expect(fast.onsets[1] - fast.onsets[0], greaterThan(882));
    },
  );
}
