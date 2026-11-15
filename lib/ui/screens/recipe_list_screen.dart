import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/recipe.dart';
import '../../providers/recipe_providers.dart';
import '../../providers/shopping_list_provider.dart';
import '../../utils/quantity_format.dart';
import '../widgets/app_spacing.dart';
import '../widgets/feature_tour.dart';
import '../widgets/press_feedback.dart';
import 'recipe_detail_screen.dart';
import 'recipe_edit_screen.dart';
import 'recipe_shared_import_screen.dart';
import 'recipe_text_import_screen.dart';
import 'settings_screen.dart';
import 'shopping_list_screen.dart';

enum _RecipeSort { recent, title, quickest }

class RecipeListScreen extends ConsumerStatefulWidget {
  const RecipeListScreen({super.key});

  @override
  ConsumerState<RecipeListScreen> createState() => _RecipeListScreenState();
}

class _RecipeListScreenState extends ConsumerState<RecipeListScreen> {
  String _query = '';
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _availableIngredients = TextEditingController();
  final Set<String> _selectedTags = {};
  bool _favoritesOnly = false;
  bool _quickRecipesOnly = false;
  bool _matchAllAvailableIngredients = false;
  bool _filtersExpanded = false;
  _RecipeSort _sort = _RecipeSort.recent;
  bool _actionsExpanded = false;
  bool _recentlyViewedExpanded = false;
  final List<String> _recentlyViewedIds = [];

  List<String> get _availableIngredientQueries => _availableIngredients.text
      .split(',')
      .map((ingredient) => ingredient.trim().toLowerCase())
      .where((ingredient) => ingredient.isNotEmpty)
      .toList();

  List<String> get _activeFilterLabels => [
    if (_query.isNotEmpty) 'Search: ${_searchController.text.trim()}',
    if (_favoritesOnly) 'Favorites',
    if (_quickRecipesOnly) 'Under 30 min',
    ..._selectedTags,
    for (final ingredient in _availableIngredientQueries) 'Have: $ingredient',
    if (_matchAllAvailableIngredients && _availableIngredientQueries.isNotEmpty)
      'Match all listed ingredients',
  ];

  @override
  void dispose() {
    _searchController.dispose();
    _availableIngredients.dispose();
    super.dispose();
  }

  void _clearFilters() {
    setState(() {
      _query = '';
      _searchController.clear();
      _favoritesOnly = false;
      _quickRecipesOnly = false;
      _matchAllAvailableIngredients = false;
      _selectedTags.clear();
      _availableIngredients.clear();
    });
  }

  void _toggleFiltersExpanded() {
    setState(() => _filtersExpanded = !_filtersExpanded);
  }

  List<Widget> _activeFilterChips() {
    final chips = <Widget>[];
    void add(String key, String label, VoidCallback onDeleted) {
      chips.add(
        InputChip(
          key: ValueKey('active-filter-$key'),
          label: Text(label),
          onDeleted: onDeleted,
          deleteButtonTooltipMessage: 'Remove $label filter',
          visualDensity: VisualDensity.compact,
          backgroundColor: Theme.of(context).colorScheme.surfaceContainerLow,
        ),
      );
    }

    if (_query.isNotEmpty) {
      add('search', 'Search: ${_searchController.text.trim()}', () {
        _searchController.clear();
        setState(() => _query = '');
      });
    }
    if (_favoritesOnly) {
      add('favorites', 'Favorites', () {
        setState(() => _favoritesOnly = false);
      });
    }
    if (_quickRecipesOnly) {
      add('quick', 'Under 30 min', () {
        setState(() => _quickRecipesOnly = false);
      });
    }
    for (final tag in _selectedTags) {
      add('tag-${tag.toLowerCase()}', tag, () {
        setState(() => _selectedTags.remove(tag));
      });
    }
    for (final ingredient in _availableIngredientQueries) {
      add('ingredient-$ingredient', 'Have: $ingredient', () {
        final remaining = _availableIngredients.text
            .split(',')
            .map((value) => value.trim())
            .where((value) => value.toLowerCase() != ingredient)
            .toList();
        setState(() => _availableIngredients.text = remaining.join(', '));
      });
    }
    if (_matchAllAvailableIngredients &&
        _availableIngredientQueries.isNotEmpty) {
      add('match-all', 'Match all', () {
        setState(() => _matchAllAvailableIngredients = false);
      });
    }
    return chips;
  }

