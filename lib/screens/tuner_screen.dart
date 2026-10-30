import 'dart:async';

import 'package:flutter/material.dart';
import 'package:tuner/models/note.dart';
import 'package:tuner/services/practice_controller.dart';
import 'package:tuner/models/metronome_state.dart';
import 'package:tuner/theme/app_theme.dart';
import 'package:tuner/widgets/note_display.dart';
import 'package:tuner/widgets/tuner_gauge.dart';
import 'package:tuner/widgets/tuning_status.dart';
import 'package:tuner/widgets/metronome_icon.dart';

import 'metronome_screen.dart';

/// Main tuner screen widget that manages audio recording and real-time pitch display.
class TunerScreen extends StatefulWidget {
  const TunerScreen({super.key, required this.controller});
  final PracticeController controller;

  @override
  State<TunerScreen> createState() => _TunerScreenState();
}

/// State management for TunerScreen handling audio integration and UI updates.
class _TunerScreenState extends State<TunerScreen> {
  double _currentFrequency = 0;
  Note? _currentNote;
  double _centsOffset = 0;
  bool _isInTune = false;
  bool _openingMetronome = false;

  Future<void> _openMetronome() async {
    if (_openingMetronome) return;
    _openingMetronome = true;
    unawaited(widget.controller.enterMetronome());
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => MetronomeScreen(controller: widget.controller),
      ),
    );
    _openingMetronome = false;
  }

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_controllerChanged);
  }

  void _controllerChanged() {
    if (!mounted) return;
    final frequency = widget.controller.frequency;
    if (frequency > 0 && widget.controller.state.mode == PracticeMode.tuner) {
      _onPitchDetected(frequency);
    } else {
      setState(() {
        _currentFrequency = 0;
        _currentNote = null;
        _centsOffset = 0;
        _isInTune = false;
      });
    }
  }

  /// Callback when pitch is detected
  void _onPitchDetected(double frequency) {
    if (frequency <= 0) {
      return;
    }

    final note = NoteTable.findClosestNote(frequency);
    if (note == null) {
      return;
    }

    final centsOffset = note.getCentsOffset(frequency);
    final isInTune = note.isInTune(frequency);

    setState(() {
      _currentFrequency = frequency;
      _currentNote = note;
      _centsOffset = centsOffset;
      _isInTune = isInTune;
    });
  }

  @override
  void dispose() {
    widget.controller.removeListener(_controllerChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textScale = MediaQuery.textScalerOf(context).scale(14);
    final compactHeader =
        MediaQuery.sizeOf(context).width < 380 || textScale > 17;
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: textScale > 22 ? 72 : kToolbarHeight,
        title: Text(compactHeader ? 'Tuner' : 'Instrument Tuner'),
        centerTitle: true,
        elevation: 0,
        actions: widget.controller.state.error == null
            ? [_metronomeHeaderAction]
            : null,
      ),
      body: widget.controller.state.error != null
          ? _buildErrorView()
          : _buildTunerView(),
    );
  }

  /// Builds error view with error message and retry button
  Widget _buildErrorView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error, size: 48, color: AppColors.error),
          const SizedBox(height: 16),
          Text(
            widget.controller.state.error ?? '',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            key: const ValueKey('open-metronome'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(220, 64),
              foregroundColor: AppColors.cyan,
              side: const BorderSide(color: AppColors.cyan, width: 1.5),
              textStyle: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            onPressed: _openMetronome,
            icon: const MetronomeIcon(size: 30),
            label: const Text('Metronome'),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => widget.controller.enterTuner(),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  /// Builds main tuner view with gauge and status, sized to fill the screen.
  Widget _buildTunerView() {
    final compact =
        MediaQuery.sizeOf(context).height < 650 ||
        MediaQuery.textScalerOf(context).scale(14) > 17;
    if (compact) {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            NoteDisplay(
              currentNote: _currentNote,
              detectedFrequency: _currentFrequency,
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 240,
              child: TunerGauge(centsOffset: _centsOffset, isInTune: _isInTune),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 88,
              child: TuningStatus(
                centsOffset: _centsOffset,
                isInTune: _isInTune,
              ),
            ),
          ],
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          NoteDisplay(
            currentNote: _currentNote,
            detectedFrequency: _currentFrequency,
          ),
          const SizedBox(height: 16),
          Expanded(
            // Weighted so the gauge gets most of the space below the note.
            flex: 3,
            child: TunerGauge(centsOffset: _centsOffset, isInTune: _isInTune),
          ),
          const SizedBox(height: 16),
          Expanded(
            flex: 1,
            child: TuningStatus(centsOffset: _centsOffset, isInTune: _isInTune),
          ),
        ],
      ),
    );
  }

  Widget get _metronomeHeaderAction => Semantics(
    key: const ValueKey('open-metronome'),
    label: 'Metronome',
    button: true,
    child: Tooltip(
      message: 'Metronome',
      child: Padding(
        padding: const EdgeInsets.only(right: 8),
        child: OutlinedButton(
          onPressed: _openMetronome,
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(56, 56),
            padding: const EdgeInsets.all(14),
            tapTargetSize: MaterialTapTargetSize.padded,
            foregroundColor: AppColors.cyan,
            side: BorderSide(color: AppColors.cyan.withValues(alpha: 0.72)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          child: const MetronomeIcon(size: 28),
        ),
      ),
    ),
  );
}
