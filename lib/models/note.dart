import 'dart:math';

/// Represents a musical note with frequency and tuning information.
class Note {
  /// The name of the note (e.g., "C", "C♯", "D").
  final String name;

  /// The octave number.
  final int octave;

  /// The frequency of the note in Hz.
  final double frequency;

  const Note({
    required this.name,
    required this.octave,
    required this.frequency,
  });

  /// Returns the cents offset from the target frequency.
  /// Positive values indicate sharp (above target), negative values indicate flat (below target).
  /// Formula: 1200 * log(detectedFreq / frequency) / ln(2)
  double getCentsOffset(double detectedFreq) {
    if (detectedFreq <= 0 || frequency <= 0) return 0.0;
    return 1200 * log(detectedFreq / frequency) / ln2;
  }

  /// Returns true if the detected frequency is within ±5 cents of the target frequency.
  bool isInTune(double detectedFreq) {
    final offset = getCentsOffset(detectedFreq);
    return offset.abs() <= 5.0;
  }

  /// Returns a formatted string representation of the note (e.g., "C4", "C♯3").
  @override
  String toString() => '$name$octave';
}

/// Static class containing predefined notes in equal temperament tuning (A4 = 440 Hz).
class NoteTable {
  static const List<Note> notes = [
    Note(name: 'C', octave: 3, frequency: 130.81),
    Note(name: 'C♯', octave: 3, frequency: 138.59),
    Note(name: 'D', octave: 3, frequency: 146.83),
    Note(name: 'D♯', octave: 3, frequency: 155.56),
    Note(name: 'E', octave: 3, frequency: 164.81),
    Note(name: 'F', octave: 3, frequency: 174.61),
    Note(name: 'F♯', octave: 3, frequency: 185.00),
    Note(name: 'G', octave: 3, frequency: 196.00),
    Note(name: 'G♯', octave: 3, frequency: 207.65),
    Note(name: 'A', octave: 3, frequency: 220.00),
    Note(name: 'A♯', octave: 3, frequency: 233.08),
    Note(name: 'B', octave: 3, frequency: 246.94),
    Note(name: 'C', octave: 4, frequency: 261.63),
    Note(name: 'C♯', octave: 4, frequency: 277.18),
    Note(name: 'D', octave: 4, frequency: 293.66),
    Note(name: 'D♯', octave: 4, frequency: 311.13),
    Note(name: 'E', octave: 4, frequency: 329.63),
    Note(name: 'F', octave: 4, frequency: 349.23),
    Note(name: 'F♯', octave: 4, frequency: 369.99),
    Note(name: 'G', octave: 4, frequency: 392.00),
    Note(name: 'G♯', octave: 4, frequency: 415.30),
    Note(name: 'A', octave: 4, frequency: 440.00),
    Note(name: 'A♯', octave: 4, frequency: 466.16),
    Note(name: 'B', octave: 4, frequency: 493.88),
  ];

  /// Finds the closest note to the given frequency.
  /// Returns null if frequency <= 0 or the notes list is empty.
  static Note? findClosestNote(double frequency) {
    if (frequency <= 0 || notes.isEmpty) return null;

    Note closestNote = notes[0];
    double minDifference = (notes[0].frequency - frequency).abs();

    for (final note in notes) {
      final difference = (note.frequency - frequency).abs();
      if (difference < minDifference) {
        minDifference = difference;
        closestNote = note;
      }
    }

    return closestNote;
  }
}
