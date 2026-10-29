import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tuner/screens/metronome_screen.dart';
import 'package:tuner/services/practice_controller.dart';
import 'package:tuner/theme/app_theme.dart';

import '../support/practice_fakes.dart';

void main() {
  late PracticeController controller;
  late FakeEngine engine;
  void screenTest(String name, Future<void> Function(WidgetTester) body) {
    testWidgets(name, (tester) async {
      try {
        await body(tester);
      } finally {
        controller.dispose();
        await tester.pumpWidget(const SizedBox());
        await tester.pump();
      }
    });
  }

  Future<void> show(
    WidgetTester tester, {
    double scale = 1,
    bool supported = true,
    TargetPlatform? platform,
  }) async {
    final trace = <String>[];
    engine = FakeEngine(trace)..supported = supported;
    controller = PracticeController(
      engine: engine,
      capture: FakeCapture(trace),
      session: FakeSession(trace),
      repository: FakeSettingsRepository(),
    );
    await controller.enterMetronome();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark.copyWith(platform: platform),
        home: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(scale)),
          child: MetronomeScreen(controller: controller),
        ),
      ),
    );
    await tester.pump();
  }

  screenTest('tempo and transport controls update the shared state', (
    tester,
  ) async {
    await show(tester);
    expect(find.byKey(const ValueKey('tempo-increase')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('tempo-increase')));
    await tester.pump();
    expect(controller.state.settings.bpm, 121);
    await tester.ensureVisible(find.byKey(const ValueKey('metronome-toggle')));
    await tester.tap(find.byKey(const ValueKey('metronome-toggle')));
    await tester.pump();
    expect(engine.active, isTrue);
    await tester.tap(find.byKey(const ValueKey('metronome-toggle')));
    await tester.pump();
    expect(engine.active, isFalse);
    await tester.pumpWidget(const SizedBox());
  });
  screenTest('small display and large text remain usable without overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await show(tester, scale: 2);
    expect(find.byKey(const ValueKey('tap-tempo')), findsOneWidget);
    await tester.ensureVisible(find.byKey(const ValueKey('metronome-toggle')));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  screenTest('Start and Stop both have a generous touch target', (
    tester,
  ) async {
    await show(tester, platform: TargetPlatform.macOS);
    final toggle = find.byKey(const ValueKey('metronome-toggle'));
    await tester.ensureVisible(toggle);
    expect(tester.getSize(toggle).height, greaterThanOrEqualTo(64));
    await tester.tap(toggle);
    await tester.pump();
    expect(engine.active, isTrue);
    expect(tester.getSize(toggle).height, greaterThanOrEqualTo(64));
  });

  screenTest('unsupported playback is explained and cannot start an engine', (
    tester,
  ) async {
    await show(tester, supported: false);
    expect(find.textContaining('iOS, Android and macOS'), findsOneWidget);
    expect(engine.starts, 0);
    await tester.pumpWidget(const SizedBox());
  });
}
