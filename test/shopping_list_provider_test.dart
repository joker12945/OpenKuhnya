import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recipe_box/main.dart';
import 'package:recipe_box/models/ingredient.dart';
import 'package:recipe_box/models/recipe.dart';
import 'package:recipe_box/models/shopping_item.dart';
import 'package:recipe_box/providers/recipe_providers.dart';
import 'package:recipe_box/providers/settings_provider.dart';
import 'package:recipe_box/providers/shopping_list_provider.dart';
import 'package:recipe_box/services/recipe_storage_service.dart';
import 'package:recipe_box/services/shopping_list_storage_service.dart';
import 'package:recipe_box/ui/screens/recipe_detail_screen.dart';
import 'package:recipe_box/ui/screens/recipe_edit_screen.dart';
import 'package:recipe_box/ui/screens/cooking_mode_screen.dart';
import 'package:recipe_box/ui/screens/recipe_list_screen.dart';
import 'package:recipe_box/ui/screens/shopping_list_screen.dart';
import 'package:recipe_box/utils/recipe_share_text.dart';
import 'package:recipe_box/utils/shopping_list_share_text.dart';
import 'package:shared_preferences/shared_preferences.dart';

double _contrastRatio(Color first, Color second) {
  final firstLuminance = first.computeLuminance();
  final secondLuminance = second.computeLuminance();
  final lighter = firstLuminance > secondLuminance
      ? firstLuminance
      : secondLuminance;
  final darker = firstLuminance > secondLuminance
      ? secondLuminance
      : firstLuminance;
  return (lighter + 0.05) / (darker + 0.05);
}

