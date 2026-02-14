import 'package:flutter/material.dart';
import '../utils/constants.dart';

class VolumeSlider extends StatelessWidget {
  final String label;
  final IconData icon;
  final double value;
  final ValueChanged<double> onChanged;
  final bool enabled;
  final Color? activeColor;

  const VolumeSlider({
    super.key,
    required this.label,
    required this.icon,
    required this.value,
    required this.onChanged,
    this.enabled = true,
    this.activeColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = activeColor ?? theme.colorScheme.primary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Icon(
                icon,
                size: 20,
                color: enabled ? color : Colors.grey,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: enabled ? null : Colors.grey,
                ),
              ),
              const Spacer(),
              Text(
                '${(value * 100).round()}%',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: enabled ? color : Colors.grey,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        SizedBox(
          width: AppConstants.volumeSliderWidth,
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: enabled ? color : Colors.grey,
              inactiveTrackColor:
                  enabled ? color.withOpacity(0.3) : Colors.grey.withOpacity(0.3),
              thumbColor: enabled ? color : Colors.grey,
              overlayColor: color.withOpacity(0.2),
              trackHeight: 6,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
            ),
            child: Slider(
              value: value,
              min: AppConstants.minVolume,
              max: AppConstants.maxVolume,
              onChanged: enabled ? onChanged : null,
            ),
          ),
        ),
      ],
    );
  }
}
