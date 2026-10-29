import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:tuner/models/metronome_settings.dart';
import 'package:tuner/models/metronome_state.dart';
import 'package:tuner/services/audio_session_coordinator.dart';
import 'package:tuner/services/metronome_engine.dart';
import 'package:tuner/services/practice_controller.dart';

import '../support/practice_fakes.dart';

void main() {
  late List<String> trace;
  late FakeEngine engine;
  late FakeCapture capture;
  late FakeSession session;
  late FakeSettingsRepository repository;
  late PracticeController controller;
  setUp(() {
    trace = [];
    engine = FakeEngine(trace);
    capture = FakeCapture(trace);
    session = FakeSession(trace);
    repository = FakeSettingsRepository();
    controller = PracticeController(
      engine: engine,
      capture: capture,
      session: session,
      repository: repository,
    );
  });
  tearDown(() async {
    await controller.shutdown();
    controller.dispose();
  });

  test(
    'entering metronome waits for microphone shutdown before playing',
    () async {
      await controller.enterTuner();
      expect(capture.active, isTrue);
      capture.stopGate = Completer<void>();
      final enter = controller.enterMetronome();
      final play = controller.start();
      await Future<void>.delayed(Duration.zero);
      expect(engine.active, isFalse);
      expect(engine.starts, 0);
      capture.stopGate!.complete();
      await Future.wait([enter, play]);
      expect(capture.active, isFalse);
      expect(engine.active, isTrue);
      expect(
        trace.indexOf('capture.stop'),
        lessThan(trace.indexOf('engine.start')),
      );
    },
  );
  test(
    'returning to tuner waits for playback stop before capture starts',
    () async {
      await controller.enterMetronome();
      await controller.start();
      engine.stopGate = Completer<void>();
      final leave = controller.enterTuner();
      await Future<void>.delayed(Duration.zero);
      expect(capture.active, isFalse);
      engine.stopGate!.complete();
      await leave;
      expect(engine.active, isFalse);
      expect(capture.active, isTrue);
      expect(controller.state.resumable, isFalse);
      await controller.playFromSystem();
      expect(engine.active, isFalse);
    },
  );
  test('double Start owns one engine voice', () async {
    await controller.enterMetronome();
    await Future.wait([controller.start(), controller.start()]);
    expect(engine.starts, 1);
    expect(controller.state.playing, isTrue);
  });
  test(
    'stop during pending engine start prevents a stale playing state',
    () async {
      await controller.enterMetronome();
      engine.startGate = Completer<void>();
      final play = controller.start();
      await Future<void>.delayed(Duration.zero);
      final stop = controller.stop();
      engine.startGate!.complete();
      await Future.wait([play, stop]);
      expect(engine.active, isFalse);
      expect(controller.state.playing, isFalse);
      expect(controller.state.resumable, isFalse);
    },
  );
  test(
    'late microphone initialization never starts capture in metronome',
    () async {
      capture.initializeGate = Completer<void>();
      final tuner = controller.enterTuner();
      await Future<void>.delayed(Duration.zero);
      final metro = controller.enterMetronome();
      capture.initializeGate!.complete();
      await Future.wait([tuner, metro]);
      expect(capture.starts, 0);
      expect(controller.state.mode, PracticeMode.metronome);
    },
  );
  test('microphone denial does not prevent metronome playback', () async {
    capture.denied = true;
    await controller.enterTuner();
    expect(controller.state.error, contains('permission denied'));
    await controller.enterMetronome();
    await controller.start();
    expect(controller.state.playing, isTrue);
    expect(controller.state.error, isNull);
  });
  test('capture shutdown failure blocks playback', () async {
    await controller.enterTuner();
    capture.failStop = true;
    await controller.enterMetronome();
    await controller.start();
    expect(engine.starts, 0);
    expect(controller.state.error, isNotNull);
    capture.failStop = false;
  });
  test('failed start produces recoverable stopped/error state', () async {
    await controller.enterMetronome();
    engine.failStart = true;
    await controller.start();
    expect(controller.state.playing, isFalse);
    expect(controller.state.error, contains('No output device'));
    engine.failStart = false;
    await controller.start();
    expect(controller.state.playing, isTrue);
  });
  test(
    'interruption pauses until explicit resume, never on event end',
    () async {
      await controller.enterMetronome();
      await controller.start();
      session.controller.add(PracticeAudioEvent.interruption);
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(engine.active, isFalse);
      expect(controller.state.playing, isFalse);
      await controller.playFromSystem();
      expect(engine.active, isTrue);
    },
  );
  test(
    'asynchronous output failure cannot leave false playing state',
    () async {
      await controller.enterMetronome();
      await controller.start();
      engine.events.add(
        const MetronomeEngineStatus(error: 'Output disappeared'),
      );
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(controller.state.playing, isFalse);
      expect(controller.state.error, contains('Output disappeared'));
    },
  );
  test(
    'late tuner interruption cannot deactivate metronome playback',
    () async {
      await controller.enterTuner();
      capture.stopGate = Completer<void>();
      final enter = controller.enterMetronome();
      final play = controller.start();
      await Future<void>.delayed(Duration.zero);
      session.controller.add(PracticeAudioEvent.routeChanged);
      await Future<void>.delayed(Duration.zero);
      capture.stopGate!.complete();
      await Future.wait([enter, play]);
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(controller.state.playing, isTrue);
      expect(controller.state.error, isNull);
      final start = trace.lastIndexOf('engine.start');
      expect(trace.skip(start + 1), isNot(contains('session.deactivate')));
    },
  );

  test('late engine errors cannot deactivate the tuner microphone', () async {
    await controller.enterTuner();
    trace.clear();
    engine.events.add(const MetronomeEngineStatus(error: 'Stale output event'));
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(capture.active, isTrue);
    expect(controller.state.error, isNull);
    expect(trace, isNot(contains('session.deactivate')));
  });

  test('metronome continues in background, tuner capture does not', () async {
    await controller.enterTuner();
    await controller.setForeground(false);
    expect(capture.active, isFalse);
    await controller.setForeground(true);
    expect(capture.active, isTrue);
    await controller.enterMetronome();
    await controller.start();
    await controller.setForeground(false);
    expect(engine.active, isTrue);
  });
  test(
    'restoring settings never starts playback and latest edits persist',
    () async {
      repository.saved = MetronomeSettings(bpm: 87, beatsPerBar: 3);
      await controller.initialize();
      expect(controller.state.settings.bpm, 87);
      expect(engine.starts, 0);
      await controller.updateSettings(MetronomeSettings(bpm: 103));
      await controller.updateSettings(MetronomeSettings(bpm: 141));
      expect(repository.saved!.bpm, 141);
    },
  );
}
