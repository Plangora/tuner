import 'dart:async';

import 'package:flutter/foundation.dart';

import 'tuner_capture.dart';

import 'package:record/record.dart';

import 'pitch_detector.dart';

/// Callback type for pitch detection results
typedef PitchCallback = void Function(double frequency);

/// Manages audio recording and real-time pitch detection
class AudioService implements TunerCapture {
  AudioService({AudioRecorder? recorder}) : _audioRecorder = recorder;

  static const int sampleRate = 44100;
  static const int channelCount = 1;

  AudioRecorder? _audioRecorder;
  bool _recorderStarted = false;
  Stream<Uint8List>? _audioStream;
  StreamSubscription<Uint8List>? _audioSubscription;
  bool _isRecording = false;
  PitchCallback? _onPitchDetected;

  /// Called when the audio stream reports an error.
  void Function(Object error)? onStreamError;

  /// Initializes the audio service and requests microphone permission; session policy is app-owned
  ///
  /// Throws an exception with message "Microphone permission denied" if initialization fails.
  @override
  Future<void> initialize() async {
    final recorder = _audioRecorder ??= AudioRecorder();
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
      await recorder.ios?.manageAudioSession(false);
    }
    if (!await recorder.hasPermission()) {
      throw StateError(
        'Microphone permission denied. Enable access in Settings, then tap Retry.',
      );
    }
  }

  /// Starts audio recording with pitch detection
  ///
  /// The provided callback is called for each detected frequency.
  /// Throws an exception with message "Microphone permission denied" if permission is denied.
  @override
  Future<void> startRecording(PitchCallback onPitchDetected) async {
    _onPitchDetected = onPitchDetected;

    if (_isRecording) return;
    if (_audioRecorder == null) await initialize();
    _recorderStarted = true;
    try {
      _audioStream = await _audioRecorder!.startStream(
        RecordConfig(
          encoder: AudioEncoder.pcm16bits,
          sampleRate: sampleRate,
          numChannels: channelCount,
          audioInterruption:
              !kIsWeb && defaultTargetPlatform == TargetPlatform.android
              ? AudioInterruptionMode.none
              : AudioInterruptionMode.pause,
        ),
      );
      _isRecording = true;
    } catch (_) {
      await stopRecording();
      rethrow;
    }

    // Listen to stream, keeping the subscription so it can be cancelled.
    await _audioSubscription?.cancel();
    _audioSubscription = _audioStream?.listen(
      _processAudioBuffer,
      onError: (Object error) {
        _isRecording = false;
        onStreamError?.call(error);
      },
      onDone: () {
        if (_isRecording) {
          _isRecording = false;
          onStreamError?.call(StateError('Microphone stream ended'));
        }
      },
      cancelOnError: true,
    );
  }

  /// Processes incoming audio buffer and detects pitch
  void _processAudioBuffer(Uint8List audioData) {
    if (!_isRecording || audioData.isEmpty) {
      return;
    }

    // Convert bytes to samples
    final samples = _bytesToSamples(audioData);

    // Detect pitch if we have enough samples
    if (samples.length >= 512) {
      final frequency = PitchDetector.detectPitch(samples, sampleRate);
      _onPitchDetected?.call(frequency);
    }
  }

  /// Converts PCM16 bytes to normalized double samples
  ///
  /// Returns a List of doubles with values normalized to [-1.0, 1.0]
  List<double> _bytesToSamples(Uint8List bytes) {
    final samples = <double>[];

    for (int i = 0; i < bytes.length - 1; i += 2) {
      // Read two bytes as signed 16-bit integer (little-endian)
      final byte1 = bytes[i];
      final byte2 = bytes[i + 1];

      // Combine bytes into signed 16-bit integer
      int sample = byte1 | (byte2 << 8);

      // Convert to signed value
      if (sample > 32767) {
        sample -= 65536;
      }

      // Normalize to [-1.0, 1.0]
      samples.add(sample / 32768.0);
    }

    return samples;
  }

  /// Stops audio recording
  @override
  Future<void> stopRecording() async {
    _isRecording = false;
    await _audioSubscription?.cancel();
    _audioSubscription = null;
    if (_recorderStarted) {
      await _audioRecorder?.stop();
      _recorderStarted = false;
    }
    _audioStream = null;
  }

  /// Disposes the audio service resources
  @override
  Future<void> dispose() async {
    await stopRecording();
    await _audioSubscription?.cancel();
    _audioSubscription = null;
    await _audioRecorder?.dispose();
    _audioRecorder = null;
  }
}
