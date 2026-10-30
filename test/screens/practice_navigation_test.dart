import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tuner/main.dart';
import 'package:tuner/screens/tuner_screen.dart';
import 'package:tuner/services/practice_controller.dart';
import 'package:tuner/widgets/metronome_icon.dart';

import '../support/practice_fakes.dart';

void main() {
  testWidgets(
    'metronome navigation stays in the header on a small large-text screen',
    (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final trace = <String>[];
      final controller = PracticeController(
        engine: FakeEngine(trace),
        capture: FakeCapture(trace),
        session: FakeSession(trace),
        repository: FakeSettingsRepository(),
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2)),
            child: TunerScreen(controller: controller),
          ),
        ),
      );
      await tester.pump();
      final control = find.byKey(const ValueKey('open-metronome'));
      expect(control, findsOneWidget);
      final headerAction = tester.widget<OutlinedButton>(
        find.descendant(of: control, matching: find.byType(OutlinedButton)),
      );
      expect(headerAction.child, isA<MetronomeIcon>());
      expect(headerAction.style?.side?.resolve({})?.width, greaterThan(0));
      expect(find.text('0.0 Hz'), findsOneWidget);
      expect(find.text('Metronome'), findsNothing);
      expect(tester.getSize(control).height, greaterThanOrEqualTo(56));
      expect(tester.getCenter(control).dy, lessThan(90));
      expect(tester.getCenter(control).dx, greaterThan(160));
      expect(tester.getSemantics(control).label, 'Metronome');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      controller.dispose();
      await tester.pump();
    },
  );
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
        final metronome = find.byKey(const ValueKey('open-metronome'));
        expect(find.byKey(const ValueKey('open-metronome')), findsOneWidget);
        expect(tester.getSize(metronome).height, greaterThanOrEqualTo(56));
        if (!denied) {
          expect(tester.getCenter(metronome).dy, lessThan(100));
        }
        await tester.tap(metronome);
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
