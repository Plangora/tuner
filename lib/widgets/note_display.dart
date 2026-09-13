import 'package:flutter/material.dart';
import 'package:tuner/models/note.dart';

/// A widget that displays the current note name and frequency information.
///
/// Shows:
/// - The name of the detected note (e.g., "A4", "C♯4") or "--" if not detected
/// - The detected frequency in Hz
/// - The target frequency for the detected note
class NoteDisplay extends StatelessWidget {
  /// The currently detected note, or null if no note has been detected.
  final Note? currentNote;

  /// The detected frequency in Hz.
  final double detectedFrequency;

  const NoteDisplay({
    super.key,
    required this.currentNote,
    required this.detectedFrequency,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Note name
        Text(
          currentNote?.toString() ?? '--',
          style: textTheme.displayLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        // Detected frequency
        Text(
          '${detectedFrequency.toStringAsFixed(1)} Hz',
          style: textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        // Target frequency
        Text(
          currentNote != null
              ? '${currentNote!.frequency.toStringAsFixed(2)} Hz'
              : '--',
          style: textTheme.bodySmall?.copyWith(
            color: Colors.grey,
          ),
        ),
      ],
    );
  }
}
