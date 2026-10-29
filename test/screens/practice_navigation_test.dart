import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tuner/main.dart';
import 'package:tuner/services/practice_controller.dart';

import '../support/practice_fakes.dart';

void main() {
  for (final denied in [false, true]) {
    testWidgets(
      'launch tuner and enter metronome with microphone denied=$denied',
      (tester) async {
        final trace = <String>[];
        final engine = FakeEngine(trace);
        final capture = FakeCapture(trace)..denied = denied;
        final controller = PracticeController(
          engine: engine,
          capture: capture,
          session: FakeSession(trace),
          repository: FakeSettingsRepository(),
        );
        await tester.pumpWidget(MyApp(controller: controller));
        await tester.pumpAndSettle();
        expect(find.text('Instrument Tuner'), findsOneWidget);
        expect(find.byTooltip('Metronome'), findsOneWidget);
        await tester.tap(find.byTooltip('Metronome'));
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('metronome-toggle')), findsOneWidget);
        await tester.ensureVisible(
          find.byKey(const ValueKey('metronome-toggle')),
        );
        await tester.tap(find.byKey(const ValueKey('metronome-toggle')));
        await tester.pump();
        expect(engine.active, isTrue);
        expect(capture.active, isFalse);
        await tester.tap(find.byTooltip('Back to tuner'));
        await tester.pumpAndSettle();
        expect(find.text('Instrument Tuner'), findsOneWidget);
        expect(engine.active, isFalse);
        expect(capture.active, !denied);
        await tester.pumpWidget(const SizedBox());
        controller.dispose();
        await tester.pump();
      },
    );
  }
}
