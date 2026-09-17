import 'package:flutter/material.dart';
import 'package:tuner/theme/app_theme.dart';

/// A widget that displays the tuning status (In Tune, Flat, or Sharp).
///
/// Shows a colored status indicator based on the relationship between
/// the detected frequency and the target frequency:
/// - Neon green: In Tune (±5 cents)
/// - Cyan: Flat (below target)
/// - Magenta: Sharp (above target)
class TuningStatus extends StatelessWidget {
  /// The offset in cents from the target frequency.
  final double centsOffset;

  /// Whether the current pitch is within ±5 cents (in tune).
  final bool isInTune;

  const TuningStatus({
    super.key,
    required this.centsOffset,
    required this.isInTune,
  });

  @override
  Widget build(BuildContext context) {
    // Determine status text and color
    late String statusText;
    late Color statusColor;

    if (isInTune) {
      statusText = 'In Tune';
      statusColor = AppColors.success;
    } else if (centsOffset < 0) {
      statusText = 'Flat';
      statusColor = AppColors.flat;
    } else {
      statusText = 'Sharp';
      statusColor = AppColors.sharp;
    }

    return SizedBox.expand(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        decoration: BoxDecoration(
          color: statusColor.withValues(alpha: 0.12),
          border: Border.all(color: statusColor, width: 4),
          borderRadius: BorderRadius.circular(24),
          boxShadow: AppTheme.glow(statusColor),
        ),
        alignment: Alignment.center,
        // Scales the text up to fill the box, whatever size the screen gives it.
        child: FittedBox(
          fit: BoxFit.contain,
          child: Text(
            statusText,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: statusColor,
              fontSize: 40,
            ),
          ),
        ),
      ),
    );
  }
}
