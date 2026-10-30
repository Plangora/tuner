import 'dart:async';

import 'package:tuner/models/metronome_settings.dart';
import 'package:tuner/services/audio_session_coordinator.dart';
import 'package:tuner/services/metronome_engine.dart';
import 'package:tuner/services/metronome_settings_repository.dart';
import 'package:tuner/services/tuner_capture.dart';

class FakeEngine implements MetronomeEngine {
  FakeEngine(this.trace);
  final List<String> trace;
  final events = StreamController<MetronomeEngineStatus>.broadcast();
  Completer<void>? startGate;
  Future<void> Function()? onInitialize;
  Completer<void>? stopGate;
  bool failStart = false;
  bool failStop = false;
  bool active = false;
  int starts = 0;
  MetronomeSettings? applied;
  @override
  bool supported = true;
  @override
  Duration? get position => active ? const Duration(milliseconds: 500) : null;
  @override
  Stream<MetronomeEngineStatus> get status => events.stream;
  @override
  Future<void> initialize() async {
    trace.add('engine.initialize');
    await onInitialize?.call();
  }

  @override
  Future<void> start(MetronomeSettings settings) async {
    trace.add('engine.start');
    starts++;
    await startGate?.future;
    if (failStart) throw StateError('No output device');
    active = true;
    applied = settings;
  }

  @override
  Future<void> updateSettings(MetronomeSettings settings) async {
    applied = settings;
  }

  @override
  Future<void> stop() async {
    trace.add('engine.stop');
    await stopGate?.future;
    if (failStop) throw StateError('Cannot stop');
    active = false;
  }

  @override
  Future<void> checkHealth() async {}
  @override
  Future<void> dispose() async {
    await events.close();
  }
}

class FakeCapture implements TunerCapture {
  FakeCapture(this.trace);
  final List<String> trace;
  Completer<void>? initializeGate;
  Completer<void>? stopGate;
  bool denied = false;
  bool failStop = false;
  bool active = false;
  int starts = 0;
  void Function(double)? pitch;
  @override
  void Function(Object)? onStreamError;
  @override
  Future<void> initialize() async {
    trace.add('capture.initialize');
    await initializeGate?.future;
    if (denied) throw StateError('Microphone permission denied');
  }

  @override
  Future<void> startRecording(void Function(double) onPitch) async {
    trace.add('capture.start');
    starts++;
    active = true;
    pitch = onPitch;
  }

  @override
  Future<void> stopRecording() async {
    trace.add('capture.stop');
    await stopGate?.future;
    if (failStop) throw StateError('Microphone could not stop');
    active = false;
  }

  @override
  Future<void> dispose() async {}
}

class FakeSession implements AudioSessionCoordinator {
  FakeSession(this.trace);
  final List<String> trace;
  final controller = StreamController<PracticeAudioEvent>.broadcast();
  bool playbackConfigured = false;
  bool playbackActive = false;
  bool denyPlayback = false;
  @override
  Stream<PracticeAudioEvent> get events => controller.stream;
  @override
  Future<void> configureCapture() async {
    trace.add('session.capture');
    playbackConfigured = false;
  }

  @override
  Future<void> configurePlayback() async {
    trace.add('session.playback');
    playbackConfigured = true;
  }

  @override
  Future<void> activatePlayback() async {
    trace.add('session.activate');
    if (denyPlayback) throw StateError('Audio focus denied');
    playbackActive = playbackConfigured;
  }

  @override
  Future<void> deactivate() async {
    trace.add('session.deactivate');
    playbackActive = false;
  }

  @override
  Future<void> dispose() async {
    await controller.close();
  }
}

class FakeSettingsRepository implements MetronomeSettingsRepository {
  MetronomeSettings? saved;
  bool failSave = false;
  @override
  Future<MetronomeSettings> load() async => saved ?? MetronomeSettings();
  @override
  Future<void> save(MetronomeSettings settings) async {
    if (failSave) throw StateError('Storage unavailable');
    saved = settings;
  }
}
