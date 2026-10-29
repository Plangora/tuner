import 'dart:async';

import 'package:flutter/material.dart';

import '../models/metronome_state.dart';
import '../services/practice_controller.dart';
import '../services/tap_tempo.dart';
import '../theme/app_theme.dart';

class MetronomeScreen extends StatefulWidget {
  const MetronomeScreen({super.key, required this.controller});
  final PracticeController controller;
  @override
  State<MetronomeScreen> createState() => _MetronomeScreenState();
}

class _MetronomeScreenState extends State<MetronomeScreen>
    with WidgetsBindingObserver {
  final _tapTempo = TapTempo();
  final _tapClock = Stopwatch()..start();
  Timer? _visualTimer;
  int? _beat;
  bool _visible = true;
  bool _leaving = false;
  bool _allowPop = false;
  String? _tapHint;
  PracticeController get _controller => widget.controller;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller.addListener(_changed);
    _syncVisualTimer();
  }

  void _changed() {
    if (!mounted) return;
    _syncVisualTimer();
    setState(() {});
  }

  void _syncVisualTimer() {
    if (!_visible || !_controller.state.playing) {
      _visualTimer?.cancel();
      _visualTimer = null;
      _beat = null;
    } else {
      _visualTimer ??= Timer.periodic(
        const Duration(milliseconds: 40),
        (_) => _readVisualPhase(),
      );
      _readVisualPhase();
    }
  }

  void _readVisualPhase() {
    final position = _controller.engine.position;
    if (!mounted || position == null) return;
    final settings = _controller.state.settings;
    final beat =
        (position.inMicroseconds * settings.bpm / 60000000).floor() %
        settings.beatsPerBar;
    if (beat != _beat) setState(() => _beat = beat);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _visible = state == AppLifecycleState.resumed;
    _syncVisualTimer(); // Presentation only; never stops the transport.
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.removeListener(_changed);
    _visualTimer?.cancel();
    _tapClock.stop();
    super.dispose();
  }

  Future<void> _leave() async {
    if (_leaving) return;
    setState(() => _leaving = true);
    await _controller.enterTuner();
    if (!mounted) return;
    if (_controller.state.mode != PracticeMode.tuner) {
      setState(() => _leaving = false);
      return;
    }
    setState(() => _allowPop = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.of(context).pop();
    });
  }

  void _tempo(int bpm) {
    if (mounted) setState(() => _tapHint = null);
    unawaited(
      _controller.updateSettings(
        _controller.state.settings.copyWith(bpm: bpm.clamp(40, 240)),
      ),
    );
  }

  Future<void> _toggle() async {
    if (_controller.state.busy || _leaving || !_controller.engine.supported) {
      return;
    }
    if (_controller.state.playing) {
      await _controller.stop();
    } else {
      if (_controller.state.mode != PracticeMode.metronome ||
          _controller.state.error != null) {
        await _controller.enterMetronome();
      }
      await _controller.start();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = _controller.state;
    final settings = state.settings;
    final text = Theme.of(context).textTheme;
    final supported =
        _controller.engine.supported &&
        _controller.metronomeUnavailableReason == null;
    final message =
        _controller.metronomeUnavailableReason ??
        (!supported
            ? 'Metronome playback is available on iOS, Android and macOS.'
            : state.error);
    return PopScope(
      canPop: _allowPop,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(_leave());
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Metronome'),
          leading: IconButton(
            tooltip: 'Back to tuner',
            onPressed: _leaving ? null : _leave,
            icon: const Icon(Icons.arrow_back),
          ),
        ),
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final stacked =
                  constraints.maxWidth < 420 ||
                  MediaQuery.textScalerOf(context).scale(16) > 21;
              return SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 560),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Semantics(
                          label: _beat == null
                              ? 'Beat indicator stopped'
                              : 'Beat ${_beat! + 1} of ${settings.beatsPerBar}',
                          child: ExcludeSemantics(
                            child: Wrap(
                              alignment: WrapAlignment.center,
                              spacing: 8,
                              runSpacing: 8,
                              children: List.generate(settings.beatsPerBar, (
                                index,
                              ) {
                                final active = state.playing && index == _beat;
                                final color = index == 0
                                    ? AppColors.magenta
                                    : AppColors.cyan;
                                return Container(
                                  width: 40,
                                  height: 40,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: active ? color : AppColors.surface,
                                    border: Border.all(
                                      color: active
                                          ? color
                                          : AppColors.trackInactive,
                                      width: active ? 2 : 1,
                                    ),
                                  ),
                                  child: FittedBox(
                                    child: Text(
                                      (index + 1).toString(),
                                      style: text.titleMedium?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: active
                                            ? AppColors.background
                                            : Colors.white70,
                                      ),
                                    ),
                                  ),
                                );
                              }),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        Row(
                          children: [
                            IconButton.outlined(
                              key: const ValueKey('tempo-decrease'),
                              tooltip: 'Decrease tempo',
                              style: IconButton.styleFrom(
                                foregroundColor: AppColors.cyan,
                                side: const BorderSide(
                                  color: AppColors.cyan,
                                  width: 1.5,
                                ),
                              ),
                              onPressed: _leaving || settings.bpm == 40
                                  ? null
                                  : () => _tempo(settings.bpm - 1),
                              icon: const Icon(Icons.remove),
                              constraints: const BoxConstraints(
                                minWidth: 48,
                                minHeight: 48,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Semantics(
                                label: '${settings.bpm} beats per minute',
                                excludeSemantics: true,
                                child: Column(
                                  children: [
                                    FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Text(
                                        settings.bpm.toString(),
                                        style: text.displayLarge?.copyWith(
                                          fontSize: 96,
                                          height: 1.1,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.cyan,
                                          fontFeatures: const [
                                            FontFeature.tabularFigures(),
                                          ],
                                          shadows: AppTheme.glow(
                                            AppColors.cyan,
                                            blurRadius: 20,
                                          ),
                                        ),
                                      ),
                                    ),
                                    Text(
                                      'BPM',
                                      style: text.titleLarge?.copyWith(
                                        color: AppColors.purple,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            IconButton.outlined(
                              key: const ValueKey('tempo-increase'),
                              tooltip: 'Increase tempo',
                              style: IconButton.styleFrom(
                                foregroundColor: AppColors.cyan,
                                side: const BorderSide(
                                  color: AppColors.cyan,
                                  width: 1.5,
                                ),
                              ),
                              onPressed: _leaving || settings.bpm == 240
                                  ? null
                                  : () => _tempo(settings.bpm + 1),
                              icon: const Icon(Icons.add),
                              constraints: const BoxConstraints(
                                minWidth: 48,
                                minHeight: 48,
                              ),
                            ),
                          ],
                        ),
                        Slider(
                          key: const ValueKey('tempo-slider'),
                          value: settings.bpm.toDouble(),
                          min: 40,
                          max: 240,
                          divisions: 200,
                          label: '${settings.bpm} BPM',
                          semanticFormatterCallback: (value) =>
                              '${value.round()} beats per minute',
                          inactiveColor: AppColors.trackInactive,
                          onChanged: _leaving
                              ? null
                              : (value) => _tempo(value.round()),
                        ),
                        Center(
                          child: ElevatedButton.icon(
                            key: const ValueKey('tap-tempo'),
                            onPressed: _leaving
                                ? null
                                : () {
                                    final bpm = _tapTempo.tap(
                                      _tapClock.elapsed,
                                    );
                                    if (bpm != null) _tempo(bpm);
                                    setState(
                                      () => _tapHint = bpm == null
                                          ? 'Tap again to set tempo'
                                          : 'Tempo set to $bpm BPM',
                                    );
                                  },
                            icon: const Icon(Icons.touch_app_outlined),
                            label: const Text('Tap tempo'),
                          ),
                        ),
                        if (_tapHint != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              _tapHint!,
                              textAlign: TextAlign.center,
                              style: text.bodySmall?.copyWith(
                                color: Colors.white70,
                              ),
                            ),
                          ),
                        const SizedBox(height: 28),
                        Flex(
                          direction: stacked ? Axis.vertical : Axis.horizontal,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (stacked)
                              _beatsSelector()
                            else
                              Expanded(child: _beatsSelector()),
                            SizedBox(
                              width: stacked ? 0 : 16,
                              height: stacked ? 16 : 0,
                            ),
                            if (stacked)
                              _subdivisionSelector()
                            else
                              Expanded(child: _subdivisionSelector()),
                          ],
                        ),
                        const SizedBox(height: 24),
                        Wrap(
                          alignment: WrapAlignment.spaceBetween,
                          runSpacing: 8,
                          children: [
                            Text('Volume', style: text.titleMedium),
                            Text(
                              settings.volume == 0
                                  ? 'Muted'
                                  : '${(settings.volume * 100).round()}%',
                              style: text.titleMedium?.copyWith(
                                color: AppColors.purple,
                              ),
                            ),
                          ],
                        ),
                        Slider(
                          key: const ValueKey('volume-slider'),
                          value: settings.volume,
                          divisions: 20,
                          label: '${(settings.volume * 100).round()}%',
                          inactiveColor: AppColors.trackInactive,
                          semanticFormatterCallback: (value) =>
                              '${(value * 100).round()} percent',
                          onChanged: _leaving
                              ? null
                              : (value) => unawaited(
                                  _controller.updateSettings(
                                    settings.copyWith(volume: value),
                                  ),
                                ),
                        ),
                        const SizedBox(height: 16),
                        if (message != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: Semantics(
                              liveRegion: true,
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(
                                    Icons.error_outline,
                                    color: AppColors.error,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      message,
                                      style: text.bodyMedium,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ElevatedButton.icon(
                          key: const ValueKey('metronome-toggle'),
                          style: ElevatedButton.styleFrom(
                            visualDensity: VisualDensity.standard,
                            minimumSize: const Size.fromHeight(64),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 18,
                            ),
                            textStyle: text.titleLarge?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                            iconSize: 28,
                          ),
                          onPressed: state.busy || _leaving || !supported
                              ? null
                              : _toggle,
                          icon: Icon(
                            state.playing ? Icons.stop : Icons.play_arrow,
                          ),
                          label: Text(
                            _leaving
                                ? 'Returning to tuner…'
                                : (state.busy
                                      ? 'Please wait…'
                                      : (state.playing
                                            ? 'Stop'
                                            : (state.error == null
                                                  ? 'Start'
                                                  : 'Retry'))),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          state.playing
                              ? 'Playing · keeps going when the phone is locked.'
                              : (state.resumable
                                    ? 'Paused · ready to resume.'
                                    : 'Ready when you are.'),
                          textAlign: TextAlign.center,
                          style: text.bodyMedium?.copyWith(
                            color: Colors.white70,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Tempo and pattern changes restart the bar.',
                          textAlign: TextAlign.center,
                          style: text.bodySmall?.copyWith(
                            color: Colors.white70,
                          ),
                        ),
                        if (_controller.settingsWarning != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: Text(
                              _controller.settingsWarning!,
                              style: text.bodySmall,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _beatsSelector() => _PatternSelector(
    label: 'Beats per bar',
    value: _controller.state.settings.beatsPerBar,
    values: const [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12],
    onChanged: _leaving
        ? null
        : (value) => unawaited(
            _controller.updateSettings(
              _controller.state.settings.copyWith(beatsPerBar: value),
            ),
          ),
  );
  Widget _subdivisionSelector() => _PatternSelector(
    label: 'Pulses per beat',
    value: _controller.state.settings.subdivision,
    values: const [1, 2, 3, 4],
    onChanged: _leaving
        ? null
        : (value) => unawaited(
            _controller.updateSettings(
              _controller.state.settings.copyWith(subdivision: value),
            ),
          ),
  );
}

class _PatternSelector extends StatelessWidget {
  const _PatternSelector({
    required this.label,
    required this.value,
    required this.values,
    required this.onChanged,
  });
  final String label;
  final int value;
  final List<int> values;
  final ValueChanged<int>? onChanged;
  @override
  Widget build(BuildContext context) => InputDecorator(
    decoration: InputDecoration(
      labelText: label,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      filled: true,
      fillColor: AppColors.surface,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.purple),
      ),
    ),
    child: DropdownButtonHideUnderline(
      child: DropdownButton<int>(
        value: value,
        isExpanded: true,
        isDense: false,
        dropdownColor: AppColors.surface,
        items: [
          for (final item in values)
            DropdownMenuItem(value: item, child: Text(item.toString())),
        ],
        onChanged: onChanged == null
            ? null
            : (value) {
                if (value != null) onChanged!(value);
              },
      ),
    ),
  );
}
