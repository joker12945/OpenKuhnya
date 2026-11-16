import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../models/ingredient.dart';
import '../../models/recipe.dart';
import '../../providers/recipe_providers.dart';
import '../../providers/shopping_list_provider.dart';
import '../../utils/quantity_format.dart';
import '../../utils/recipe_share_text.dart';
import '../widgets/app_spacing.dart';
import '../widgets/portion_scaler.dart';
import '../widgets/section_heading.dart';
import 'cooking_mode_screen.dart';
import 'recipe_edit_screen.dart';

class RecipeDetailScreen extends ConsumerStatefulWidget {
  const RecipeDetailScreen({super.key, required this.recipeId});

  final String recipeId;

  @override
  ConsumerState<RecipeDetailScreen> createState() => _RecipeDetailScreenState();
}

class _RecipeDetailScreenState extends ConsumerState<RecipeDetailScreen> {
  int? _servings; // null = use the recipe's own serving size
  bool _awake = false;

  @override
  void dispose() {
    // Never leave the screen locked awake after leaving the recipe.
    if (_awake) WakelockPlus.disable();
    super.dispose();
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _toggleAwake() async {
    final next = !_awake;
    try {
      await WakelockPlus.toggle(enable: next);
      if (mounted) setState(() => _awake = next);
    } catch (_) {
      _snack('Could not change the screen-on setting.');
    }
  }

  Future<void> _toggleFavorite(Recipe recipe) async {
    try {
      await ref
          .read(recipesProvider.notifier)
          .setFavorite(recipe.id, !recipe.isFavorite);
    } catch (error) {
      _snack('Could not update favorite: $error');
    }
  }

  void _startCookingMode(Recipe recipe) {
    if (recipe.steps.isEmpty) return;
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => CookingModeScreen(recipe: recipe)),
    );
  }

  Future<void> _edit(Recipe recipe) async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => RecipeEditScreen(recipe: recipe)));
    if (mounted) setState(() => _servings = null);
  }

  Future<void> _export(Recipe recipe) async {
    try {
      final saved = await ref.read(recipesProvider.notifier).exportOne(recipe);
      if (saved) _snack('Recipe saved.');
    } catch (e) {
      _snack('Export failed: $e');
    }
  }

  Future<void> _share(
    Recipe recipe,
    int servings,
    List<Ingredient> ingredients,
  ) async {
    try {
      await SharePlus.instance.share(
        ShareParams(
          text: formatRecipeForSharing(
            recipe,
            servings: servings,
            ingredients: ingredients,
          ),
          subject: recipe.title,
        ),
      );
    } catch (error) {
      _snack('Could not share recipe: $error');
    }
  }

  Future<void> _addIngredient(Ingredient ingredient, Recipe recipe) async {
    try {
      await ref
          .read(shoppingListProvider.notifier)
          .addIngredient(ingredient, recipeTitle: recipe.title);
      _snack('Added ${ingredient.name} to the shopping list.');
    } catch (error) {
      _snack('Could not add ${ingredient.name}: $error');
    }
  }

  Future<void> _addAllIngredients(
    List<Ingredient> ingredients,
    Recipe recipe,
  ) async {
    try {
      await ref
          .read(shoppingListProvider.notifier)
          .addIngredients(ingredients, recipeTitle: recipe.title);
      _snack('Added ${ingredients.length} ingredients to the shopping list.');
    } catch (error) {
      _snack('Could not add ingredients to the shopping list: $error');
    }
  }

  Future<void> _confirmDelete(Recipe recipe) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete recipe?'),
        content: Text('“${recipe.title}” will be removed from this device.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final notifier = ref.read(recipesProvider.notifier);
    Navigator.of(context).pop();
    await notifier.delete(recipe.id);
  }

  static Widget _leftAligned(Widget? current, List<Widget> previous) =>
      Stack(alignment: Alignment.centerLeft, children: [...previous, ?current]);

  @override
  Widget build(BuildContext context) {
    final recipes = ref.watch(recipesProvider).value;
    final recipe = recipes?.where((r) => r.id == widget.recipeId).firstOrNull;

    if (recipe == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(
          child: recipes == null
              ? const CircularProgressIndicator()
              : const Text('Recipe not found'),
        ),
      );
    }

    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final servings = _servings ?? recipe.servings;
    final ingredients = recipe.ingredientsFor(servings);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            actions: [
              IconButton(
                tooltip: recipe.isFavorite
                    ? 'Remove from favorites'
                    : 'Add to favorites',
                icon: Icon(
                  recipe.isFavorite ? Icons.favorite : Icons.favorite_border,
                ),
                onPressed: () => _toggleFavorite(recipe),
              ),
              IconButton(
                tooltip: 'Edit recipe',
                icon: const Icon(Icons.edit_outlined),
                onPressed: () => _edit(recipe),
              ),
              PopupMenuButton<String>(
                tooltip: 'More recipe actions',
                onSelected: (action) {
                  switch (action) {
                    case 'share':
                      _share(recipe, servings, ingredients);
                    case 'export':
                      _export(recipe);
                    case 'delete':
                      _confirmDelete(recipe);
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(value: 'share', child: Text('Share')),
                  const PopupMenuItem(value: 'export', child: Text('Export')),
                  const PopupMenuItem(value: 'delete', child: Text('Delete')),
                ],
              ),
            ],
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.pageGutter,
              0,
              AppSpacing.pageGutter,
              AppSpacing.pageBottom,
            ),
            sliver: SliverList.list(
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: cs.primaryContainer,
                    borderRadius: BorderRadius.circular(36),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        recipe.title,
                        style: theme.textTheme.headlineMedium?.copyWith(
                          color: cs.onPrimaryContainer,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (recipe.description.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          recipe.description,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: cs.onPrimaryContainer,
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 12,
                        runSpacing: 8,
                        children: [
                          _RecipeMeta(
                            icon: Icons.people_outline,
                            text: 'Serves ${recipe.servings}',
                            color: cs.onPrimaryContainer,
                          ),
                          if (recipe.prepMinutes != null)
                            _RecipeMeta(
                              icon: Icons.timer_outlined,
                              text:
                                  'Prep ${formatMinutes(recipe.prepMinutes!)}',
                              color: cs.onPrimaryContainer,
                            ),
                          if (recipe.cookMinutes != null)
                            _RecipeMeta(
                              icon: Icons.local_fire_department_outlined,
                              text:
                                  'Cook ${formatMinutes(recipe.cookMinutes!)}',
                              color: cs.onPrimaryContainer,
                            ),
                        ],
                      ),
                      if (recipe.tags.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          children: [
                            for (final tag in recipe.tags)
                              Chip(
                                label: Text(tag),
                                visualDensity: VisualDensity.compact,
                                backgroundColor: cs.surfaceContainerHighest,
                              ),
                          ],
                        ),
                      ],
                      if (recipe.steps.isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.section),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            key: const ValueKey('start-cooking-mode'),
                            onPressed: () => _startCookingMode(recipe),
                            icon: const Icon(Icons.play_arrow_rounded),
                            label: const Text('Start cooking'),
                            style: FilledButton.styleFrom(
                              backgroundColor: cs.primary,
                              foregroundColor: cs.onPrimary,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.section),
                PortionScaler(
                  servings: servings,
                  baseServings: recipe.servings,
                  onChanged: (v) => setState(() => _servings = v),
                ),
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: _toggleAwake,
                    icon: Icon(
                      _awake ? Icons.lightbulb : Icons.lightbulb_outline,
                    ),
                    label: Text(_awake ? 'Screen stays on' : 'Keep screen on'),
                  ),
                ),
                const SizedBox(height: AppSpacing.section),
                SectionHeading(
                  title: 'Ingredients',
                  icon: Icons.checklist,
                  trailing: Text(
                    '${ingredients.length}',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ),
                if (ingredients.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.tonalIcon(
                      key: const ValueKey('add-all-recipe-ingredients'),
                      onPressed: () => _addAllIngredients(ingredients, recipe),
                      icon: const Icon(Icons.add_shopping_cart_outlined),
                      label: const Text('Add all ingredients to shopping list'),
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                if (ingredients.isEmpty)
                  Text(
                    'No ingredients listed.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                for (final i in ingredients)
                  _ingredientRow(
                    theme,
                    i,
                    onAdd: () => _addIngredient(i, recipe),
                  ),
                const SizedBox(height: AppSpacing.section),
                SectionHeading(
                  title: 'Method',
                  icon: Icons.menu_book_outlined,
                  trailing: Text(
                    '${recipe.steps.length} steps',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                if (recipe.steps.isEmpty)
                  Text(
                    'No steps listed.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                for (var n = 0; n < recipe.steps.length; n++)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(
                          radius: 13,
                          backgroundColor: cs.primaryContainer,
                          child: Text(
                            '${n + 1}',
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: cs.onPrimaryContainer,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            recipe.steps[n],
                            style: theme.textTheme.bodyLarge?.copyWith(
                              height: 1.45,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _ingredientRow(
    ThemeData theme,
    Ingredient i, {
    required VoidCallback onAdd,
  }) {
    final cs = theme.colorScheme;
    final qty = i.quantity == null
        ? ''
        : [
            formatQuantity(i.quantity!),
            if (i.unit.isNotEmpty) i.unit,
          ].join(' ');

    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.5)),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 9),
              child: Icon(Icons.circle, size: 6, color: cs.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                layoutBuilder: _leftAligned,
                child: Text.rich(
                  TextSpan(
                    children: [
                      if (qty.isNotEmpty)
                        TextSpan(
                          text: '$qty ',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: cs.primary,
                          ),
                        ),
                      TextSpan(text: i.name),
                      if (i.note.isNotEmpty)
                        TextSpan(
                          text: ', ${i.note}',
                          style: TextStyle(color: cs.onSurfaceVariant),
                        ),
                      if (i.substitute.isNotEmpty)
                        TextSpan(
                          text: '\nSubstitute: ${i.substitute}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                  key: ValueKey('${i.name}|$qty'),
                  style: theme.textTheme.bodyLarge,
                ),
              ),
            ),
            IconButton(
              tooltip: 'Add ${i.name} to shopping list',
              onPressed: onAdd,
              icon: const Icon(Icons.add_shopping_cart_outlined),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecipeMeta extends StatelessWidget {
  const _RecipeMeta({required this.icon, required this.text, this.color});

  final IconData icon;
  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final metaColor = color ?? theme.colorScheme.onSurfaceVariant;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: metaColor),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            text,
            style: theme.textTheme.bodySmall?.copyWith(color: metaColor),
          ),
        ),
      ],
    );
  }
}
