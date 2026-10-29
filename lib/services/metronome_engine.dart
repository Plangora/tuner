import '../models/metronome_settings.dart';

class MetronomeEngineStatus {
  const MetronomeEngineStatus({this.error});
  final String? error;
}

abstract interface class MetronomeEngine {
  bool get supported;
  Stream<MetronomeEngineStatus> get status;
  Duration? get position;
  Future<void> initialize();
  Future<void> start(MetronomeSettings settings);
  Future<void> updateSettings(MetronomeSettings settings);
  Future<void> stop();
  Future<void> checkHealth();
  Future<void> dispose();
}
