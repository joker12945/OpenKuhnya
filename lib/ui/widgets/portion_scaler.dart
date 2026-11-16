import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../utils/quantity_format.dart';

class PortionScaler extends StatelessWidget {
  const PortionScaler({
    super.key,
    required this.servings,
    required this.baseServings,
    required this.onChanged,
  });

  final int servings;
  final int baseServings;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final maxValue = math.min(100, math.max(12, baseServings * 4)).toDouble();
    final sliderValue = math.min(servings.toDouble(), maxValue);
    final factor = servings / baseServings;
    final isOriginal = servings == baseServings;

    return Card.filled(
      margin: EdgeInsets.zero,
      color: cs.primaryContainer,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(
          children: [
            Row(
              children: [
                Icon(Icons.restaurant_menu, color: cs.onPrimaryContainer),
                const SizedBox(width: 8),
                Text(
                  'Servings',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: cs.onPrimaryContainer,
                  ),
                ),
                const Spacer(),
                AnimatedOpacity(
                  duration: const Duration(milliseconds: 200),
                  opacity: isOriginal ? 0 : 1,
                  child: TextButton(
                    onPressed: isOriginal
                        ? null
                        : () => onChanged(baseServings),
                    child: const Text('Reset'),
                  ),
                ),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton.filledTonal(
                  tooltip: 'Fewer servings',
                  onPressed: servings > 1
                      ? () => onChanged(servings - 1)
                      : null,
                  icon: const Icon(Icons.remove),
                ),
                SizedBox(
                  width: 110,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    transitionBuilder: (child, anim) => ScaleTransition(
                      scale: anim,
                      child: FadeTransition(opacity: anim, child: child),
                    ),
                    child: Text(
                      '$servings',
                      key: ValueKey(servings),
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: cs.onPrimaryContainer,
                      ),
                    ),
                  ),
                ),
                IconButton.filledTonal(
                  tooltip: 'More servings',
                  onPressed: servings < 999
                      ? () => onChanged(servings + 1)
                      : null,
                  icon: const Icon(Icons.add),
                ),
              ],
            ),
            Slider(
              value: sliderValue,
              min: 1,
              max: maxValue,
              divisions: maxValue.toInt() - 1,
              label: '$servings',
              onChanged: (v) => onChanged(v.round()),
            ),
            Text(
              isOriginal
                  ? 'Original recipe · serves $baseServings'
                  : '×${formatNumber(factor, decimals: 2)} · original serves $baseServings',
              style: theme.textTheme.bodySmall?.copyWith(
                color: cs.onPrimaryContainer,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
