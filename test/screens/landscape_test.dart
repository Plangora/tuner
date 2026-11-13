import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tuner/main.dart';
import 'package:tuner/services/practice_controller.dart';
import 'package:tuner/widgets/note_display.dart';
import 'package:tuner/widgets/tuner_gauge.dart';
import 'package:tuner/widgets/tuning_status.dart';

import '../support/practice_fakes.dart';

void main() {
  late PracticeController controller;
  late FakeCapture capture;

  Future<void> show(
    WidgetTester tester, {
    bool denied = false,
    double scale = 1,
    Size size = const Size(568, 320),
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    tester.view.padding = FakeViewPadding(left: 24, right: 24, bottom: 16);
    tester.platformDispatcher.textScaleFactorTestValue = scale;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final trace = <String>[];
    capture = FakeCapture(trace)..denied = denied;
    controller = PracticeController(
      engine: FakeEngine(trace),
      capture: capture,
      session: FakeSession(trace),
      repository: FakeSettingsRepository(),
    );
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox());
      controller.dispose();
    });
    await tester.pumpWidget(MyApp(controller: controller));
    await tester.pumpAndSettle();
  }

  void expectOnScreen(WidgetTester tester, Finder finder) {
    final bounds = tester.getRect(finder);
    expect(bounds.left, greaterThanOrEqualTo(24));
    expect(
      bounds.right,
      lessThanOrEqualTo(tester.view.physicalSize.width - 24),
    );
    expect(bounds.top, greaterThanOrEqualTo(56));
    expect(
      bounds.bottom,
      lessThanOrEqualTo(tester.view.physicalSize.height - 16),
    );
  }

  for (final size in [const Size(568, 320), const Size(844, 390)]) {
    testWidgets(
      'landscape tuner shows note, gauge and status together after rotation at $size',
      (tester) async {
        await show(tester, size: size);
        capture.pitch!(440);
        await tester.pump();
        for (final type in [NoteDisplay, TunerGauge, TuningStatus]) {
          expectOnScreen(tester, find.byType(type));
        }
        expect(find.text('A4'), findsOneWidget);
        expect(find.text('In Tune'), findsOneWidget);
        tester.view.physicalSize = const Size(320, 568);
        await tester.pumpAndSettle();
        tester.view.physicalSize = size;
        await tester.pumpAndSettle();
        expectOnScreen(tester, find.byType(TuningStatus));
        expect(find.text('A4'), findsOneWidget);
        expect(capture.active, isTrue);
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final scale in [1.0, 2.0]) {
    testWidgets(
      'landscape microphone error allows recovery at text scale $scale',
      (tester) async {
        await show(tester, denied: true, scale: scale);
        expect(tester.takeException(), isNull);
        final retry = find.widgetWithText(ElevatedButton, 'Retry');
        await tester.ensureVisible(retry);
        expectOnScreen(tester, retry);
        capture.denied = false;
        await tester.tap(retry);
        await tester.pumpAndSettle();
        expect(find.byType(NoteDisplay), findsOneWidget);
        expect(capture.active, isTrue);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'landscape metronome controls and return remain reachable at scale $scale',
      (tester) async {
        await show(tester, scale: scale);
        await tester.ensureVisible(find.byType(TuningStatus));
        expectOnScreen(tester, find.byType(TuningStatus));
        await tester.tap(find.byKey(const ValueKey('open-metronome')));
        await tester.pumpAndSettle();
        for (final key in ['tempo-increase', 'tap-tempo', 'metronome-toggle']) {
          final control = find.byKey(ValueKey(key));
          await tester.ensureVisible(control);
          await tester.tap(control);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        }
        expect(controller.state.playing, isTrue);
        tester.view.physicalSize = const Size(320, 568);
        await tester.pumpAndSettle();
        expect(controller.state.playing, isTrue);
        await tester.tap(find.byTooltip('Back to tuner'));
        await tester.pumpAndSettle();
        expect(controller.state.playing, isFalse);
        expect(capture.active, isTrue);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
