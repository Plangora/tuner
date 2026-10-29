import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/metronome_settings.dart';
import '../models/metronome_state.dart';
import 'audio_session_coordinator.dart';
import 'metronome_engine.dart';
import 'metronome_settings_repository.dart';
import 'tuner_capture.dart';

/// One app-owned transport for widgets, system controls and lifecycle events.
/// Native audio owns beat timing; this queue only serializes user commands.
class PracticeController extends ChangeNotifier {
  PracticeController({
    required this.engine,
    required this.capture,
    required this.session,
    required this.repository,
  }) {
    _engineEvents = engine.status.listen((event) {
      if (event.error != null && _desiredMode == PracticeMode.metronome) {
        unawaited(
          _enqueue(() async {
            if (_desiredMode == PracticeMode.metronome &&
                (_state.playing || _state.status == TransportStatus.starting)) {
              await _fail(event.error!);
            }
          }),
        );
      }
    });
    _sessionEvents = session.events.listen((event) {
      if (_state.mode == PracticeMode.metronome &&
          (_state.playing || _state.busy)) {
        unawaited(
          pause(
            reason: switch (event) {
              PracticeAudioEvent.interruption =>
                'Playback interrupted. Tap Start to resume.',
              PracticeAudioEvent.headphonesRemoved =>
                'Headphones disconnected. Tap Start to resume.',
              PracticeAudioEvent.routeChanged =>
                'Audio route changed. Tap Start to resume.',
            },
          ),
        );
      } else if (_state.mode == PracticeMode.tuner && _captureActive) {
        unawaited(
          _enqueue(() async {
            if (_desiredMode != PracticeMode.tuner ||
                _state.mode != PracticeMode.tuner ||
                !_captureActive) {
              return;
            }
            await capture.stopRecording();
            _captureActive = false;
            await session.deactivate();
            _publish(error: 'Microphone interrupted. Tap Retry to resume.');
          }),
        );
      }
    });
    capture.onStreamError = (error) {
      if (_closed || _desiredMode != PracticeMode.tuner) return;
      unawaited(
        _enqueue(() async {
          if (_desiredMode != PracticeMode.tuner ||
              _state.mode != PracticeMode.tuner) {
            return;
          }
          await capture.stopRecording();
          _captureActive = false;
          _publish(error: 'Microphone stopped. Tap Retry to resume. ($error)');
        }),
      );
    };
  }
  final MetronomeEngine engine;
  final TunerCapture capture;
  final AudioSessionCoordinator session;
  final MetronomeSettingsRepository repository;
  late final StreamSubscription<MetronomeEngineStatus> _engineEvents;
  late final StreamSubscription<PracticeAudioEvent> _sessionEvents;
  MetronomeState _state = MetronomeState();
  MetronomeState get state => _state;
  double _frequency = 0;
  double get frequency => _frequency;
  bool _captureActive = false;
  bool get captureActive => _captureActive;
  String? settingsWarning;
  String? metronomeUnavailableReason;
  Future<void> _pending = Future.value();
  PracticeMode _desiredMode = PracticeMode.tuner;
  bool _foreground = true;
  bool _closed = false;
  bool _loaded = false;
  int _playEpoch = 0;
  int _modeEpoch = 0;
  int _settingsEpoch = 0;

  void _publish({
    PracticeMode? mode,
    TransportStatus? status,
    MetronomeSettings? settings,
    bool? resumable,
    String? error,
    bool clearError = false,
  }) {
    if (_closed) return;
    _state = MetronomeState(
      mode: mode ?? _state.mode,
      status: status ?? _state.status,
      settings: settings ?? _state.settings,
      resumable: resumable ?? _state.resumable,
      error: clearError ? null : (error ?? _state.error),
    );
    notifyListeners();
  }

  Future<void> _enqueue(Future<void> Function() command) {
    if (_closed) return Future.value();
    _pending = _pending.then((_) async {
      if (_closed) return;
      try {
        await command();
      } catch (error) {
        await _fail(error.toString());
      }
    });
    return _pending;
  }

  Future<void> _fail(String message) async {
    _playEpoch++;
    try {
      await engine.stop();
    } catch (_) {
      /* Preserve the original failure. */
    }
    try {
      await session.deactivate();
    } catch (_) {
      /* Best-effort release. */
    }
    _publish(status: TransportStatus.stopped, resumable: false, error: message);
  }

  Future<void> initialize() => _enqueue(() async {
    if (_loaded) return;
    _loaded = true;
    try {
      _publish(settings: await repository.load());
    } catch (_) {
      settingsWarning = 'Saved settings could not be loaded. Using defaults.';
      _publish();
    }
  });

  Future<void> enterMetronome() {
    _desiredMode = PracticeMode.metronome;
    _modeEpoch++;
    _playEpoch++;
    _publish(status: TransportStatus.stopping);
    return _enqueue(() async {
      if (_desiredMode != PracticeMode.metronome) return;
      await capture.stopRecording();
      _captureActive = false;
      await session.deactivate();
      if (_desiredMode != PracticeMode.metronome) return;
      _frequency = 0;
      _publish(
        mode: PracticeMode.metronome,
        status: TransportStatus.stopped,
        resumable: false,
        clearError: true,
      );
    });
  }

  Future<void> enterTuner() {
    _desiredMode = PracticeMode.tuner;
    final epoch = ++_modeEpoch;
    _playEpoch++;
    _publish(status: TransportStatus.stopping);
    return _enqueue(() async {
      if (_desiredMode != PracticeMode.tuner) return;
      await engine.stop();
      await session.deactivate();
      if (_desiredMode != PracticeMode.tuner) return;
      _publish(
        mode: PracticeMode.tuner,
        status: TransportStatus.stopped,
        resumable: false,
        clearError: true,
      );
      await _startCapture(epoch);
    });
  }

