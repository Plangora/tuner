import 'package:material_ui/material_ui.dart';
import 'package:tuner/models/note.dart';
import 'package:tuner/theme/app_theme.dart';

/// A widget that displays the current note name and detected frequency.
///
/// Shows:
/// - The name of the detected note (e.g., "A4", "C♯4") or "--" if not detected
/// - The detected frequency in Hz
class NoteDisplay extends StatelessWidget {
  /// The currently detected note, or null if no note has been detected.
  final Note? currentNote;

  /// The detected frequency in Hz.
  final double detectedFrequency;

  /// Note size can be reduced when the display shares a landscape row.
  final double noteFontSize;

  const NoteDisplay({
    super.key,
    required this.currentNote,
    required this.detectedFrequency,
    this.noteFontSize = 96,
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
            fontSize: noteFontSize,
            color: AppColors.cyan,
            shadows: AppTheme.glow(AppColors.cyan, blurRadius: 20),
          ),
        ),
        const SizedBox(height: 12),
        // Detected frequency
        Text(
          '${detectedFrequency.toStringAsFixed(1)} Hz',
          style: textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: AppColors.purple,
          ),
        ),
      ],
    );
  }
}