void main() {
  testWidgets('shopping list button shows and updates pending item count', (
    tester,
  ) async {
    final shoppingStorage = _MemoryShoppingListStorageService()
      ..items = [
        const ShoppingItem(id: 'pending-1', name: 'Apples', recipeTitle: ''),
        const ShoppingItem(id: 'pending-2', name: 'Milk', recipeTitle: ''),
        const ShoppingItem(
          id: 'bought-1',
          name: 'Bread',
          recipeTitle: '',
          isBought: true,
        ),
      ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          storageServiceProvider.overrideWithValue(
            _MemoryRecipeStorageService([]),
          ),
          shoppingListStorageServiceProvider.overrideWithValue(shoppingStorage),
          weeklyBackupProvider.overrideWith((ref) async {}),
        ],
        child: const MaterialApp(home: RecipeListScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Your recipe box starts here'), findsOneWidget);
    expect(find.byKey(const ValueKey('add-first-recipe')), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(find.byTooltip('Shopping list'), findsOneWidget);
    expect(find.byKey(const ValueKey('shopping-list-button')), findsOneWidget);
    expect(find.byKey(const ValueKey('home-search-heading')), findsOneWidget);
    expect(find.byTooltip('Quick tutorial'), findsOneWidget);
    expect(find.byIcon(Icons.auto_stories_outlined), findsOneWidget);

    await tester.tap(find.byTooltip('Quick tutorial'));
    await tester.pumpAndSettle();
    expect(find.text('Welcome to OpenKuhnya'), findsOneWidget);
    await tester.tap(find.text('Got it'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Shopping list'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Checkbox).first);
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(find.text('1'), findsOneWidget);
  });

  testWidgets('recipe loading errors offer a working retry', (tester) async {
    final storage = _DeferredRecipeStorageService();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          storageServiceProvider.overrideWithValue(storage),
          shoppingListStorageServiceProvider.overrideWithValue(
            _MemoryShoppingListStorageService(),
          ),
          weeklyBackupProvider.overrideWith((ref) async {}),
        ],
        child: const MaterialApp(home: RecipeListScreen()),
      ),
    );
    await tester.pump();

    expect(find.text('Getting your recipes ready'), findsOneWidget);

    storage.firstLoad.completeError(StateError('Storage unavailable'));
    await tester.pumpAndSettle();

    expect(find.text('Your recipes couldn’t be opened'), findsOneWidget);
    expect(find.text('Bad state: Storage unavailable'), findsOneWidget);
    expect(find.byKey(const ValueKey('retry-loading-recipes')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('retry-loading-recipes')));
    await tester.pumpAndSettle();

    expect(find.text('Your recipe box starts here'), findsOneWidget);
  });

  testWidgets('surprise me opens a saved recipe', (tester) async {
    final recipes = [
      Recipe(
        id: 'older-recipe',
        title: 'Older recipe',
        servings: 2,
        createdAt: DateTime.utc(2024),
        updatedAt: DateTime.utc(2024),
      ),
      Recipe(
        id: 'featured-recipe',
        title: 'Latest recipe',
        servings: 2,
        createdAt: DateTime.utc(2025),
        updatedAt: DateTime.utc(2025),
      ),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          storageServiceProvider.overrideWithValue(
            _MemoryRecipeStorageService(recipes),
          ),
          weeklyBackupProvider.overrideWith((ref) async {}),
        ],
        child: const MaterialApp(home: RecipeListScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byKey(const ValueKey('surprise-me-recipe')),
        matching: find.byIcon(Icons.shuffle_rounded),
      ),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('surprise-me-recipe')));
    await tester.pumpAndSettle();
    expect(find.byTooltip('More recipe actions'), findsOneWidget);
  });

  testWidgets('empty recipe box offers add and import actions', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          storageServiceProvider.overrideWithValue(
            _MemoryRecipeStorageService([]),
          ),
          weeklyBackupProvider.overrideWith((ref) async {}),
        ],
        child: const MaterialApp(home: RecipeListScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byKey(const ValueKey('add-first-recipe')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('add-first-recipe')));
    await tester.pumpAndSettle();
    expect(find.text('New recipe'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.ensureVisible(
      find.byKey(const ValueKey('import-first-recipe')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('import-first-recipe')));
    await tester.pumpAndSettle();
    expect(find.text('Import from text'), findsOneWidget);
  });

  testWidgets('ingredient quantity and unit labels fit their fields', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(home: RecipeEditScreen()));
    await tester.pumpAndSettle();

    final quantityField = find.byKey(const ValueKey('ingredient-quantity-0'));
    await tester.ensureVisible(quantityField);
    await tester.tap(quantityField);
    await tester.pumpAndSettle();
    expect(find.text('Quantity'), findsOneWidget);
    expect(tester.getSize(quantityField).width, greaterThanOrEqualTo(120));

    final unitField = find.byKey(const ValueKey('ingredient-unit-0'));
    await tester.ensureVisible(unitField);
    await tester.tap(unitField);
    await tester.pumpAndSettle();
    expect(find.text('Unit'), findsOneWidget);
    expect(tester.getSize(unitField).width, greaterThanOrEqualTo(100));
  });

  testWidgets('ingredient labels remain readable with enlarged text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(2)),
        child: MaterialApp(home: RecipeEditScreen()),
      ),
    );
    await tester.pumpAndSettle();

    final quantityField = find.byKey(const ValueKey('ingredient-quantity-0'));
    await tester.scrollUntilVisible(
      quantityField,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(quantityField);
    await tester.pumpAndSettle();
    await tester.tap(quantityField);
    await tester.pumpAndSettle();

    final unitField = find.byKey(const ValueKey('ingredient-unit-0'));
    await tester.scrollUntilVisible(
      unitField,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(unitField);
    await tester.pumpAndSettle();
    await tester.tap(unitField);
    await tester.pumpAndSettle();

    expect(find.text('Quantity'), findsOneWidget);
    expect(find.text('Unit'), findsOneWidget);
    expect(tester.getSize(quantityField).width, greaterThanOrEqualTo(250));
    expect(tester.getSize(unitField).width, greaterThanOrEqualTo(250));
    expect(tester.takeException(), isNull);
  });

  testWidgets('recipe method steps can be reordered and saved', (tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final storage = _MemoryRecipeStorageService([
      Recipe(
        id: 'recipe-with-steps',
        title: 'Recipe with steps',
        servings: 2,
        steps: const ['First step', 'Second step', 'Third step'],
        createdAt: DateTime.utc(2024),
        updatedAt: DateTime.utc(2024),
      ),
    ]);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [storageServiceProvider.overrideWithValue(storage)],
        child: MaterialApp(
          home: RecipeEditScreen(recipe: storage.recipes.single),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final firstStepHandle = find.byTooltip('Reorder step 1');
    await tester.ensureVisible(firstStepHandle);
    await tester.drag(firstStepHandle, const Offset(0, 160));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('save-recipe-button')));
    await tester.pumpAndSettle();

    expect(storage.recipes.single.steps, [
      'Second step',
      'First step',
      'Third step',
    ]);
  });

  testWidgets('ingredient notes can be edited and saved', (tester) async {
    final storage = _MemoryRecipeStorageService([
      Recipe(
        id: 'recipe-with-note',
        title: 'Tomato soup',
        servings: 2,
        ingredients: const [
          Ingredient(
            name: 'Tomatoes',
            quantity: 2,
            note: 'roughly chopped',
            substitute: 'canned tomatoes',
          ),
        ],
        createdAt: DateTime.utc(2024),
        updatedAt: DateTime.utc(2024),
      ),
    ]);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [storageServiceProvider.overrideWithValue(storage)],
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) =>
                        RecipeEditScreen(recipe: storage.recipes.single),
                  ),
                ),
                child: const Text('Edit recipe'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Edit recipe'));
    await tester.pumpAndSettle();

    final noteFields = find.ancestor(
      of: find.text('Note (optional)'),
      matching: find.byType(TextFormField),
    );
    expect(noteFields, findsOneWidget);
    await tester.enterText(noteFields, 'finely diced');
    final substituteFields = find.ancestor(
      of: find.text('Substitute (optional)'),
      matching: find.byType(TextFormField),
    );
    expect(substituteFields, findsOneWidget);
    await tester.enterText(substituteFields, 'roasted peppers');
    await tester.tap(find.byKey(const ValueKey('save-recipe-button')));
    await tester.pumpAndSettle();
    expect(storage.recipes.single.ingredients.single.note, 'finely diced');
    expect(
      storage.recipes.single.ingredients.single.substitute,
      'roasted peppers',
    );
    expect(
      Recipe.fromJson(storage.recipes.single.toJson())
          .ingredients
          .single
          .substitute,
      'roasted peppers',
    );
  });

  testWidgets('new recipes can include ingredient substitutes', (tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final storage = _MemoryRecipeStorageService([]);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [storageServiceProvider.overrideWithValue(storage)],
        child: const MaterialApp(home: RecipeEditScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).first, 'Tomato soup');
    final ingredientField = find.ancestor(
      of: find.text('Ingredient'),
      matching: find.byType(TextFormField),
    );
    await tester.enterText(ingredientField, 'Tomatoes');
    final substituteField = find.ancestor(
      of: find.text('Substitute (optional)'),
      matching: find.byType(TextFormField),
    );
    await tester.enterText(substituteField, 'canned tomatoes');
    await tester.tap(find.byKey(const ValueKey('save-recipe-button')));
    await tester.pumpAndSettle();

    expect(storage.recipes.single.ingredients.single.name, 'Tomatoes');
    expect(
      storage.recipes.single.ingredients.single.substitute,
      'canned tomatoes',
    );
  });

  testWidgets('dark theme input outlines use a visible color', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: RecipeBoxApp()));

    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    final darkTheme = app.darkTheme!;
    final outline =
        darkTheme.inputDecorationTheme.enabledBorder! as OutlineInputBorder;

    expect(outline.borderSide.color, darkTheme.colorScheme.outline);
    expect(
      darkTheme.inputDecorationTheme.focusedBorder!.borderSide.color,
      darkTheme.colorScheme.primary,
    );
    expect(
      _contrastRatio(outline.borderSide.color, darkTheme.colorScheme.surface),
      greaterThanOrEqualTo(3),
    );
    expect(
      _contrastRatio(
        darkTheme.colorScheme.onSurfaceVariant,
        darkTheme.colorScheme.surface,
      ),
      greaterThanOrEqualTo(4.5),
    );
  });

  test('new theme colors can be selected and saved', () async {
    SharedPreferences.setMockInitialValues({});
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await container.read(appearanceSettingsProvider.future);

    for (final color in [
      ThemeColor.cyan,
      ThemeColor.magenta,
      ThemeColor.yellow,
    ]) {
      await container
          .read(appearanceSettingsProvider.notifier)
          .setThemeColor(color);
      expect(
        container.read(appearanceSettingsProvider).requireValue.themeColor,
        color,
      );
      expect(
        (await SharedPreferences.getInstance()).getString('theme_color'),
        color.name,
      );
    }
  });

  test(
    'automatic weekly backup preference can be disabled persistently',
    () async {
      SharedPreferences.setMockInitialValues({});
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(
        (await container.read(autoBackupSettingsProvider.future)).enabled,
        isTrue,
      );

      await container
          .read(autoBackupSettingsProvider.notifier)
          .setEnabled(false);

      expect(
        container.read(autoBackupSettingsProvider).requireValue.enabled,
        isFalse,
      );
    },
  );

  test('recipe share text includes readable scaled ingredients and method', () {
    final recipe = Recipe(
      id: 'recipe-1',
      title: 'Tomato soup',
      description: 'A simple soup.',
      servings: 2,
      prepMinutes: 10,
      cookMinutes: 30,
      createdAt: DateTime.utc(2024),
      updatedAt: DateTime.utc(2024),
      ingredients: const [
        Ingredient(name: 'Tomatoes', quantity: 2, unit: 'cups'),
        Ingredient(name: 'Salt', note: 'to taste'),
      ],
      steps: const ['Chop tomatoes', 'Simmer until soft'],
    );

    final text = formatRecipeForSharing(
      recipe,
      servings: 3,
      ingredients: recipe.ingredientsFor(3),
    );

    expect(text, contains('Tomato soup\n\nA simple soup.'));
    expect(text, contains('Serves 3'));
    expect(text, contains('Prep: 10 min'));
    expect(text, contains('- 3 cups Tomatoes'));
    expect(text, contains('- Salt (to taste)'));
    expect(text, contains('1. Chop tomatoes\n2. Simmer until soft'));
  });

  testWidgets('recipe detail adds all scaled ingredients to shopping list', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final recipe = Recipe(
      id: 'recipe-1',
      title: 'Tomato soup',
      servings: 2,
      createdAt: DateTime.utc(2024),
      updatedAt: DateTime.utc(2024),
      ingredients: const [
        Ingredient(name: 'Tomatoes', quantity: 2, unit: 'cups'),
        Ingredient(name: 'Salt', note: 'to taste'),
      ],
    );
    final shoppingStorage = _MemoryShoppingListStorageService();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          storageServiceProvider.overrideWithValue(
            _MemoryRecipeStorageService([recipe]),
          ),
          shoppingListStorageServiceProvider.overrideWithValue(shoppingStorage),
        ],
        child: const MaterialApp(
          home: RecipeDetailScreen(recipeId: 'recipe-1'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byTooltip('More recipe actions'), findsOneWidget);
    expect(find.byTooltip('Edit recipe'), findsOneWidget);
    await tester.tap(find.byTooltip('Edit recipe'));
    await tester.pumpAndSettle();
    expect(find.text('Edit recipe'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(find.text('Shopping tip'), findsNothing);
    await tester.tap(find.byTooltip('More servings'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('add-all-recipe-ingredients')));
    await tester.pumpAndSettle();

    expect(shoppingStorage.items, hasLength(2));
    expect(shoppingStorage.items[0].name, 'Tomatoes');
    expect(shoppingStorage.items[0].quantity, 3);
    expect(shoppingStorage.items[0].recipeTitle, 'Tomato soup');
    expect(shoppingStorage.items[1].name, 'Salt');
    expect(shoppingStorage.items[1].note, 'to taste');
    expect(
      find.text('Added 2 ingredients to the shopping list.'),
      findsOneWidget,
    );
  });

  testWidgets('recipe detail presents cooking mode as a primary action', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final recipe = Recipe(
      id: 'cooking-recipe',
      title: 'Tomato soup',
      servings: 2,
      createdAt: DateTime.utc(2024),
      updatedAt: DateTime.utc(2024),
      steps: const ['Chop tomatoes'],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          storageServiceProvider.overrideWithValue(
            _MemoryRecipeStorageService([recipe]),
          ),
        ],
        child: const MaterialApp(
          home: RecipeDetailScreen(recipeId: 'cooking-recipe'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Shopping tip'), findsNothing);

    final cookingButton = find.byKey(const ValueKey('start-cooking-mode'));
    expect(cookingButton, findsOneWidget);
    await tester.tap(cookingButton);
    await tester.pumpAndSettle();
    expect(find.text('Step 1 of 1'), findsOneWidget);
    expect(find.text('Chop tomatoes'), findsOneWidget);
  });

  test('shopping item JSON round-trips its recipe and purchase details', () {
    const item = ShoppingItem(
      id: 'item-1',
      name: 'Tomatoes',
      recipeTitle: 'Tomato soup',
      quantity: 2,
      amountText: '2 large cans',
      unit: 'cups',
      note: 'diced',
      isBought: true,
    );

    expect(ShoppingItem.fromJson(item.toJson()).toJson(), item.toJson());
  });

  test(
    'favorite recipes round-trip through JSON and preserve other fields',
    () {
      final recipe = Recipe(
        id: 'favorite-recipe',
        title: 'Tomato soup',
        servings: 2,
        createdAt: DateTime.utc(2024),
        updatedAt: DateTime.utc(2024),
        tags: const ['soup'],
        steps: const ['Simmer'],
      );

      final favorite = recipe.copyWith(isFavorite: true);
      final restored = Recipe.fromJson(favorite.toJson());

      expect(restored.isFavorite, isTrue);
      expect(restored.title, recipe.title);
      expect(restored.tags, recipe.tags);
      expect(restored.copyWith(isFavorite: false).isFavorite, isFalse);
      expect(Recipe.fromJson(recipe.toJson()).isFavorite, isFalse);
    },
  );

  test(
    'weekly backup creates one rolling backup and skips within a week',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'recipe-weekly-backup-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final storage = RecipeStorageService(directoryOverride: directory);
      final recipe = Recipe(
        id: 'backup-recipe',
        title: 'Tomato soup',
        servings: 2,
        createdAt: DateTime.utc(2024),
        updatedAt: DateTime.utc(2024),
      );

      expect(await storage.weeklyBackupLastModified(), isNull);
      expect(await storage.createWeeklyBackup([recipe]), isTrue);
      final backup = File('${directory.path}/recipes-auto-backup.json');
      final originalContents = await backup.readAsString();
      expect(await storage.weeklyBackupLastModified(), isNotNull);
      expect(storage.parseRecipes(originalContents).single.id, recipe.id);

      expect(
        await storage.createWeeklyBackup([recipe.copyWith(isFavorite: true)]),
        isFalse,
      );
      expect(await backup.readAsString(), originalContents);

      await backup.setLastModified(
        DateTime.now().subtract(const Duration(days: 8)),
      );
      expect(
        await storage.createWeeklyBackup([recipe.copyWith(isFavorite: true)]),
        isTrue,
      );
      expect(
        storage.parseRecipes(await backup.readAsString()).single.isFavorite,
        isTrue,
      );
    },
  );

  test(
    'weekly backup restore replaces recipes and preserves a safety copy',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'recipe-weekly-restore-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final storage = RecipeStorageService(directoryOverride: directory);
      final current = Recipe(
        id: 'current-recipe',
        title: 'Current recipe',
        servings: 2,
        createdAt: DateTime.utc(2024),
        updatedAt: DateTime.utc(2024),
      );
      final saved = Recipe(
        id: 'saved-recipe',
        title: 'Saved recipe',
        servings: 2,
        createdAt: DateTime.utc(2024),
        updatedAt: DateTime.utc(2024),
      );
      await storage.saveAll([current]);
      await storage.createWeeklyBackup([saved]);

      final restored = await storage.restoreWeeklyBackup();

      expect(restored.map((recipe) => recipe.id), ['saved-recipe']);
      expect((await storage.loadAll()).map((recipe) => recipe.id), [
        'saved-recipe',
      ]);
      final safetyCopy = File('${directory.path}/recipes.json.bak');
      expect(
        storage.parseRecipes(await safetyCopy.readAsString()).single.id,
        'current-recipe',
      );
    },
  );

  test(
    'weekly backup restore rejects a missing backup without changing recipes',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'recipe-weekly-restore-missing-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final storage = RecipeStorageService(directoryOverride: directory);
      final current = Recipe(
        id: 'current-recipe',
        title: 'Current recipe',
        servings: 2,
        createdAt: DateTime.utc(2024),
        updatedAt: DateTime.utc(2024),
      );
      await storage.saveAll([current]);

      await expectLater(
        storage.restoreWeeklyBackup(),
        throwsA(isA<RecipeImportException>()),
      );
      expect((await storage.loadAll()).single.id, 'current-recipe');
    },
  );

  testWidgets('cooking mode advances through steps and finishes', (
    tester,
  ) async {
    final recipe = Recipe(
      id: 'cooking-recipe',
      title: 'Tomato soup',
      servings: 2,
      createdAt: DateTime.utc(2024),
      updatedAt: DateTime.utc(2024),
      steps: const ['Chop tomatoes', 'Simmer until soft'],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => CookingModeScreen(recipe: recipe),
                  ),
                ),
                child: const Text('Open cooking mode'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open cooking mode'));
    await tester.pumpAndSettle();
    expect(find.text('Step 1 of 2'), findsOneWidget);
    expect(find.text('Chop tomatoes'), findsOneWidget);

    await tester.tap(find.text('1 min'));
    await tester.pump();
    expect(find.byTooltip('Pause timer'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) => widget is Text && widget.data == '01:00',
      ),
      findsOneWidget,
    );
    await tester.tap(find.byTooltip('Pause timer'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));
    expect(
      find.byWidgetPredicate(
        (widget) => widget is Text && widget.data == '01:00',
      ),
      findsOneWidget,
    );
    await tester.tap(find.byTooltip('Resume timer'));
    await tester.pump();
    expect(find.byTooltip('Pause timer'), findsOneWidget);

    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.text('Step 2 of 2'), findsOneWidget);
    expect(find.text('Simmer until soft'), findsOneWidget);
    expect(find.text('1 min'), findsOneWidget);

    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(find.text('Open cooking mode'), findsOneWidget);
  });

  testWidgets('recipe browsing filters favorites and quick recipes', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final recipes = [
      Recipe(
        id: 'quick-favorite',
        title: 'Carrot soup',
        servings: 2,
        prepMinutes: 10,
        cookMinutes: 10,
        tags: const ['Dinner'],
        isFavorite: true,
        createdAt: DateTime.utc(2024),
        updatedAt: DateTime.utc(2024),
      ),
      Recipe(
        id: 'slow-recipe',
        title: 'Roast vegetables',
        servings: 4,
        prepMinutes: 20,
        cookMinutes: 45,
        tags: const ['Dinner'],
        createdAt: DateTime.utc(2024),
        updatedAt: DateTime.utc(2024),
      ),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          storageServiceProvider.overrideWithValue(
            _MemoryRecipeStorageService(recipes),
          ),
          weeklyBackupProvider.overrideWith((ref) async {}),
        ],
        child: const MaterialApp(home: RecipeListScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('all-recipes-header')), findsOneWidget);
    expect(find.text('All recipes'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('all-recipes-header')),
        matching: find.text('2'),
      ),
      findsOneWidget,
    );
    expect(find.text('Carrot soup'), findsOneWidget);
    expect(find.text('Roast vegetables'), findsOneWidget);
    expect(find.text('Serves 2'), findsOneWidget);
    expect(find.text('Total 20 min'), findsOneWidget);
    expect(find.text('Dinner'), findsNWidgets(2));
    expect(
      tester.getSize(find.byTooltip('Add to favorites')).height,
      greaterThanOrEqualTo(48),
    );

    await tester.enterText(find.byType(EditableText).first, 'carrot');
    await tester.pumpAndSettle();
    expect(find.text('Carrot soup'), findsOneWidget);
    expect(find.text('Roast vegetables'), findsNothing);
    await tester.tap(find.byTooltip('Clear search'));
    await tester.pumpAndSettle();
    expect(find.text('Carrot soup'), findsOneWidget);
    expect(find.text('Roast vegetables'), findsOneWidget);

    expect(find.widgetWithText(FilterChip, 'Favorites'), findsNothing);
    await tester.tap(find.byTooltip('Filters'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilterChip, 'Favorites'));
    await tester.pumpAndSettle();
    expect(find.text('Carrot soup'), findsOneWidget);
    expect(find.text('Roast vegetables'), findsNothing);
    expect(find.text('Matching recipes'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilterChip, 'Under 30 min'));
    await tester.pumpAndSettle();
    expect(find.text('Carrot soup'), findsOneWidget);
    expect(find.text('Roast vegetables'), findsNothing);
    await tester.enterText(find.byType(EditableText).first, 'carrot');
    await tester.pumpAndSettle();

    final activeFilters = find.byType(InputChip);
    expect(find.byKey(const ValueKey('active-filter-search')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('active-filter-favorites')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('active-filter-quick')), findsOneWidget);

    await tester.tap(find.text('Clear all'));
    await tester.pumpAndSettle();

    expect(activeFilters, findsNothing);
    expect(find.text('Carrot soup'), findsOneWidget);
    expect(find.text('Roast vegetables'), findsOneWidget);

    await tester.enterText(find.byType(EditableText).first, 'unmatched');
    await tester.pumpAndSettle();
    expect(find.text('No results for “unmatched”'), findsOneWidget);
    await tester.tap(find.text('Clear search and filters'));
    await tester.pumpAndSettle();
    expect(find.text('Carrot soup'), findsOneWidget);
    expect(find.text('Roast vegetables'), findsOneWidget);
  });

  testWidgets('recipe list and editor support enlarged text', (tester) async {
    tester.view.physicalSize = const Size(400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final recipe = Recipe(
      id: 'accessible-recipe',
      title: 'A very long recipe title that should remain readable',
      servings: 2,
      prepMinutes: 10,
      cookMinutes: 15,
      createdAt: DateTime.utc(2024),
      updatedAt: DateTime.utc(2024),
    );
    const largeText = MediaQuery(
      data: MediaQueryData(textScaler: TextScaler.linear(2)),
      child: MaterialApp(home: RecipeListScreen()),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          storageServiceProvider.overrideWithValue(
            _MemoryRecipeStorageService([recipe]),
          ),
          weeklyBackupProvider.overrideWith((ref) async {}),
        ],
        child: largeText,
      ),
    );
    final layoutError = tester.takeException();
    expect(layoutError, isNull);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.scrollUntilVisible(
      find.text('Serves 2'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Serves 2'), findsOneWidget);

    await tester.pumpWidget(
      ProviderScope(
        key: const ValueKey('recipe-editor-large-text'),
        child: const MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(2)),
          child: MaterialApp(home: RecipeEditScreen()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final editorLayoutError = tester.takeException();
    expect(editorLayoutError, isNull);
    expect(find.byType(TextFormField), findsWidgets);
    expect(find.text('Title'), findsOneWidget);
    expect(find.text('Prep time (min)'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Describe this step'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(tester.takeException(), isNull);
    expect(find.text('Describe this step'), findsOneWidget);
    expect(find.text('Save recipe'), findsOneWidget);
    expect(
      tester.getRect(find.byKey(const ValueKey('save-recipe-button'))).bottom,
      lessThanOrEqualTo(tester.view.physicalSize.height),
    );
  });

  testWidgets('quick actions close on navigation and scrolling', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final recipes = List.generate(
      15,
      (index) => Recipe(
        id: 'recipe-$index',
        title: 'Recipe $index',
        servings: 2,
        description: 'A recipe that fills space in the scrollable list.',
        createdAt: DateTime.utc(2024),
        updatedAt: DateTime.utc(2024),
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          storageServiceProvider.overrideWithValue(
            _MemoryRecipeStorageService(recipes),
          ),
          weeklyBackupProvider.overrideWith((ref) async {}),
        ],
        child: const MaterialApp(home: RecipeListScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Add or import recipe'));
    await tester.pumpAndSettle();
    expect(find.text('Add new recipe'), findsOneWidget);

    await tester.tap(find.text('Recipe 0').first);
    await tester.pumpAndSettle();
    expect(find.text('Recipe 0'), findsWidgets);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byTooltip('Add or import recipe'), findsOneWidget);
    expect(find.text('Add new recipe'), findsNothing);
    expect(find.text('Recently viewed'), findsOneWidget);

    expect(find.text('OPEN AGAIN'), findsNothing);
    await tester.tap(find.byTooltip('Expand recently viewed'));
    await tester.pumpAndSettle();
    expect(find.text('OPEN AGAIN'), findsOneWidget);

    await tester.tap(find.byTooltip('Minimize recently viewed'));
    await tester.pumpAndSettle();
    expect(find.text('OPEN AGAIN'), findsNothing);

    await tester.tap(find.byTooltip('Add or import recipe'));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -500));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Add or import recipe'), findsOneWidget);
    expect(find.text('Add new recipe'), findsNothing);
  });

  testWidgets('recipe browsing combines tag and available ingredient filters', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final recipes = [
      Recipe(
        id: 'tomato-rice',
        title: 'Tomato rice',
        servings: 2,
        ingredients: const [
          Ingredient(name: 'Tomato'),
          Ingredient(name: 'Rice'),
        ],
        tags: const ['Dinner', 'Vegetarian'],
        createdAt: DateTime.utc(2024),
        updatedAt: DateTime.utc(2024),
      ),
      Recipe(
        id: 'chicken-rice',
        title: 'Chicken rice',
        servings: 2,
        ingredients: const [
          Ingredient(name: 'Chicken'),
          Ingredient(name: 'Rice'),
        ],
        tags: const ['Dinner', 'Meat'],
        createdAt: DateTime.utc(2024),
        updatedAt: DateTime.utc(2024),
      ),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          storageServiceProvider.overrideWithValue(
            _MemoryRecipeStorageService(recipes),
          ),
          weeklyBackupProvider.overrideWith((ref) async {}),
        ],
        child: const MaterialApp(home: RecipeListScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Filters'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.widgetWithText(FilterChip, 'Dinner'));
    await tester.tap(find.widgetWithText(FilterChip, 'Dinner'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.widgetWithText(FilterChip, 'Vegetarian'));
    await tester.tap(find.widgetWithText(FilterChip, 'Vegetarian'));
    await tester.pumpAndSettle();

    expect(find.text('Tomato rice'), findsOneWidget);
    expect(find.text('Chicken rice'), findsNothing);

    await tester.tap(find.widgetWithText(FilterChip, 'Vegetarian'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('available-ingredients-filter')),
      'tomato',
    );
    await tester.pumpAndSettle();

    final activeFilters = find.byKey(const ValueKey('active-filters'));
    expect(
      find.byKey(const ValueKey('active-filter-tag-dinner')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('active-filter-ingredient-tomato')),
      findsOneWidget,
    );
    expect(find.text('Tomato rice'), findsOneWidget);
    expect(find.text('Chicken rice'), findsNothing);

    await tester.enterText(
      find.byKey(const ValueKey('available-ingredients-filter')),
      'tomato, chicken',
    );
    await tester.pumpAndSettle();
    expect(find.text('Tomato rice'), findsOneWidget);
    expect(find.text('Chicken rice'), findsOneWidget);
    await tester.tap(
      find.descendant(
        of: find.byKey(const ValueKey('available-ingredients-match-mode')),
        matching: find.text('All'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('No recipes match those filters'), findsOneWidget);
    await tester.tap(
      find.descendant(
        of: find.byKey(const ValueKey('available-ingredients-match-mode')),
        matching: find.text('Any'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Tomato rice'), findsOneWidget);
    expect(find.text('Chicken rice'), findsOneWidget);

    await tester.tap(find.text('Clear all'));
    await tester.pumpAndSettle();

    expect(activeFilters, findsNothing);
    expect(find.text('Tomato rice'), findsOneWidget);
    expect(find.text('Chicken rice'), findsOneWidget);
    expect(
      tester
          .widget<TextField>(
            find.byKey(const ValueKey('available-ingredients-filter')),
          )
          .controller!
          .text,
      isEmpty,
    );
  });

  test(
    'shopping list share text includes amounts, notes, and bought status',
    () {
      const items = [
        ShoppingItem(
          id: 'item-1',
          name: 'Tomatoes',
          recipeTitle: '',
          quantity: 1.5,
          unit: 'cups',
        ),
        ShoppingItem(
          id: 'item-2',
          name: 'Salt',
          recipeTitle: '',
          note: 'to taste',
          isBought: true,
        ),
      ];

      expect(
        formatShoppingListForSharing(items),
        'Shopping List\n\n- [ ] 1½ cups Tomatoes\n- [x] Salt (to taste)',
      );
    },
  );

  test('shopping list combines saved duplicates when loading', () async {
    final storage = _MemoryShoppingListStorageService()
      ..items = [
        const ShoppingItem(
          id: 'item-1',
          name: 'Tomatoes',
          recipeTitle: 'Soup',
          quantity: 2,
          unit: 'cups',
        ),
        const ShoppingItem(
          id: 'item-2',
          name: ' tomatoes ',
          recipeTitle: 'Salad',
          quantity: 1,
          unit: 'CUPS',
        ),
      ];
    final container = ProviderContainer(
      overrides: [
        shoppingListStorageServiceProvider.overrideWithValue(storage),
      ],
    );
    addTearDown(container.dispose);

    final items = await container.read(shoppingListProvider.future);

    expect(items, hasLength(1));
    expect(items.single.quantity, 3);
    expect(items.single.recipeTitle, 'Soup · Salad');
    expect(storage.items, hasLength(1));
  });

  test('marking an item bought moves it to the bottom', () async {
    final storage = _MemoryShoppingListStorageService()
      ..items = const [
        ShoppingItem(id: 'apples', name: 'Apples', recipeTitle: ''),
        ShoppingItem(
          id: 'bread',
          name: 'Bread',
          recipeTitle: '',
          isBought: true,
        ),
        ShoppingItem(id: 'milk', name: 'Milk', recipeTitle: ''),
      ];
    final container = ProviderContainer(
      overrides: [
        shoppingListStorageServiceProvider.overrideWithValue(storage),
      ],
    );
    addTearDown(container.dispose);

    final loadedItems = await container.read(shoppingListProvider.future);
    expect(loadedItems.map((item) => item.name), ['Apples', 'Milk', 'Bread']);
    await container.read(shoppingListProvider.notifier).setBought('milk', true);

    final items = container.read(shoppingListProvider).value!;
    expect(items.map((item) => item.name), ['Apples', 'Bread', 'Milk']);
    expect(storage.items.map((item) => item.name), ['Apples', 'Bread', 'Milk']);
  });

  testWidgets(
    'shopping list combines duplicate ingredients with matching units',
    (tester) async {
      final storage = _MemoryShoppingListStorageService();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            shoppingListStorageServiceProvider.overrideWithValue(storage),
          ],
          child: const MaterialApp(home: _ShoppingListHarness()),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Add duplicates'));
      await tester.pumpAndSettle();

      expect(find.text('Items: 2'), findsOneWidget);
      expect(storage.items.map((item) => item.quantity), [3, 1]);
      expect(storage.items.map((item) => item.unit), ['cups', 'g']);
    },
  );

  testWidgets(
    'shopping list supports adding, marking bought, and removing items',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            shoppingListStorageServiceProvider.overrideWithValue(
              _MemoryShoppingListStorageService(),
            ),
          ],
          child: const MaterialApp(home: _ShoppingListHarness()),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Add'));
      await tester.pumpAndSettle();
      expect(find.text('Items: 1'), findsOneWidget);
      expect(find.text('Tomatoes'), findsOneWidget);

      await tester.tap(find.text('Mark bought'));
      await tester.pumpAndSettle();
      expect(find.text('Bought'), findsOneWidget);

      await tester.tap(find.text('Clear bought'));
      await tester.pumpAndSettle();
      expect(find.text('Items: 0'), findsOneWidget);

      await tester.tap(find.text('Add'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Remove'));
      await tester.pumpAndSettle();
      expect(find.text('Items: 0'), findsOneWidget);
    },
  );

  testWidgets('shopping list items can be reordered and saved', (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final storage = _MemoryShoppingListStorageService()
      ..items = const [
        ShoppingItem(id: 'apples', name: 'Apples', recipeTitle: ''),
        ShoppingItem(id: 'milk', name: 'Milk', recipeTitle: ''),
        ShoppingItem(id: 'bread', name: 'Bread', recipeTitle: ''),
      ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          shoppingListStorageServiceProvider.overrideWithValue(storage),
        ],
        child: const MaterialApp(home: ShoppingListScreen()),
      ),
    );
    await tester.pumpAndSettle();

    final applesCard = find.ancestor(
      of: find.text('Apples'),
      matching: find.byType(Card),
    );
    final milkCard = find.ancestor(
      of: find.text('Milk'),
      matching: find.byType(Card),
    );
    expect(
      tester.getTopLeft(milkCard).dy - tester.getBottomLeft(applesCard).dy,
      8,
    );

    await tester.drag(find.byTooltip('Reorder Apples'), const Offset(0, 200));
    await tester.pumpAndSettle();

    expect(storage.items.map((item) => item.name), ['Milk', 'Apples', 'Bread']);
  });

  testWidgets('shopping list scrolls normally when swiping over an item', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(400, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final storage = _MemoryShoppingListStorageService()
      ..items = List.generate(
        20,
        (index) => ShoppingItem(
          id: 'item-$index',
          name: 'Ingredient $index',
          recipeTitle: '',
        ),
      );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          shoppingListStorageServiceProvider.overrideWithValue(storage),
        ],
        child: const MaterialApp(home: ShoppingListScreen()),
      ),
    );
    await tester.pumpAndSettle();

    final scrollable = find.byType(Scrollable).first;
    await tester.scrollUntilVisible(
      find.text('Ingredient 0'),
      200,
      scrollable: scrollable,
    );
    await tester.drag(find.text('Ingredient 0'), const Offset(0, -1200));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Ingredient 19'),
      200,
      scrollable: scrollable,
    );

    expect(find.text('Ingredient 19'), findsOneWidget);
    expect(
      tester.state<ScrollableState>(scrollable).position.pixels,
      greaterThan(0),
    );
  });

  testWidgets('shopping list page allows manually adding an amount and name', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          shoppingListStorageServiceProvider.overrideWithValue(
            _MemoryShoppingListStorageService(),
          ),
        ],
        child: const MaterialApp(home: ShoppingListScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Shopping tip'), findsNothing);

    await tester.enterText(
      find.byKey(const ValueKey('shopping-amount')),
      '1 1/2',
    );
    await tester.enterText(find.byKey(const ValueKey('shopping-unit')), 'cups');
    await tester.enterText(
      find.byKey(const ValueKey('shopping-ingredient-name')),
      'Tomatoes',
    );
    await tester.tap(find.byKey(const ValueKey('add-shopping-ingredient')));
    await tester.pumpAndSettle();

    expect(find.text('Shopping tip'), findsNothing);

    expect(find.text('1 1/2 cups Tomatoes'), findsOneWidget);
    expect(find.text('From '), findsNothing);
    expect(find.text('Your list is empty'), findsNothing);
    expect(find.byTooltip('Share shopping list as text'), findsOneWidget);
    await tester.tap(find.byType(Checkbox));
    await tester.pumpAndSettle();
    expect(find.text('Shopping tip'), findsNothing);

    await tester.tap(find.byTooltip('Edit Tomatoes'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('edit-shopping-amount')),
      '3',
    );
    await tester.enterText(
      find.byKey(const ValueKey('edit-shopping-unit')),
      'small tins',
    );
    await tester.enterText(
      find.byKey(const ValueKey('edit-shopping-name')),
      'Cherry tomatoes',
    );
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('3 small tins Cherry tomatoes'), findsOneWidget);
    expect(find.text('Tomatoes'), findsNothing);
  });

  testWidgets('shopping list supports undoing remove and clearing bought', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final storage = _MemoryShoppingListStorageService()
      ..items = const [ShoppingItem(id: 'milk', name: 'Milk', recipeTitle: '')];
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          shoppingListStorageServiceProvider.overrideWithValue(storage),
        ],
        child: const MaterialApp(home: ShoppingListScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Remove Milk'));
    await tester.pumpAndSettle();
    expect(find.text('Milk'), findsNothing);
    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(find.text('Milk'), findsOneWidget);

    await tester.tap(find.byType(Checkbox));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilterChip, 'Hide bought'));
    await tester.pumpAndSettle();
    expect(find.text('All caught up'), findsOneWidget);
    await tester.tap(find.text('Show bought items'));
    await tester.pumpAndSettle();
    expect(find.text('Milk'), findsOneWidget);

    await tester.tap(find.byTooltip('Clear bought items'));
    await tester.pumpAndSettle();
    expect(find.text('Milk'), findsNothing);
    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(find.text('Milk'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shopping item actions fit small screens with large text', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final storage = _MemoryShoppingListStorageService()
      ..items = const [
        ShoppingItem(
          id: 'ingredient',
          name: 'A very long ingredient name that wraps onto multiple lines',
          recipeTitle: 'A recipe with a long title',
          quantity: 2,
          unit: 'large cups',
        ),
      ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          shoppingListStorageServiceProvider.overrideWithValue(storage),
        ],
        child: const MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(2)),
          child: MaterialApp(home: ShoppingListScreen()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byTooltip(
        'Edit A very long ingredient name that wraps onto multiple lines',
      ),
      200,
      scrollable: find.byType(Scrollable).first,
    );

    expect(
      find.byTooltip(
        'Edit A very long ingredient name that wraps onto multiple lines',
      ),
      findsOneWidget,
    );
    expect(
      find.byTooltip(
        'Remove A very long ingredient name that wraps onto multiple lines',
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('shopping list add form adapts to enlarged text', (tester) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          shoppingListStorageServiceProvider.overrideWithValue(
            _MemoryShoppingListStorageService(),
          ),
        ],
        child: const MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(2)),
          child: MaterialApp(home: ShoppingListScreen()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('shopping-amount')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.enterText(find.byKey(const ValueKey('shopping-amount')), '2');
    await tester.enterText(
      find.byKey(const ValueKey('shopping-ingredient-name')),
      'Apples',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Add'));
    await tester.pumpAndSettle();

    expect(find.text('2 Apples'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _ShoppingListHarness extends ConsumerWidget {
  const _ShoppingListHarness();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(shoppingListProvider).value ?? const [];
    final item = items.firstOrNull;

    return Scaffold(
      body: Column(
        children: [
          Text('Items: ${items.length}'),
          if (item != null) ...[
            Text(item.name),
            TextButton(
              onPressed: () => ref
                  .read(shoppingListProvider.notifier)
                  .setBought(item.id, true),
              child: Text(item.isBought ? 'Bought' : 'Mark bought'),
            ),
            TextButton(
              onPressed: () =>
                  ref.read(shoppingListProvider.notifier).remove(item.id),
              child: const Text('Remove'),
            ),
          ],
          TextButton(
            onPressed: () => ref
                .read(shoppingListProvider.notifier)
                .addIngredient(
                  const Ingredient(name: 'Tomatoes', quantity: 2, unit: 'cups'),
                  recipeTitle: 'Tomato soup',
                ),
            child: const Text('Add'),
          ),
          TextButton(
            onPressed: () =>
                ref.read(shoppingListProvider.notifier).addIngredients(const [
                  Ingredient(name: 'Tomatoes', quantity: 2, unit: 'cups'),
                  Ingredient(name: ' tomatoes ', quantity: 1, unit: 'cups'),
                  Ingredient(name: 'Tomatoes', quantity: 1, unit: 'g'),
                ], recipeTitle: 'Tomato soup'),
            child: const Text('Add duplicates'),
          ),
          TextButton(
            onPressed: () =>
                ref.read(shoppingListProvider.notifier).clearBought(),
            child: const Text('Clear bought'),
          ),
        ],
      ),
    );
  }
}

class _MemoryShoppingListStorageService extends ShoppingListStorageService {
  List<ShoppingItem> items = [];

  @override
  Future<List<ShoppingItem>> loadAll() async => items;

  @override
  Future<void> saveAll(List<ShoppingItem> items) async {
    this.items = List.of(items);
  }
}

class _MemoryRecipeStorageService extends RecipeStorageService {
  _MemoryRecipeStorageService(this.recipes);

  List<Recipe> recipes;

  @override
  Future<List<Recipe>> loadAll() async => recipes;

  @override
  Future<void> saveAll(List<Recipe> recipes) async {
    this.recipes = List.of(recipes);
  }
}

class _DeferredRecipeStorageService extends RecipeStorageService {
  final firstLoad = Completer<List<Recipe>>();
  var _loadCount = 0;

  @override
  Future<List<Recipe>> loadAll() {
    _loadCount++;
    if (_loadCount == 1) return firstLoad.future;
    return Future.value([]);
  }
}
