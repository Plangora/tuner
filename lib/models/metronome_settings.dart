/// Validated, immutable practice preferences. Playback state is never persisted.
class MetronomeSettings {
  MetronomeSettings({
    this.bpm = 120,
    this.beatsPerBar = 4,
    this.subdivision = 1,
    this.volume = 0.5,
    this.accentFirstBeat = true,
  }) {
    if (bpm < 40 || bpm > 240) throw ArgumentError.value(bpm, 'bpm');
    if (beatsPerBar < 1 || beatsPerBar > 12) {
      throw ArgumentError.value(beatsPerBar, 'beatsPerBar');
    }
    if (subdivision < 1 || subdivision > 4) {
      throw ArgumentError.value(subdivision, 'subdivision');
    }
    if (!volume.isFinite || volume < 0 || volume > 1) {
      throw ArgumentError.value(volume, 'volume');
    }
  }
  final int bpm;
  final int beatsPerBar;
  final int subdivision;
  final double volume;
  final bool accentFirstBeat;
  MetronomeSettings copyWith({
    int? bpm,
    int? beatsPerBar,
    int? subdivision,
    double? volume,
    bool? accentFirstBeat,
  }) => MetronomeSettings(
    bpm: bpm ?? this.bpm,
    beatsPerBar: beatsPerBar ?? this.beatsPerBar,
    subdivision: subdivision ?? this.subdivision,
    volume: volume ?? this.volume,
    accentFirstBeat: accentFirstBeat ?? this.accentFirstBeat,
  );
  bool samePattern(MetronomeSettings other) =>
      bpm == other.bpm &&
      beatsPerBar == other.beatsPerBar &&
      subdivision == other.subdivision &&
      accentFirstBeat == other.accentFirstBeat;
  Map<String, Object> toJson() => {
    'version': 1,
    'bpm': bpm,
    'beatsPerBar': beatsPerBar,
    'subdivision': subdivision,
    'volume': volume,
    'accentFirstBeat': accentFirstBeat,
  };
  static MetronomeSettings fromJson(Object? value) {
    if (value is Map &&
        value['version'] == 1 &&
        value['bpm'] is int &&
        value['beatsPerBar'] is int &&
        value['subdivision'] is int &&
        value['volume'] is num &&
        (value['accentFirstBeat'] == null ||
            value['accentFirstBeat'] is bool)) {
      try {
        return MetronomeSettings(
          bpm: value['bpm'] as int,
          beatsPerBar: value['beatsPerBar'] as int,
          subdivision: value['subdivision'] as int,
          volume: (value['volume'] as num).toDouble(),
          accentFirstBeat: (value['accentFirstBeat'] as bool?) ?? true,
        );
      } on ArgumentError {
        /* Invalid saved values fall back as a unit. */
      }
    }
    return MetronomeSettings();
  }

  @override
  bool operator ==(Object other) =>
      other is MetronomeSettings &&
      samePattern(other) &&
      volume == other.volume &&
      accentFirstBeat == other.accentFirstBeat;
  @override
  int get hashCode =>
      Object.hash(bpm, beatsPerBar, subdivision, volume, accentFirstBeat);
}
