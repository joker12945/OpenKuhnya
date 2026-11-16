import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/feature_tour_provider.dart';

class FeatureTourLauncher extends ConsumerStatefulWidget {
  const FeatureTourLauncher({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<FeatureTourLauncher> createState() =>
      _FeatureTourLauncherState();
}

class _FeatureTourLauncherState extends ConsumerState<FeatureTourLauncher> {
  bool _tourScheduled = false;
  bool _loadErrorReported = false;

  @override
  Widget build(BuildContext context) {
    ref
        .watch(featureTourSeenProvider)
        .when(
          data: (hasSeenTour) {
            if (!hasSeenTour && !_tourScheduled) {
              _tourScheduled = true;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) _showFirstLaunchTour();
              });
            }
          },
          loading: () {},
          error: (error, _) {
            if (!_loadErrorReported) {
              _loadErrorReported = true;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Could not load feature tour status: $error'),
                    action: SnackBarAction(
                      label: 'Retry',
                      onPressed: () {
                        _loadErrorReported = false;
                        ref.invalidate(featureTourSeenProvider);
                      },
                    ),
                  ),
                );
              });
            }
          },
        );
    return widget.child;
  }

  Future<void> _showFirstLaunchTour() async {
    await showFeatureTourDialog(context);
    if (!mounted) return;

    try {
      await ref.read(featureTourSeenProvider.notifier).markSeen();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save feature tour status: $error')),
      );
    }
  }
}

Future<void> showFeatureTourDialog(BuildContext context) => showDialog<void>(
  context: context,
  builder: (context) => const FeatureTourDialog(),
);

class FeatureTourDialog extends StatelessWidget {
  const FeatureTourDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Dialog(
      clipBehavior: Clip.antiAlias,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 560,
          maxHeight: MediaQuery.sizeOf(context).height * 0.9,
        ),
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    colors.primaryContainer,
                    colors.surfaceContainerHigh,
                  ],
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: colors.primary,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      Icons.auto_stories_rounded,
                      color: colors.onPrimary,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'QUICK TUTORIAL',
                          style: Theme.of(context).textTheme.labelMedium
                              ?.copyWith(
                                color: colors.primary,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.1,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Welcome to OpenKuhnya',
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Your recipes, cooking, and shopping—all in one place.',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: colors.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: const [
                    _FeatureTourItem(
                      icon: Icons.manage_search,
                      title: 'Find the right recipe',
                      description:
                          'Search by recipe name, ingredient, or tag. Filter by favorites, '
                          'quick recipes, tags, or ingredients you have, then sort by '
                          'recently updated, title, or cooking time. Reopen recently '
                          'viewed recipes anytime.',
                    ),
                    _FeatureTourItem(
                      icon: Icons.note_add_outlined,
                      title: 'Create or import recipes',
                      description:
                          'Add recipes with ingredients, steps, servings, prep and cook '
                          'times, and tags. Or paste recipe text to extract ingredients '
                          'and method steps, or import a recipe shared from OpenKuhnya.',
                    ),
                    _FeatureTourItem(
                      icon: Icons.tune,
                      title: 'Make each recipe yours',
                      description:
                          'Edit recipes, mark favorites, and adjust servings to scale '
                          'ingredient amounts. Recipe details also show prep time, cook '
                          'time, and tags.',
                    ),
                    _FeatureTourItem(
                      icon: Icons.play_circle_outline,
                      title: 'Cook step by step',
                      description:
                          'Follow one instruction at a time with a progress indicator. '
                          'Start 1-, 5-, or 10-minute timers, set a custom timer, and '
                          'pause or resume it. Cooking mode keeps the screen on.',
                    ),
                    _FeatureTourItem(
                      icon: Icons.shopping_cart_outlined,
                      title: 'Keep a useful shopping list',
                      description:
                          'Add individual or all recipe ingredients, or enter items '
                          'yourself. Edit or remove items, check off what you bought, '
                          'clear bought items, and share your list.',
                    ),
                    _FeatureTourItem(
                      icon: Icons.share_outlined,
                      title: 'Share recipes',
                      description:
                          'Share a recipe as text with its ingredients scaled to your '
                          'selected servings, or export an individual recipe.',
                    ),
                    _FeatureTourItem(
                      icon: Icons.backup_outlined,
                      title: 'Back up your collection',
                      description:
                          'Import and export recipe-library backups in Settings. Enable '
                          'automatic weekly backups and restore a saved backup when needed.',
                    ),
                    _FeatureTourItem(
                      icon: Icons.palette_outlined,
                      title: 'Choose your look',
                      description:
                          'Pick a theme color and use light mode, dark mode, or your '
                          'device’s system theme.',
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              child: Align(
                alignment: Alignment.centerRight,
                child: FilledButton.icon(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.check_rounded),
                  label: const Text('Got it'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FeatureTourItem extends StatelessWidget {
  const _FeatureTourItem({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: colors.primaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 20, color: colors.onPrimaryContainer),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 3),
                Text(description),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