  Future<void> _importText() async {
    setState(() => _actionsExpanded = false);
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const RecipeTextImportScreen()));
  }

  Future<void> _importSharedRecipe() async {
    setState(() => _actionsExpanded = false);
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const RecipeSharedImportScreen()));
  }

  Future<void> _addRecipe() async {
    setState(() => _actionsExpanded = false);
    await Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const RecipeEditScreen()));
  }

  Future<void> _openPage(Widget page) async {
    setState(() => _actionsExpanded = false);
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
  }

  Future<void> _openRecipe(String recipeId) async {
    setState(() {
      _actionsExpanded = false;
      _recentlyViewedIds
        ..remove(recipeId)
        ..insert(0, recipeId);
      if (_recentlyViewedIds.length > 10) {
        _recentlyViewedIds.removeLast();
      }
    });
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => RecipeDetailScreen(recipeId: recipeId)),
    );
  }

  List<Recipe> _filter(List<Recipe> all) {
    int totalMinutes(Recipe recipe) =>
        (recipe.prepMinutes ?? 0) + (recipe.cookMinutes ?? 0);

    final available = _availableIngredientQueries;

    final filtered = all.where((recipe) {
      final matchesQuery =
          _query.isEmpty ||
          recipe.title.toLowerCase().contains(_query) ||
          recipe.tags.any((tag) => tag.toLowerCase().contains(_query)) ||
          recipe.ingredients.any(
            (ingredient) => ingredient.name.toLowerCase().contains(_query),
          );
      return matchesQuery &&
          (!_favoritesOnly || recipe.isFavorite) &&
          (!_quickRecipesOnly ||
              (totalMinutes(recipe) > 0 && totalMinutes(recipe) <= 30)) &&
          _selectedTags.every(recipe.tags.contains) &&
          (available.isEmpty ||
              (_matchAllAvailableIngredients ? available.every : available.any)(
                (query) => recipe.ingredients.any((ingredient) {
                  final name = ingredient.name.toLowerCase();
                  return name.contains(query) || query.contains(name);
                }),
              ));
    }).toList();

    switch (_sort) {
      case _RecipeSort.recent:
        filtered.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      case _RecipeSort.title:
        filtered.sort(
          (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
        );
      case _RecipeSort.quickest:
        filtered.sort((a, b) {
          final aMinutes = totalMinutes(a);
          final bMinutes = totalMinutes(b);
          if (aMinutes == 0) return bMinutes == 0 ? 0 : 1;
          if (bMinutes == 0) return -1;
          return aMinutes.compareTo(bMinutes);
        });
    }
    return filtered;
  }

  void _showErrorMessage(String message) {
    if (!mounted) return;
    final colors = Theme.of(context).colorScheme;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.error_outline, color: colors.onInverseSurface),
              const SizedBox(width: 12),
              Expanded(child: Text(message)),
            ],
          ),
        ),
      );
  }

  Future<void> _toggleFavorite(Recipe recipe) async {
    try {
      await ref
          .read(recipesProvider.notifier)
          .setFavorite(recipe.id, !recipe.isFavorite);
    } catch (error) {
      _showErrorMessage('Could not update favorite: $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    final recipesAsync = ref.watch(recipesProvider);
    final shoppingItemsAsync = ref.watch(shoppingListProvider);
    ref.listen(recipesProvider, (previous, next) {
      next.whenData((recipes) {
        final availableIds = recipes.map((recipe) => recipe.id).toSet();
        _recentlyViewedIds.removeWhere((id) => !availableIds.contains(id));
      });
    });
    final pendingShoppingItems =
        shoppingItemsAsync.value?.where((item) => !item.isBought).length ?? 0;
    ref.listen(weeklyBackupProvider, (previous, next) {
      next.whenOrNull(
        error: (error, _) {
          _showErrorMessage('Automatic backup failed: $error');
        },
      );
    });

    return Scaffold(
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (_actionsExpanded) ...[
            _QuickActionButton(
              heroTag: 'add-recipe-action',
              icon: Icons.add,
              label: 'Add new recipe',
              onPressed: _addRecipe,
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Theme.of(context).colorScheme.onPrimary,
            ),
            const SizedBox(height: 8),
            _QuickActionButton(
              heroTag: 'import-text-action',
              icon: Icons.content_paste_go_outlined,
              label: 'Import from text',
              onPressed: _importText,
            ),
            const SizedBox(height: 8),
            _QuickActionButton(
              heroTag: 'import-shared-recipe-action',
              icon: Icons.share_outlined,
              label: 'Import shared recipe',
              onPressed: _importSharedRecipe,
            ),
            const SizedBox(height: 12),
          ],
          PressFeedback(
            child: FloatingActionButton(
              tooltip: _actionsExpanded
                  ? 'Close actions'
                  : 'Add or import recipe',
              onPressed: () =>
                  setState(() => _actionsExpanded = !_actionsExpanded),
              child: Icon(_actionsExpanded ? Icons.close : Icons.add),
            ),
          ),
        ],
      ),
      body: NotificationListener<UserScrollNotification>(
        onNotification: (notification) {
          if (_actionsExpanded &&
              notification.direction != ScrollDirection.idle) {
            setState(() => _actionsExpanded = false);
          }
          return false;
        },
        child: CustomScrollView(
          slivers: [
            SliverAppBar.large(
              title: const Text('OpenKuhnya'),
              pinned: true,
              actions: [
                IconButton(
                  tooltip: 'Quick tutorial',
                  icon: const Icon(Icons.auto_stories_outlined),
                  onPressed: () => showFeatureTourDialog(context),
                ),
                IconButton(
                  tooltip: 'Settings',
                  icon: const Icon(Icons.settings_outlined),
                  onPressed: () => _openPage(const SettingsScreen()),
                ),
              ],
            ),
            recipesAsync.when(
              loading: () => const SliverToBoxAdapter(child: SizedBox.shrink()),
              error: (_, _) =>
                  const SliverToBoxAdapter(child: SizedBox.shrink()),
              data: (recipes) {
                if (recipes.isEmpty) {
                  return const SliverToBoxAdapter(child: SizedBox.shrink());
                }

                return SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.pageGutter,
                      AppSpacing.pageTop,
                      AppSpacing.pageGutter,
                      AppSpacing.element,
                    ),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final theme = Theme.of(context);
                          final colors = theme.colorScheme;
                          final mark = Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: colors.secondary,
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: Icon(
                              Icons.shuffle_rounded,
                              color: colors.onSecondary,
                            ),
                          );
                          final message = Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Can't decide?",
                                style: theme.textTheme.titleSmall?.copyWith(
                                  color: colors.onPrimaryContainer,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                'Pick something from your recipe box.',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: colors.onPrimaryContainer,
                                ),
                              ),
                            ],
                          );
                          final action = FilledButton.icon(
                            key: const ValueKey('surprise-me-recipe'),
                            onPressed: () => _openRecipe(
                              recipes[Random().nextInt(recipes.length)].id,
                            ),
                            icon: const Icon(Icons.shuffle_rounded),
                            label: const Text('Surprise me'),
                            style: FilledButton.styleFrom(
                              minimumSize: const Size(0, 48),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 18,
                              ),
                            ),
                          );
                          final useStackedLayout =
                              constraints.maxWidth < 440 ||
                              MediaQuery.textScalerOf(context).scale(14) >= 20;

                          if (useStackedLayout) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Row(
                                  children: [
                                    mark,
                                    const SizedBox(width: 12),
                                    Expanded(child: message),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: action,
                                ),
                              ],
                            );
                          }

                          return Row(
                            children: [
                              mark,
                              const SizedBox(width: 12),
                              Expanded(child: message),
                              const SizedBox(width: 8),
                              action,
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                );
              },
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.pageGutter,
                  AppSpacing.pageTop,
                  AppSpacing.pageGutter,
                  0,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Find something delicious',
                      key: const ValueKey('home-search-heading'),
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Search recipes, ingredients, or tags.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 14),
                    SearchBar(
                      controller: _searchController,
                      hintText: 'Search your recipes',
                      leading: const Icon(Icons.search),
                      trailing: [
                        IconButton(
                          tooltip: 'Filters',
                          onPressed: _toggleFiltersExpanded,
                          icon: Badge(
                            isLabelVisible: _activeFilterLabels.isNotEmpty,
                            label: Text('${_activeFilterLabels.length}'),
                            child: const Icon(Icons.tune),
                          ),
                        ),
                        if (_searchController.text.isNotEmpty)
                          IconButton(
                            tooltip: 'Clear search',
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _query = '');
                            },
                            icon: const Icon(Icons.clear),
                          ),
                      ],
                      elevation: const WidgetStatePropertyAll(0),
                      onChanged: (v) {
                        setState(() => _query = v.trim().toLowerCase());
                      },
                    ),
                    if (_activeFilterLabels.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 0,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            ..._activeFilterChips(),
                            TextButton(
                              onPressed: _clearFilters,
                              child: const Text('Clear all'),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.pageGutter,
                  AppSpacing.element,
                  AppSpacing.pageGutter,
                  4,
                ),
                child: SizedBox(
                  width: double.infinity,
                  child: Tooltip(
                    message: 'Shopping list',
                    child: PressFeedback(
                      child: FilledButton(
                        key: const ValueKey('shopping-list-button'),
                        onPressed: () => _openPage(const ShoppingListScreen()),
                        child: Row(
                          children: [
                            Badge(
                              key: const ValueKey(
                                'shopping-list-pending-count',
                              ),
                              isLabelVisible: pendingShoppingItems > 0,
                              label: Text(
                                pendingShoppingItems > 99
                                    ? '99+'
                                    : '$pendingShoppingItems',
                              ),
                              child: const Icon(Icons.shopping_basket_outlined),
                            ),
                            const SizedBox(width: 14),
                            const Expanded(child: Text('Shopping list')),
                            const Icon(Icons.arrow_forward_rounded),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            recipesAsync.when(
              loading: () => const SliverToBoxAdapter(child: SizedBox.shrink()),
              error: (_, _) =>
                  const SliverToBoxAdapter(child: SizedBox.shrink()),
              data: (recipes) {
                final tags =
                    recipes.expand((recipe) => recipe.tags).toSet().toList()
                      ..sort();
                if (!_filtersExpanded) {
                  return const SliverToBoxAdapter(child: SizedBox.shrink());
                }
                return SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.pageGutter,
                      0,
                      AppSpacing.pageGutter,
                      8,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              FilterChip(
                                label: const Text('Favorites'),
                                avatar: const Icon(Icons.favorite, size: 18),
                                selected: _favoritesOnly,
                                onSelected: (selected) {
                                  setState(() => _favoritesOnly = selected);
                                },
                              ),
                              const SizedBox(width: 8),
                              FilterChip(
                                label: const Text('Under 30 min'),
                                avatar: const Icon(Icons.bolt, size: 18),
                                selected: _quickRecipesOnly,
                                onSelected: (selected) {
                                  setState(() => _quickRecipesOnly = selected);
                                },
                              ),
                              for (final tag in tags) ...[
                                const SizedBox(width: 8),
                                FilterChip(
                                  label: Text(tag),
                                  selected: _selectedTags.contains(tag),
                                  onSelected: (selected) {
                                    setState(() {
                                      if (selected) {
                                        _selectedTags.add(tag);
                                      } else {
                                        _selectedTags.remove(tag);
                                      }
                                    });
                                  },
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          key: const ValueKey('available-ingredients-filter'),
                          controller: _availableIngredients,
                          onChanged: (_) {
                            setState(() {});
                          },
                          decoration: InputDecoration(
                            labelText: 'Use what I have',
                            hintText: 'e.g. tomato, rice, chicken',
                            helperText: _matchAllAvailableIngredients
                                ? 'Recipes must contain every listed ingredient.'
                                : 'Recipes must contain at least one listed ingredient.',
                            prefixIcon: const Icon(Icons.kitchen_outlined),
                            suffixIcon: _availableIngredients.text.isEmpty
                                ? null
                                : IconButton(
                                    tooltip: 'Clear available ingredients',
                                    onPressed: () {
                                      _availableIngredients.clear();
                                      setState(() {});
                                    },
                                    icon: const Icon(Icons.clear),
                                  ),
                            isDense: true,
                          ),
                          textCapitalization: TextCapitalization.words,
                        ),
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Row(
                            children: [
                              Text(
                                'Match:',
                                style: Theme.of(context).textTheme.labelLarge,
                              ),
                              const SizedBox(width: 8),
                              SegmentedButton<bool>(
                                key: const ValueKey(
                                  'available-ingredients-match-mode',
                                ),
                                showSelectedIcon: false,
                                segments: const [
                                  ButtonSegment(
                                    value: false,
                                    label: Text('Any'),
                                  ),
                                  ButtonSegment(
                                    value: true,
                                    label: Text('All'),
                                  ),
                                ],
                                selected: {_matchAllAvailableIngredients},
                                onSelectionChanged: (selection) {
                                  setState(() {
                                    _matchAllAvailableIngredients =
                                        selection.single;
                                  });
                                },
                              ),
                            ],
                          ),
                        ),
                        Text(
                          '“Under 30 min” includes recipes with a recorded total time; recipes without time data are excluded.',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                              ),
                        ),
                        Align(
                          alignment: Alignment.centerRight,
                          child: DropdownButton<_RecipeSort>(
                            value: _sort,
                            isDense: true,
                            underline: const SizedBox.shrink(),
                            onChanged: (sort) {
                              if (sort != null) {
                                setState(() => _sort = sort);
                              }
                            },
                            items: const [
                              DropdownMenuItem(
                                value: _RecipeSort.recent,
                                child: Text('Recently updated'),
                              ),
                              DropdownMenuItem(
                                value: _RecipeSort.title,
                                child: Text('Title A–Z'),
                              ),
                              DropdownMenuItem(
                                value: _RecipeSort.quickest,
                                child: Text('Quickest first'),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            recipesAsync.when(
              loading: () => const SliverToBoxAdapter(child: SizedBox.shrink()),
              error: (_, _) =>
                  const SliverToBoxAdapter(child: SizedBox.shrink()),
              data: (all) {
                final recipesById = {
                  for (final recipe in all) recipe.id: recipe,
                };
                final recentlyViewed = _recentlyViewedIds
                    .map((id) => recipesById[id])
                    .whereType<Recipe>()
                    .toList();
                if (recentlyViewed.isEmpty) {
                  return const SliverToBoxAdapter(child: SizedBox.shrink());
                }
                return SliverToBoxAdapter(
                  child: _RecentlyViewedSection(
                    recipes: recentlyViewed,
                    onTap: _openRecipe,
                    isExpanded: _recentlyViewedExpanded,
                    onToggleExpanded: () {
                      setState(
                        () =>
                            _recentlyViewedExpanded = !_recentlyViewedExpanded,
                      );
                    },
                  ),
                );
              },
            ),
            recipesAsync.when(
              loading: () =>
                  const SliverToBoxAdapter(child: _RecipeListLoadingState()),
              error: (e, _) => SliverFillRemaining(
                hasScrollBody: false,
                child: _RecipeListErrorState(
                  error: e,
                  onRetry: () => ref.invalidate(recipesProvider),
                ),
              ),
              data: (all) {
                final items = _filter(all);
                final recipeSlivers = <Widget>[
                  if (items.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: _EmptyState(
                        hasAny: all.isNotEmpty,
                        searchQuery: _searchController.text.trim(),
                        onAddRecipe: _addRecipe,
                        onImportText: _importText,
                        onClearFilters: _clearFilters,
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.pageGutter,
                        4,
                        AppSpacing.pageGutter,
                        96,
                      ),
                      sliver: SliverList.separated(
                        itemCount: items.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 0),
                        itemBuilder: (_, i) => _RecipeCard(
                          key: ValueKey(items[i].id),
                          recipe: items[i],
                          onTap: () => _openRecipe(items[i].id),
                          onToggleFavorite: () => _toggleFavorite(items[i]),
                        ),
                      ),
                    ),
                ];
                return SliverMainAxisGroup(
                  slivers: [
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                        child: _AllRecipesHeader(
                          count: items.length,
                          isFiltered: _activeFilterLabels.isNotEmpty,
                        ),
                      ),
                    ),
                    ...recipeSlivers,
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _AllRecipesHeader extends StatelessWidget {
  const _AllRecipesHeader({required this.count, required this.isFiltered});

  final int count;
  final bool isFiltered;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      key: const ValueKey('all-recipes-header'),
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              isFiltered ? 'Matching recipes' : 'All recipes',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Text('$count', style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _QuickActionButton extends StatelessWidget {
  const _QuickActionButton({
    required this.heroTag,
    required this.icon,
    required this.label,
    required this.onPressed,
    this.backgroundColor,
    this.foregroundColor,
  });

  final String heroTag;
  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final Color? backgroundColor;
  final Color? foregroundColor;

  @override
  Widget build(BuildContext context) {
    return PressFeedback(
      child: FloatingActionButton.extended(
        heroTag: heroTag,
        onPressed: onPressed,
        backgroundColor: backgroundColor,
        foregroundColor: foregroundColor,
        icon: Icon(icon),
        label: Text(label),
      ),
    );
  }
}

class _RecipeListLoadingState extends StatelessWidget {
  const _RecipeListLoadingState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final skeletonColor = theme.colorScheme.onSurface.withValues(alpha: 0.08);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 96),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const SizedBox(
                height: 18,
                width: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Getting your recipes ready',
                  style: theme.textTheme.titleSmall,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          for (var index = 0; index < 3; index++) ...[
            Container(
              height: 92,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: skeletonColor,
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          height: 14,
                          width: index == 1 ? 132 : 184,
                          decoration: BoxDecoration(
                            color: skeletonColor,
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Container(
                          height: 10,
                          width: 112,
                          decoration: BoxDecoration(
                            color: skeletonColor,
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}

class _RecipeListErrorState extends StatelessWidget {
  const _RecipeListErrorState({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.menu_book_outlined,
              size: 44,
              color: theme.colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              'Your recipes couldn’t be opened',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Try again. If the problem continues, check your device storage.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error.toString(),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              key: const ValueKey('retry-loading-recipes'),
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.hasAny,
    required this.searchQuery,
    required this.onAddRecipe,
    required this.onImportText,
    required this.onClearFilters,
  });

  final bool hasAny;
  final String searchQuery;
  final VoidCallback onAddRecipe;
  final VoidCallback onImportText;
  final VoidCallback onClearFilters;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasQuery = searchQuery.isNotEmpty;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Icon(
                hasAny ? Icons.search_off : Icons.menu_book_outlined,
                size: 36,
                color: theme.colorScheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              hasAny
                  ? hasQuery
                        ? 'No results for “$searchQuery”'
                        : 'No recipes match those filters'
                  : 'Your recipe box starts here',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              hasAny
                  ? 'Try another search, or clear the active filters.'
                  : 'Save a recipe you love, or bring one in from text. '
                        'You can add ingredients and cook from it whenever you like.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),
            if (hasAny)
              OutlinedButton.icon(
                onPressed: onClearFilters,
                icon: const Icon(Icons.filter_alt_off_outlined),
                label: Text(
                  hasQuery ? 'Clear search and filters' : 'Clear filters',
                ),
              )
            else ...[
              FilledButton.icon(
                key: const ValueKey('add-first-recipe'),
                onPressed: onAddRecipe,
                icon: const Icon(Icons.add),
                label: const Text('Add your first recipe'),
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                key: const ValueKey('import-first-recipe'),
                onPressed: onImportText,
                icon: const Icon(Icons.content_paste_go_outlined),
                label: const Text('Import from text'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _RecentlyViewedSection extends StatelessWidget {
  const _RecentlyViewedSection({
    required this.recipes,
    required this.onTap,
    required this.isExpanded,
    required this.onToggleExpanded,
  });

  final List<Recipe> recipes;
  final ValueChanged<String> onTap;
  final bool isExpanded;
  final VoidCallback onToggleExpanded;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.pageGutter,
        4,
        0,
        AppSpacing.element,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 16, bottom: 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Recently viewed',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: colors.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${recipes.length}',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: colors.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: isExpanded
                      ? 'Minimize recently viewed'
                      : 'Expand recently viewed',
                  onPressed: onToggleExpanded,
                  icon: Icon(
                    isExpanded ? Icons.expand_less : Icons.expand_more,
                  ),
                ),
              ],
            ),
          ),
          if (isExpanded)
            SizedBox(
              height: 116,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: recipes.length,
                padding: const EdgeInsets.only(right: 16, bottom: 2),
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final recipe = recipes[index];
                  return SizedBox(
                    width: 220,
                    child: Card.outlined(
                      margin: EdgeInsets.zero,
                      clipBehavior: Clip.antiAlias,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          AppSpacing.cardRadius,
                        ),
                      ),
                      child: InkWell(
                        onTap: () => onTap(recipe.id),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    height: 28,
                                    width: 28,
                                    decoration: BoxDecoration(
                                      color: colors.primaryContainer,
                                      borderRadius: BorderRadius.circular(9),
                                    ),
                                    child: Icon(
                                      Icons.history,
                                      size: 16,
                                      color: colors.onPrimaryContainer,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      'OPEN AGAIN',
                                      style: theme.textTheme.labelSmall
                                          ?.copyWith(
                                            color: colors.onSurfaceVariant,
                                            fontWeight: FontWeight.w700,
                                            letterSpacing: 0.6,
                                          ),
                                    ),
                                  ),
                                  Icon(
                                    Icons.arrow_forward_rounded,
                                    size: 16,
                                    color: colors.primary,
                                  ),
                                ],
                              ),
                              const Spacer(),
                              Text(
                                recipe.title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${recipe.servings} servings'
                                '${(recipe.prepMinutes ?? 0) + (recipe.cookMinutes ?? 0) > 0 ? ' · ${formatMinutes((recipe.prepMinutes ?? 0) + (recipe.cookMinutes ?? 0))}' : ''}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: colors.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _RecipeCard extends StatelessWidget {
  const _RecipeCard({
    super.key,
    required this.recipe,
    required this.onTap,
    required this.onToggleFavorite,
  });

  final Recipe recipe;
  final VoidCallback onTap;
  final VoidCallback onToggleFavorite;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final total = (recipe.prepMinutes ?? 0) + (recipe.cookMinutes ?? 0);

    return Card.filled(
      margin: const EdgeInsets.symmetric(vertical: 6),
      color: cs.surfaceContainerLow,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.55)),
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.panel),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact =
                  constraints.maxWidth < 440 ||
                  MediaQuery.textScalerOf(context).scale(16) >= 24;
              final leading = Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: recipe.isFavorite
                      ? cs.tertiaryContainer
                      : cs.primaryContainer,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(
                  recipe.tags.isEmpty
                      ? Icons.restaurant_menu_rounded
                      : Icons.local_offer_outlined,
                  color: recipe.isFavorite
                      ? cs.onTertiaryContainer
                      : cs.onPrimaryContainer,
                  size: 25,
                ),
              );
              final details = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    recipe.title,
                    maxLines: compact ? 2 : 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (recipe.description.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      recipe.description,
                      maxLines: compact ? 2 : 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 10,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      _Meta(
                        icon: Icons.people_outline,
                        text: 'Serves ${recipe.servings}',
                      ),
                      _Meta(
                        icon: Icons.schedule,
                        text: total > 0
                            ? 'Total ${formatMinutes(total)}'
                            : 'Time not set',
                      ),
                    ],
                  ),
                  if (recipe.tags.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        for (final tag in recipe.tags.take(2))
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 9,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: cs.secondaryContainer,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              tag,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: cs.onSecondaryContainer,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ],
              );
              final favoriteButton = IconButton(
                constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                tooltip: recipe.isFavorite
                    ? 'Remove from favorites'
                    : 'Add to favorites',
                onPressed: onToggleFavorite,
                icon: Icon(
                  recipe.isFavorite ? Icons.favorite : Icons.favorite_border,
                  color: recipe.isFavorite ? cs.primary : null,
                ),
              );
              if (compact) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        leading,
                        const SizedBox(width: AppSpacing.element),
                        Expanded(child: details),
                      ],
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        favoriteButton,
                        const Icon(Icons.chevron_right, size: 20),
                      ],
                    ),
                  ],
                );
              }
              return Row(
                children: [
                  leading,
                  const SizedBox(width: AppSpacing.element),
                  Expanded(child: details),
                  favoriteButton,
                  const Icon(Icons.chevron_right, size: 20),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _Meta extends StatelessWidget {
  const _Meta({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.onSurfaceVariant;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            text,
            style: theme.textTheme.bodySmall?.copyWith(color: color),
          ),
        ),
      ],
    );
  }
}
