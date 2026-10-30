import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tuner/models/metronome_settings.dart';
import 'package:tuner/services/metronome_settings_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test(
    'saved settings survive a new repository instance without playing state',
    () async {
      final repo = PreferencesMetronomeSettingsRepository();
      await repo.save(
        MetronomeSettings(
          bpm: 153,
          beatsPerBar: 5,
          subdivision: 4,
          volume: .75,
        ),
      );
      final restored = await PreferencesMetronomeSettingsRepository().load();
      expect(restored.bpm, 153);
      expect(restored.beatsPerBar, 5);
      expect(restored.subdivision, 4);
      expect(restored.volume, .75);
      expect(restored.accentFirstBeat, isTrue);
      final prefs = await SharedPreferences.getInstance();
      final saved = jsonDecode(
        prefs.getString(PreferencesMetronomeSettingsRepository.key)!,
      );
      expect(saved.containsKey('playing'), isFalse);
    },
  );
  test('persisted accent choice survives a new repository instance', () async {
    await PreferencesMetronomeSettingsRepository().save(
      MetronomeSettings(accentFirstBeat: false),
    );
    expect(
      (await PreferencesMetronomeSettingsRepository().load()).accentFirstBeat,
      isFalse,
    );
  });
  test(
    'missing, corrupt, wrong-type and invalid data fall back safely',
    () async {
      final repo = PreferencesMetronomeSettingsRepository();
      expect((await repo.load()).bpm, 120);
      for (final value in ['bad JSON', 123, '{"version":1,"bpm":9000}']) {
        SharedPreferences.setMockInitialValues({
          PreferencesMetronomeSettingsRepository.key: value,
        });
        expect((await repo.load()).bpm, 120);
      }
    },
  );
}
