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
    final accent = data.getInt16(44, Endian.little).abs();
    final subdivision = data.getInt16(44 + 11025 * 2, Endian.little).abs();
    final beat = data.getInt16(44 + 22050 * 2, Endian.little).abs();
    expect(accent, greaterThan(beat));
    expect(beat, greaterThan(subdivision));
    expect(data.getInt16(44 + 88200 * 2, Endian.little).abs(), accent);
    expect(data.getInt16(wav.length - 2, Endian.little), 0);
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
