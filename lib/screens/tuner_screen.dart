import 'dart:async';

import 'package:flutter/material.dart';
import 'package:tuner/models/note.dart';
import 'package:tuner/services/practice_controller.dart';
import 'package:tuner/models/metronome_state.dart';
import 'package:tuner/theme/app_theme.dart';
import 'package:tuner/widgets/note_display.dart';
import 'package:tuner/widgets/tuner_gauge.dart';
import 'package:tuner/widgets/tuning_status.dart';

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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Instrument Tuner'),
        centerTitle: true,
        elevation: 0,
        actions: [
          IconButton(
            key: const ValueKey('open-metronome'),
            tooltip: 'Metronome',
            onPressed: _openMetronome,
            icon: const Icon(Icons.timer_outlined),
          ),
        ],
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
}
