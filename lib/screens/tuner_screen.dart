import 'package:flutter/material.dart';
import 'package:tuner/models/note.dart';
import 'package:tuner/services/audio_service.dart';
import 'package:tuner/theme/app_theme.dart';
import 'package:tuner/widgets/note_display.dart';
import 'package:tuner/widgets/tuner_gauge.dart';
import 'package:tuner/widgets/tuning_status.dart';

/// Main tuner screen widget that manages audio recording and real-time pitch display.
class TunerScreen extends StatefulWidget {
  const TunerScreen({super.key});

  @override
  State<TunerScreen> createState() => _TunerScreenState();
}

/// State management for TunerScreen handling audio integration and UI updates.
class _TunerScreenState extends State<TunerScreen> {
  late AudioService _audioService;
  double _currentFrequency = 0;
  Note? _currentNote;
  double _centsOffset = 0;
  bool _isInTune = false;
  bool _hasError = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _audioService = AudioService();
    _initializeAudio();
  }

  /// Initializes the audio service and starts tuning immediately.
  Future<void> _initializeAudio() async {
    try {
      await _audioService.initialize();
      await _audioService.startRecording(_onPitchDetected);
    } catch (e) {
      _showError(e.toString());
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

  /// Shows error message
  void _showError(String message) {
    setState(() {
      _hasError = true;
      _errorMessage = message;
    });
  }

  @override
  void dispose() {
    _audioService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Instrument Tuner'),
        centerTitle: true,
        elevation: 0,
      ),
      body: _hasError ? _buildErrorView() : _buildTunerView(),
    );
  }

  /// Builds error view with error message and retry button
  Widget _buildErrorView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error,
            size: 48,
            color: AppColors.error,
          ),
          const SizedBox(height: 16),
          Text(_errorMessage),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _hasError = false;
              });
              _initializeAudio();
            },
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
            flex: 1,
            child: TunerGauge(
              centsOffset: _centsOffset,
              isInTune: _isInTune,
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            // Weighted so the status label occupies roughly half the screen.
            flex: 3,
            child: TuningStatus(
              centsOffset: _centsOffset,
              isInTune: _isInTune,
            ),
          ),
        ],
      ),
    );
  }
}
