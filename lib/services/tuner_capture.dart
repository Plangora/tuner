abstract interface class TunerCapture {
  set onStreamError(void Function(Object)? callback);
  Future<void> initialize();
  Future<void> startRecording(void Function(double) onPitch);
  Future<void> stopRecording();
  Future<void> dispose();
}
