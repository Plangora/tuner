import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tuner/models/note.dart';
import 'package:tuner/widgets/note_display.dart';
import 'package:tuner/widgets/tuner_gauge.dart';
import 'package:tuner/widgets/tuning_status.dart';

Widget wrap(Widget child) {
  return MaterialApp(home: Scaffold(body: child));
}

/// Canvas stand-in that records the lines a painter draws.
class RecordingCanvas implements ui.Canvas {
  final List<(Offset, Offset)> lines = [];

  @override
  void drawLine(Offset p1, Offset p2, ui.Paint paint) {
    lines.add((p1, p2));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

/// Paints the gauge and returns the needle line drawn from the gauge's pivot
/// point. The painter draws a blurred glow pass along the same geometry
/// before the crisp needle line, so this returns the last (topmost) match.
(Offset, Offset) needleFor(double centsOffset) {
  const size = Size(300, 150);
  final pivot = Offset(size.width / 2, size.height * 0.8);
  final canvas = RecordingCanvas();

  GaugePainter(centsOffset: centsOffset, isInTune: false).paint(canvas, size);

  final needles = canvas.lines.where((line) => line.$1 == pivot).toList();
  expect(needles, isNotEmpty);
  return needles.last;
}

void main() {
  group('NoteDisplay', () {
    testWidgets('shows placeholders when no note is detected', (tester) async {
      await tester.pumpWidget(
        wrap(const NoteDisplay(currentNote: null, detectedFrequency: 0)),
      );

      expect(find.text('--'), findsOneWidget);
      expect(find.text('0.0 Hz'), findsOneWidget);
    });

    testWidgets('shows the note name and detected frequency', (tester) async {
      await tester.pumpWidget(
        wrap(
          const NoteDisplay(
            currentNote: Note(name: 'A', octave: 4, frequency: 440.00),
            detectedFrequency: 441.2,
          ),
        ),
      );

      expect(find.text('A4'), findsOneWidget);
      expect(find.text('441.2 Hz'), findsOneWidget);
    });
  });

  group('TuningStatus', () {
    testWidgets('reports In Tune, Flat and Sharp', (tester) async {
      await tester.pumpWidget(
        wrap(const TuningStatus(centsOffset: 1, isInTune: true)),
      );
      expect(find.text('In Tune'), findsOneWidget);

      await tester.pumpWidget(
        wrap(const TuningStatus(centsOffset: -20, isInTune: false)),
      );
      expect(find.text('Flat'), findsOneWidget);

      await tester.pumpWidget(
        wrap(const TuningStatus(centsOffset: 20, isInTune: false)),
      );
      expect(find.text('Sharp'), findsOneWidget);
    });
  });

  group('TunerGauge', () {
    testWidgets('renders without overflowing', (tester) async {
      await tester.pumpWidget(
        wrap(const TunerGauge(centsOffset: 0, isInTune: true)),
      );

      expect(find.byType(CustomPaint), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    test('needle points straight up when in tune', () {
      final (start, end) = needleFor(0);

      expect(end.dx, closeTo(start.dx, 0.001));
      expect(end.dy, lessThan(start.dy));
    });

    test('needle leans left when flat and right when sharp', () {
      final (start, flatEnd) = needleFor(-100);
      final (_, sharpEnd) = needleFor(100);

      expect(flatEnd.dx, lessThan(start.dx));
      expect(sharpEnd.dx, greaterThan(start.dx));

      // ±100 cents are the horizontal extremes of the arc.
      expect(flatEnd.dy, closeTo(start.dy, 0.001));
      expect(sharpEnd.dy, closeTo(start.dy, 0.001));
    });

    testWidgets('repaints when the offset changes', (tester) async {
      final painter = GaugePainter(centsOffset: 0, isInTune: true);

      expect(
        painter.shouldRepaint(GaugePainter(centsOffset: 0, isInTune: true)),
        isFalse,
      );
      expect(
        painter.shouldRepaint(GaugePainter(centsOffset: 30, isInTune: false)),
        isTrue,
      );
    });
  });
}
