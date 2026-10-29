import 'package:audio_service/audio_service.dart';

import '../models/metronome_state.dart';
import 'practice_controller.dart';

class PracticeAudioHandler extends BaseAudioHandler {
  PracticeAudioHandler(this.controller) {
    controller.addListener(_publish);
    _publish();
  }
  final PracticeController controller;
  void _publish() {
    final state = controller.state;
    final active =
        state.mode == PracticeMode.metronome &&
        (state.playing || state.resumable || state.busy);
    mediaItem.add(
      active
          ? MediaItem(
              id: 'plangora-metronome',
              title: 'Metronome — ${state.settings.bpm} BPM',
              artist: 'Plangora Tuner',
              isLive: true,
            )
          : null,
    );
    playbackState.add(
      PlaybackState(
        controls: active
            ? [
                state.playing ? MediaControl.pause : MediaControl.play,
                MediaControl.stop,
              ]
            : [],
        androidCompactActionIndices: active ? const [0] : const [],
        systemActions: const {},
        playing: state.playing,
        processingState:
            state.error != null && state.mode == PracticeMode.metronome
            ? AudioProcessingState.error
            : (state.busy
                  ? AudioProcessingState.buffering
                  : (active
                        ? AudioProcessingState.ready
                        : AudioProcessingState.idle)),
        errorCode: state.error == null ? null : 1,
        errorMessage: state.error,
      ),
    );
  }

  @override
  Future<void> play() => controller.playFromSystem();
  @override
  Future<void> pause() => controller.pause();
  @override
  Future<void> stop() => controller.stop();
  void close() {
    controller.removeListener(_publish);
  }
}
