import 'package:flutter_test/flutter_test.dart';
import 'package:tuner/models/note.dart';

void main() {
  group('Note', () {
    const a4 = Note(name: 'A', octave: 4, frequency: 440.00);

    test('formats as name plus octave', () {
      expect(a4.toString(), 'A4');
      expect(const Note(name: 'C♯', octave: 3, frequency: 138.59).toString(),
          'C♯3');
    });

    test('reports 0 cents at the target frequency', () {
      expect(a4.getCentsOffset(440), closeTo(0, 0.001));
    });

    test('reports 1200 cents for an octave up and -1200 for an octave down',
        () {
      expect(a4.getCentsOffset(880), closeTo(1200, 0.001));
      expect(a4.getCentsOffset(220), closeTo(-1200, 0.001));
    });

    test('reports 0 cents for non-positive frequencies', () {
      expect(a4.getCentsOffset(0), 0);
      expect(a4.getCentsOffset(-100), 0);
    });

    test('is in tune only within ±5 cents', () {
      expect(a4.isInTune(440), isTrue);
      expect(a4.isInTune(440 * 1.0028), isTrue); // ~+4.8 cents
      expect(a4.isInTune(440 * 1.006), isFalse); // ~+10 cents
      expect(a4.isInTune(440 * 0.994), isFalse); // ~-10 cents
    });
  });

  group('NoteTable', () {
    test('covers the full range from E2 to B4', () {
      expect(NoteTable.notes.first.toString(), 'E2');
      expect(NoteTable.notes.first.frequency, 82.41);
      expect(NoteTable.notes.last.toString(), 'B4');
    });

    test('contains every standard guitar string', () {
      const strings = <String, double>{
        'E2': 82.41,
        'A2': 110.00,
        'D3': 146.83,
        'G3': 196.00,
        'B3': 246.94,
        'E4': 329.63,
      };

      strings.forEach((name, frequency) {
        final match = NoteTable.notes.firstWhere(
          (note) => note.toString() == name,
          orElse: () => throw StateError('$name missing from the note table'),
        );
        expect(match.frequency, frequency);
      });
    });

    test('is chromatic and strictly ascending with no gaps', () {
      for (var i = 1; i < NoteTable.notes.length; i++) {
        final ratio =
            NoteTable.notes[i].frequency / NoteTable.notes[i - 1].frequency;
        // One semitone in equal temperament.
        expect(ratio, closeTo(1.059463, 0.001));
      }
    });

    test('finds the closest note', () {
      expect(NoteTable.findClosestNote(82.41).toString(), 'E2');
      expect(NoteTable.findClosestNote(110.5).toString(), 'A2');
      expect(NoteTable.findClosestNote(441).toString(), 'A4');
      expect(NoteTable.findClosestNote(116.0).toString(), 'A♯2');
    });

    test('returns null for non-positive frequencies', () {
      expect(NoteTable.findClosestNote(0), isNull);
      expect(NoteTable.findClosestNote(-5), isNull);
    });
  });
}
