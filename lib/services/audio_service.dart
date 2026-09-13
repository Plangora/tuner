import 'dart:async';
import 'dart:typed_data';

import 'package:audio_session/audio_session.dart';
import 'package:record/record.dart';

import 'pitch_detector.dart';

/// Callback type for pitch detection results
typedef PitchCallback = void Function(double frequency);

/// Manages audio recording and real-time pitch detection
class AudioService {
  static const int sampleRate = 44100;
  static const int channelCount = 1;

  late AudioRecorder _audioRecorder;
  Stream<Uint8List>? _audioStream;
  StreamSubscription<Uint8List>? _audioSubscription;
  bool _isRecording = false;
  PitchCallback? _onPitchDetected;

  /// Called when the audio stream reports an error.
  void Function(Object error)? onStreamError;

  /// Initializes the audio service with proper audio session configuration
  ///
  /// Throws an exception with message "Microphone permission denied" if initialization fails.
  Future<void> initialize() async {
    _audioRecorder = AudioRecorder();

    try {
      final session = await AudioSession.instance;
      await session.configure(
        AudioSessionConfiguration(
          avAudioSessionCategory: AVAudioSessionCategory.record,
          avAudioSessionCategoryOptions:
              AVAudioSessionCategoryOptions.duckOthers,
          avAudioSessionMode: AVAudioSessionMode.defaultMode,
          avAudioSessionRouteSharingPolicy:
              AVAudioSessionRouteSharingPolicy.defaultPolicy,
        ),
      );
    } catch (e) {
      throw Exception('Microphone permission denied');
    }
  }

  /// Starts audio recording with pitch detection
  ///
  /// The provided callback is called for each detected frequency.
  /// Throws an exception with message "Microphone permission denied" if permission is denied.
  Future<void> startRecording(PitchCallback onPitchDetected) async {
    _onPitchDetected = onPitchDetected;

    // Check permission
    final isPermitted = await _audioRecorder.hasPermission();
    if (!isPermitted) {
      throw Exception('Microphone permission denied');
    }

    _isRecording = true;

    // Start recording stream
    _audioStream = await _audioRecorder.startStream(
      const RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: sampleRate,
        numChannels: channelCount,
      ),
    );

    // Listen to stream, keeping the subscription so it can be cancelled.
    await _audioSubscription?.cancel();
    _audioSubscription = _audioStream?.listen(
      _processAudioBuffer,
      onError: (Object error) {
        _isRecording = false;
        onStreamError?.call(error);
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
  Future<void> stopRecording() async {
    _isRecording = false;
    await _audioSubscription?.cancel();
    _audioSubscription = null;
    await _audioRecorder.stop();
    _audioStream = null;
  }

  /// Disposes the audio service resources
  Future<void> dispose() async {
    if (_isRecording) {
      await stopRecording();
    }
    await _audioSubscription?.cancel();
    _audioSubscription = null;
    await _audioRecorder.dispose();
  }
}
