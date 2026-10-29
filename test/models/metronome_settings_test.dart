import 'package:flutter_test/flutter_test.dart';
import 'package:tuner/models/metronome_settings.dart';

void main() {
  test('settings survive versioned round-trip without playback state', () {
    final original = MetronomeSettings(
      bpm: 97,
      beatsPerBar: 7,
      subdivision: 3,
      volume: .23,
    );
    final json = original.toJson();
    final restored = MetronomeSettings.fromJson(json);
    expect(restored.bpm, 97);
    expect(restored.beatsPerBar, 7);
    expect(restored.subdivision, 3);
    expect(restored.volume, .23);
    expect(json.containsKey('playing'), isFalse);
  });
  test('invalid values are rejected at the model boundary', () {
    expect(() => MetronomeSettings(bpm: 0), throwsArgumentError);
    expect(() => MetronomeSettings(bpm: 241), throwsArgumentError);
    expect(() => MetronomeSettings(beatsPerBar: 13), throwsArgumentError);
    expect(() => MetronomeSettings(subdivision: 0), throwsArgumentError);
    expect(() => MetronomeSettings(volume: double.nan), throwsArgumentError);
    expect(() => MetronomeSettings(volume: 1.1), throwsArgumentError);
  });
  test('corrupt and unknown-version data fall back safely', () {
    for (final value in [
      null,
      'broken',
      {'version': 20, 'bpm': 97},
      {'version': 1, 'bpm': 'fast'},
      {'version': 1, 'bpm': -20},
    ]) {
      expect(MetronomeSettings.fromJson(value).bpm, 120);
    }
  });
}
