import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tuner/services/audio_session_coordinator.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('iPhone capture and playback mix without ducking other audio', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    final configurations = <Map<Object?, Object?>>[];
    const channel = MethodChannel('com.ryanheise.audio_session');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'setConfiguration') {
        configurations.add(
          Map<Object?, Object?>.from((call.arguments as List).single as Map),
        );
      }
      return null;
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
    final session = DeviceAudioSessionCoordinator();
    addTearDown(session.dispose);
    await session.configureCapture();
    await session.configurePlayback();
    expect(configurations, hasLength(2));
    expect(
      configurations.first['avAudioSessionCategory'],
      AVAudioSessionCategory.playAndRecord.rawValue,
    );
    expect(
      configurations.last['avAudioSessionCategory'],
      AVAudioSessionCategory.playback.rawValue,
    );
    for (final configuration in configurations) {
      final options = configuration['avAudioSessionCategoryOptions'] as int;
      expect(
        options & AVAudioSessionCategoryOptions.mixWithOthers.value,
        isNonZero,
      );
      expect(options & AVAudioSessionCategoryOptions.duckOthers.value, 0);
    }
    expect(
      (configurations.first['avAudioSessionCategoryOptions'] as int) &
          AVAudioSessionCategoryOptions.defaultToSpeaker.value,
      isNonZero,
    );
  });
}
