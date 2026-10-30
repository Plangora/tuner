import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:record/record.dart';
import 'package:tuner/services/audio_service.dart';

class CapturingRecorder implements AudioRecorder {
  RecordConfig? configuration;
  @override
  Future<Stream<Uint8List>> startStream(RecordConfig config) async {
    configuration = config;
    return const Stream.empty();
  }

  @override
  Future<String?> stop() async => null;
  @override
  Future<void> dispose() async {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    test(
      'actual $platform recorder stream uses the intended interruption policy',
      () async {
        debugDefaultTargetPlatformOverride = platform;
        addTearDown(() => debugDefaultTargetPlatformOverride = null);
        final recorder = CapturingRecorder();
        final service = AudioService(recorder: recorder);
        addTearDown(service.dispose);
        await service.startRecording((_) {});
        expect(recorder.configuration, isNotNull);
        expect(recorder.configuration!.encoder, AudioEncoder.pcm16bits);
        expect(recorder.configuration!.sampleRate, AudioService.sampleRate);
        expect(
          recorder.configuration!.audioInterruption,
          platform == TargetPlatform.android
              ? AudioInterruptionMode.none
              : AudioInterruptionMode.pause,
        );
      },
    );
  }
}
