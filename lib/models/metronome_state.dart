import 'metronome_settings.dart';

enum PracticeMode { tuner, metronome }

enum TransportStatus { stopped, starting, playing, stopping }

class MetronomeState {
  MetronomeState({
    this.mode = PracticeMode.tuner,
    this.status = TransportStatus.stopped,
    MetronomeSettings? settings,
    this.resumable = false,
    this.error,
  }) : settings = settings ?? MetronomeSettings();
  final PracticeMode mode;
  final TransportStatus status;
  final MetronomeSettings settings;
  final bool resumable;
  final String? error;
  bool get playing => status == TransportStatus.playing;
  bool get busy =>
      status == TransportStatus.starting || status == TransportStatus.stopping;
}
