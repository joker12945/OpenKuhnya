import 'package:flutter/material.dart';

import 'app_spacing.dart';

class SectionHeading extends StatelessWidget {
  const SectionHeading({
    super.key,
    required this.title,
    required this.icon,
    this.trailing,
  });

  final String title;
  final IconData icon;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final titleText = Text(
      title,
      style: Theme.of(context).textTheme.titleLarge
          ?.copyWith(fontWeight: FontWeight.w700),
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final trailingWidget = trailing;
        final stackTrailing =
            constraints.maxWidth < 360 ||
            MediaQuery.textScalerOf(context).scale(16) >= 24;
        final heading = Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 20, color: colors.primary),
            const SizedBox(width: 10),
            Expanded(child: titleText),
          ],
        );
        if (trailingWidget == null) return heading;
        if (stackTrailing) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              heading,
              const SizedBox(height: AppSpacing.element / 2),
              Align(alignment: Alignment.centerRight, child: trailingWidget),
            ],
          );
        }
        return Row(
          children: [
            Expanded(child: heading),
            const SizedBox(width: AppSpacing.element),
            trailingWidget,
          ],
        );
      },
    );
  }
}
