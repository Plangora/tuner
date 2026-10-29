import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:marionette_flutter/marionette_flutter.dart';

import 'screens/tuner_screen.dart';
import 'theme/app_theme.dart';
import 'services/practice_controller.dart';
import 'services/practice_runtime.dart';

Future<void> main() async {
  if (kDebugMode) {
    MarionetteBinding.ensureInitialized();
  } else {
    WidgetsFlutterBinding.ensureInitialized();
  }
  LicenseRegistry.addLicense(() async* {
    final text = await rootBundle.loadString(
      'assets/licenses/metronome-audio.txt',
    );
    yield LicenseEntryWithLineBreaks([
      'flutter_soloud native audio components',
    ], text);
  });
  final runtime = await PracticeRuntime.create();
  if (kDebugMode) {
    registerMarionetteExtension(
      name: 'practice.status',
      description: 'Read transport, microphone ownership and native visual phase for device diagnostics.',
      callback: (_) async {
        final controller = runtime.controller;
        final state = controller.state;
        return MarionetteExtensionResult.success({
          'mode': state.mode.name,
          'transport': state.status.name,
          'captureActive': controller.captureActive,
          'bpm': state.settings.bpm,
          'beatsPerBar': state.settings.beatsPerBar,
          'subdivision': state.settings.subdivision,
          'volume': state.settings.volume,
          'resumable': state.resumable,
          'positionUs': controller.engine.position?.inMicroseconds,
          'error': state.error,
        });
      },
    );
  }
  runApp(MyApp(controller: runtime.controller, onDispose: runtime.dispose));
}

class MyApp extends StatefulWidget {
  const MyApp({super.key, required this.controller, this.onDispose});
  final PracticeController controller;
  final Future<void> Function()? onDispose;
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(widget.controller.initialize());
    unawaited(widget.controller.enterTuner());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.resumed) {
      unawaited(
        widget.controller.setForeground(state == AppLifecycleState.resumed),
      );
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    final dispose = widget.onDispose;
    if (dispose != null) unawaited(dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tuner',
      theme: AppTheme.dark,
      home: TunerScreen(controller: widget.controller),
      debugShowCheckedModeBanner: false,
    );
  }
}
