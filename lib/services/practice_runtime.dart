import 'package:audio_service/audio_service.dart' as background;
import 'package:flutter/foundation.dart';

import 'audio_service.dart';
import 'audio_session_coordinator.dart';
import 'metronome_settings_repository.dart';
import 'practice_audio_handler.dart';
import 'practice_controller.dart';
import 'soloud_metronome_engine.dart';

class PracticeRuntime {
  PracticeRuntime._(this.controller, this._handler);
  final PracticeController controller;
  final PracticeAudioHandler? _handler;
  static Future<PracticeRuntime> create() async {
    final nativePlayback =
        !kIsWeb &&
        {
          TargetPlatform.android,
          TargetPlatform.iOS,
          TargetPlatform.macOS,
        }.contains(defaultTargetPlatform);
    final controller = PracticeController(
      engine: SoloudMetronomeEngine(supported: nativePlayback),
      capture: AudioService(),
      session: DeviceAudioSessionCoordinator(),
      repository: PreferencesMetronomeSettingsRepository(),
    );
    PracticeAudioHandler? handler;
    if (nativePlayback) {
      final candidate = PracticeAudioHandler(controller);
      try {
        handler = await background.AudioService.init(
          builder: () => candidate,
          config: const background.AudioServiceConfig(
            androidNotificationChannelId: 'com.plangora.tuner.metronome',
            androidNotificationChannelName: 'Metronome',
            androidNotificationOngoing: true,
          ),
        );
      } catch (error) {
        candidate.close();
        debugPrint('Background audio initialization failed: $error');
        controller.metronomeUnavailableReason =
            'Background audio could not start. Restart the app to retry.';
      }
    }
    return PracticeRuntime._(controller, handler);
  }

  Future<void> dispose() async {
    await controller.shutdown();
    _handler?.close();
    controller.dispose();
  }
}
