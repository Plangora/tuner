import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tuner/services/practice_runtime.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('iPhone runtime does not initialize a system media session', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    final mediaCalls = <String>[];
    const channel = MethodChannel('com.ryanheise.audio_service.client.methods');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(channel, (call) async {
      mediaCalls.add(call.method);
      throw StateError('iPhone metronome must not claim system media controls');
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
    final runtime = await PracticeRuntime.create();
    addTearDown(runtime.dispose);
    expect(runtime.controller.metronomeUnavailableReason, isNull);
    expect(mediaCalls, isEmpty);
    expect(runtime.controller.engine.supported, isTrue);
  });
}
