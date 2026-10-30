import 'dart:async';

import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';

enum PracticeAudioEvent { interruption, headphonesRemoved, routeChanged }

abstract interface class AudioSessionCoordinator {
  Stream<PracticeAudioEvent> get events;
  Future<void> configureCapture();
  Future<void> configurePlayback();
  Future<void> activatePlayback();
  Future<void> deactivate();
  Future<void> dispose();
}

/// Central owner of session policy; the recorder's iOS session management is off.
class DeviceAudioSessionCoordinator implements AudioSessionCoordinator {
  AudioSession? _session;
  final _events = StreamController<PracticeAudioEvent>.broadcast();
  final _subscriptions = <StreamSubscription<dynamic>>[];
  bool get _hasSession =>
      kIsWeb ||
      {
        TargetPlatform.iOS,
        TargetPlatform.android,
        TargetPlatform.macOS,
      }.contains(defaultTargetPlatform);
  @override
  Stream<PracticeAudioEvent> get events => _events.stream;
  Future<AudioSession?> _ensureSession() async {
    if (!_hasSession) return null;
    if (_session != null) return _session;
    final session = _session = await AudioSession.instance;
    _subscriptions.add(
      session.interruptionEventStream.listen((event) {
        if (event.begin) _events.add(PracticeAudioEvent.interruption);
      }),
    );
    _subscriptions.add(
      session.becomingNoisyEventStream.listen((_) {
        _events.add(PracticeAudioEvent.headphonesRemoved);
      }),
    );
    _subscriptions.add(
      session.devicesChangedEventStream.listen((event) {
        if (event.devicesRemoved.isNotEmpty || event.devicesAdded.isNotEmpty) {
          _events.add(PracticeAudioEvent.routeChanged);
        }
      }),
    );
    return session;
  }

  @override
  Future<void> configureCapture() async {
    final session = await _ensureSession();
    await session?.configure(
      AudioSessionConfiguration(
        // The tuner is the launch screen: it must also preserve other music
        // before the user opens the metronome or returns to tuning.
        avAudioSessionCategory: AVAudioSessionCategory.playAndRecord,
        avAudioSessionCategoryOptions:
            AVAudioSessionCategoryOptions.mixWithOthers |
            AVAudioSessionCategoryOptions.defaultToSpeaker,
        avAudioSessionMode: AVAudioSessionMode.defaultMode,
      ),
    );
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
      if (!await session!.setActive(true)) {
        throw StateError('Microphone audio session could not start.');
      }
    }
  }

  @override
  Future<void> configurePlayback() async {
    final session = await _ensureSession();
    await session?.configure(
      const AudioSessionConfiguration(
        avAudioSessionCategory: AVAudioSessionCategory.playback,
        // Keep the song's audio and system media controls with its own app.
        avAudioSessionCategoryOptions:
            AVAudioSessionCategoryOptions.mixWithOthers,
        androidAudioAttributes: AndroidAudioAttributes(
          contentType: AndroidAudioContentType.music,
          usage: AndroidAudioUsage.media,
        ),
        androidAudioFocusGainType:
            AndroidAudioFocusGainType.gainTransientMayDuck,
        androidWillPauseWhenDucked: true,
      ),
    );
  }

  @override
  Future<void> activatePlayback() async {
    // Android's shared-output metronome intentionally coexists with other
    // media and does not participate in Android audio focus arbitration.
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) return;
    final session = await _ensureSession();
    if (session != null && !await session.setActive(true)) {
      throw StateError(
        'Audio focus was denied. Return to the app and tap Start.',
      );
    }
  }

  @override
  Future<void> deactivate() async {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) return;
    await _session?.setActive(false);
  }

  @override
  Future<void> dispose() async {
    try {
      await deactivate();
    } finally {
      for (final subscription in _subscriptions) {
        await subscription.cancel();
      }
      await _events.close();
    }
  }
}
