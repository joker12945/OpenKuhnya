import 'package:flutter/material.dart';

import 'app_spacing.dart';

class SectionPanel extends StatelessWidget {
  const SectionPanel({super.key, required this.child, this.emphasized = false});

  final Widget child;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: emphasized ? colors.surfaceContainerLow : Colors.transparent,
      shape: emphasized
          ? RoundedRectangleBorder(
              side: BorderSide(
                color: colors.outlineVariant.withValues(alpha: 0.6),
              ),
              borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
            )
          : null,
      clipBehavior: emphasized ? Clip.antiAlias : Clip.none,
      child: child,
    );
  }
}
