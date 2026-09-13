import 'package:flutter/material.dart';
import 'package:tuner/models/note.dart';
import 'package:tuner/services/audio_service.dart';
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
  bool _isRecording = false;
  bool _hasError = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _audioService = AudioService();
    _initializeAudio();
  }

  /// Initializes the audio service
  Future<void> _initializeAudio() async {
    try {
      await _audioService.initialize();
    } catch (e) {
      _showError(e.toString());
    }
  }

  /// Toggles audio recording on/off
  Future<void> _toggleRecording() async {
    try {
      if (_isRecording) {
        await _audioService.stopRecording();
        setState(() {
          _isRecording = false;
        });
      } else {
        await _audioService.startRecording(_onPitchDetected);
        setState(() {
          _isRecording = true;
        });
      }
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
            color: Colors.red,
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

  /// Builds main tuner view with gauge and controls
  Widget _buildTunerView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            NoteDisplay(
              currentNote: _currentNote,
              detectedFrequency: _currentFrequency,
            ),
            const SizedBox(height: 24),
            TunerGauge(
              centsOffset: _centsOffset,
              isInTune: _isInTune,
            ),
            const SizedBox(height: 24),
            TuningStatus(
              centsOffset: _centsOffset,
              isInTune: _isInTune,
            ),
            const SizedBox(height: 32),
            FloatingActionButton.extended(
              onPressed: _toggleRecording,
              label: Text(_isRecording ? 'Stop Tuning' : 'Start Tuning'),
              icon: Icon(_isRecording ? Icons.stop : Icons.mic),
            ),
          ],
        ),
      ),
    );
  }
}
