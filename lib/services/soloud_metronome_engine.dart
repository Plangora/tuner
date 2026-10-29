import 'dart:async';

import 'package:flutter_soloud/flutter_soloud.dart';

import '../models/metronome_settings.dart';
import 'metronome_engine.dart';
import 'metronome_rhythm.dart';

/// The repeating PCM buffer is the only beat scheduler.
class SoloudMetronomeEngine implements MetronomeEngine {
  SoloudMetronomeEngine({required this.supported});
  @override
  final bool supported;
  SoLoud get _audio => SoLoud.instance;
  bool _initialized = false;
  AudioSource? _source;
  SoundHandle? _voice;
  MetronomeSettings? _settings;
  StreamSubscription<AudioDeviceStartFailure>? _deviceErrors;
  StreamSubscription<StreamSoundEvent>? _sourceEvents;
  final _events = StreamController<MetronomeEngineStatus>.broadcast();
  @override
  Stream<MetronomeEngineStatus> get status => _events.stream;
  @override
  Duration? get position {
    final voice = _voice;
    if (!_initialized || voice == null) return null;
    try {
      return _audio.getPosition(voice);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> initialize() async {
    if (!supported) {
      throw UnsupportedError(
        'Metronome playback is unavailable on this platform.',
      );
    }
    if (_initialized) return;
    await _audio.init(sampleRate: MetronomeRhythm.sampleRate);
    _initialized = true;
    _deviceErrors = _audio.audioDeviceStartFailures.listen((_) {
      _events.add(
        const MetronomeEngineStatus(
          error: 'Audio output is unavailable. Check the audio route and tap Start.',
        ),
      );
    });
  }

  @override
  Future<void> start(MetronomeSettings settings) async {
    await initialize();
    await stop();
    if (_source == null ||
        _settings == null ||
        !_settings!.samePattern(settings)) {
      await _sourceEvents?.cancel();
      final old = _source;
      _source = null;
      if (old != null) await _audio.disposeSource(old);
      _source = await _audio.loadMem(
        'metronome-${settings.hashCode}.wav',
        MetronomeRhythm(settings).wav(),
      );
      _sourceEvents = _source!.soundEvents.listen((event) {
        if (event.handle == _voice &&
            event.event == SoundEventType.handleIsNoMoreValid) {
          _events.add(
            const MetronomeEngineStatus(
              error: 'Playback stopped unexpectedly. Tap Start to retry.',
            ),
          );
        }
      });
    }
    _voice = _audio.play(_source!, volume: settings.volume, looping: true);
    _audio.setInaudibleBehavior(_voice!, true, false);
    if (!_audio.getIsValidVoiceHandle(_voice!)) {
      throw StateError('Audio could not create a playback voice.');
    }
    await _audio.startAudioDevice();
    _settings = settings;
  }

  @override
  Future<void> updateSettings(MetronomeSettings settings) async {
    final voice = _voice;
    if (voice == null) return;
    if (_settings?.samePattern(settings) == true) {
      _audio.setVolume(voice, settings.volume);
      _settings = settings;
    } else {
      // Disclosed MVP behavior: tempo/pattern edits restart on beat one.
      await start(settings);
    }
  }

  @override
  Future<void> stop() async {
    final voice = _voice;
    _voice = null; // Late native end events from our Stop are not failures.
    if (!_initialized) return;
    if (voice != null) await _audio.stop(voice);
    await _audio.stopAudioDevice();
  }

  @override
  Future<void> checkHealth() async {
    final voice = _voice;
    if (voice != null &&
        (!_audio.getIsValidVoiceHandle(voice) ||
            _audio.getAudioDeviceState() != AudioDeviceState.started)) {
      throw StateError(
        'Audio output stopped. Check the audio route and tap Start.',
      );
    }
  }

  @override
  Future<void> dispose() async {
    await stop();
    await _deviceErrors?.cancel();
    await _sourceEvents?.cancel();
    if (_source != null) await _audio.disposeSource(_source!);
    _source = null;
    if (_initialized) await _audio.deinitAsync();
    _initialized = false;
    await _events.close();
  }
}
