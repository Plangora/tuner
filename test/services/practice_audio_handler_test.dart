import 'package:flutter_test/flutter_test.dart';
import 'package:audio_service/audio_service.dart';
import 'package:tuner/services/practice_audio_handler.dart';
import 'package:tuner/services/practice_controller.dart';

import '../support/practice_fakes.dart';

void main() {
  late FakeEngine engine;
  late PracticeController controller;
  late PracticeAudioHandler handler;
  setUp(() {
    final trace = <String>[];
    engine = FakeEngine(trace);
    controller = PracticeController(
      engine: engine,
      capture: FakeCapture(trace),
      session: FakeSession(trace),
      repository: FakeSettingsRepository(),
    );
    handler = PracticeAudioHandler(controller);
  });
  tearDown(() async {
    handler.close();
    await controller.shutdown();
    controller.dispose();
  });
  test(
    'system pause/resume uses the same native transport as the UI',
    () async {
      await controller.enterMetronome();
      await controller.start();
      expect(handler.playbackState.value.playing, isTrue);
      expect(handler.mediaItem.value!.title, contains('120 BPM'));
      await handler.pause();
      expect(engine.active, isFalse);
      expect(handler.playbackState.value.playing, isFalse);
      expect(
        handler.playbackState.value.processingState,
        AudioProcessingState.ready,
      );
      await handler.play();
      expect(engine.active, isTrue);
      await handler.stop();
      expect(engine.active, isFalse);
      expect(handler.mediaItem.value, isNull);
      expect(
        handler.playbackState.value.processingState,
        AudioProcessingState.idle,
      );
    },
  );
  test(
    'stale system Play cannot start clicks while tuning or after Stop',
    () async {
      await controller.enterTuner();
      await handler.play();
      expect(engine.starts, 0);
      await controller.enterMetronome();
      await controller.start();
      await handler.stop();
      await handler.play();
      expect(engine.active, isFalse);
    },
  );
  test('start failure clears system playing state and seek/skip actions stay absent', () async {
    await controller.enterMetronome();
    engine.failStart = true;
    await controller.start();
    final state = handler.playbackState.value;
    expect(state.playing, isFalse);
    expect(state.errorMessage, contains('No output device'));
    expect(state.systemActions, isNot(contains(MediaAction.seek)));
    expect(
      state.controls.any((c) => c.action == MediaAction.skipToNext),
      isFalse,
    );
  });
}
