class TapTempo {
  Duration? _last;
  final _intervals = <int>[];
  int? tap(Duration time) {
    final previous = _last;
    if (previous == null ||
        time <= previous ||
        time - previous > const Duration(seconds: 3)) {
      _last = time;
      _intervals.clear();
      return null;
    }
    final interval = (time - previous).inMicroseconds;
    // Ignore accidental double taps, but tolerate small overshoots at 240 BPM.
    if (interval < 150000) return null;
    _last = time;
    if (interval > 1500000) {
      _intervals.clear();
      return null;
    }
    _intervals.add(interval);
    if (_intervals.length > 5) _intervals.removeAt(0);
    final average = _intervals.reduce((a, b) => a + b) / _intervals.length;
    return (60000000 / average).round().clamp(40, 240);
  }
}