  Future<void> _startCapture(int epoch) async {
    if (!_foreground || _captureActive || _desiredMode != PracticeMode.tuner) {
      return;
    }
    await capture.initialize();
    if (_closed ||
        epoch != _modeEpoch ||
        !_foreground ||
        _desiredMode != PracticeMode.tuner) {
      return;
    }
    await session.configureCapture();
    if (_closed ||
        epoch != _modeEpoch ||
        !_foreground ||
        _desiredMode != PracticeMode.tuner) {
      await session.deactivate();
      return;
    }
    await capture.startRecording((frequency) {
      if (!_closed &&
          _captureActive &&
          _desiredMode == PracticeMode.tuner &&
          _state.mode == PracticeMode.tuner) {
        _frequency = frequency;
        notifyListeners();
      }
    });
    _captureActive = true;
    if (_closed ||
        epoch != _modeEpoch ||
        !_foreground ||
        _desiredMode != PracticeMode.tuner) {
      await capture.stopRecording();
      _captureActive = false;
      await session.deactivate();
    } else {
      _publish(clearError: true);
    }
  }

  Future<void> start() {
    final epoch = _playEpoch;
    return _enqueue(() async {
      if (_desiredMode != PracticeMode.metronome ||
          _state.mode != PracticeMode.metronome ||
          _captureActive ||
          epoch != _playEpoch ||
          _state.playing) {
        return;
      }
      if (metronomeUnavailableReason != null) {
        throw StateError(metronomeUnavailableReason!);
      }
      if (!engine.supported) {
        throw StateError(
          'Metronome playback is supported on iOS, Android and macOS.',
        );
      }
      _publish(status: TransportStatus.starting, clearError: true);
      await engine.initialize();
      if (_closed || epoch != _playEpoch) return;
      await session.configurePlayback();
      await session.activatePlayback();
      if (_closed || epoch != _playEpoch) {
        await session.deactivate();
        return;
      }
      await engine.start(_state.settings);
      if (_closed ||
          epoch != _playEpoch ||
          _desiredMode != PracticeMode.metronome) {
        await engine.stop();
        await session.deactivate();
        return;
      }
      _publish(
        status: TransportStatus.playing,
        resumable: true,
        clearError: true,
      );
    });
  }

  Future<void> playFromSystem() =>
      _state.resumable && _desiredMode == PracticeMode.metronome
      ? start()
      : Future.value();

  Future<void> pause({String? reason}) {
    _playEpoch++;
    return _enqueue(() async {
      if (_state.mode != PracticeMode.metronome) return;
      final resumable = _state.playing || _state.busy || _state.resumable;
      await engine.stop();
      await session.deactivate();
      _publish(
        status: TransportStatus.stopped,
        resumable: resumable,
        error: reason,
        clearError: reason == null,
      );
    });
  }

  Future<void> stop() {
    _playEpoch++;
    return _enqueue(() async {
      if (_state.mode != PracticeMode.metronome) return;
      _publish(status: TransportStatus.stopping);
      await engine.stop();
      await session.deactivate();
      _publish(
        status: TransportStatus.stopped,
        resumable: false,
        clearError: true,
      );
    });
  }

  Future<void> updateSettings(MetronomeSettings settings) {
    final previous = _state.settings;
    if (settings == previous) return _pending;
    final revision = ++_settingsEpoch;
    _publish(settings: settings);
    return _enqueue(() async {
      if (revision != _settingsEpoch) return; // Coalesce rapid slider edits.
      if (_state.playing) {
        final epoch = _playEpoch;
        if (!previous.samePattern(settings)) {
          _publish(status: TransportStatus.starting);
        }
        await engine.updateSettings(settings);
        if (epoch == _playEpoch && _desiredMode == PracticeMode.metronome) {
          _publish(status: TransportStatus.playing, clearError: true);
        } else {
          await engine.stop();
        }
      }
      try {
        await repository.save(settings);
        settingsWarning = null;
      } catch (_) {
        settingsWarning =
            'Settings could not be saved. Changes apply for this session.';
      }
      _publish();
    });
  }

  Future<void> setForeground(bool foreground) {
    _foreground = foreground;
    final epoch = ++_modeEpoch;
    return _enqueue(() async {
      if (_desiredMode == PracticeMode.tuner) {
        if (!foreground) {
          await capture.stopRecording();
          _captureActive = false;
          await session.deactivate();
        } else {
          await _startCapture(epoch);
        }
      } else if (foreground && _state.playing) {
        await engine.checkHealth();
      }
    });
  }

  Future<void> shutdown() async {
    if (_closed) return;
    _publish(
      mode: PracticeMode.tuner,
      status: TransportStatus.stopped,
      resumable: false,
      clearError: true,
    );
    _closed = true;
    _playEpoch++;
    _modeEpoch++;
    capture.onStreamError = null;
    await _engineEvents.cancel();
    await _sessionEvents.cancel();
    await _pending;
    for (final cleanup in [
      engine.stop,
      capture.stopRecording,
      engine.dispose,
      capture.dispose,
      session.dispose,
    ]) {
      try {
        await cleanup();
      } catch (_) {
        /* Continue releasing the other owners. */
      }
    }
  }

  @override
  void dispose() {
    if (!_closed) unawaited(shutdown());
    super.dispose();
  }
}
