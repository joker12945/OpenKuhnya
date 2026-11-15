import 'package:flutter_test/flutter_test.dart';
import 'package:recipe_box/models/ingredient.dart';
import 'package:recipe_box/models/recipe.dart';
import 'package:recipe_box/services/recipe_text_parser.dart';
import 'package:recipe_box/utils/recipe_share_text.dart';

void main() {
  const parser = RecipeTextParser();

  test('extracts title, servings, ingredients, and numbered steps', () {
    final recipe = parser.parse('''
Tomato pasta
A quick weeknight dinner.
Serves 2

Ingredients:
200 g pasta
1 ½ cups tomato sauce
Salt to taste

Instructions:
1. Boil the pasta.
2. Stir in the sauce and serve.
''');

    expect(recipe, isNotNull);
    expect(recipe!.title, 'Tomato pasta');
    expect(recipe.description, 'A quick weeknight dinner.');
    expect(recipe.servings, 2);
    expect(recipe.ingredients, hasLength(3));
    expect(recipe.ingredients[0].quantity, 200);
    expect(recipe.ingredients[0].unit, 'g');
    expect(recipe.ingredients[0].name, 'pasta');
    expect(recipe.ingredients[1].quantity, 1.5);
    expect(recipe.ingredients[1].unit, 'cups');
    expect(recipe.ingredients[1].name, 'tomato sauce');
    expect(recipe.ingredients[2].name, 'Salt to taste');
    expect(recipe.steps, ['Boil the pasta.', 'Stir in the sauce and serve.']);
  });

  test('recognizes headings embedded in copied text', () {
    final recipe = parser.parse(
      'Pancakes Ingredients: 1 cup flour, 1 egg Instructions: Mix and cook.',
    );

    expect(recipe, isNotNull);
    expect(recipe!.title, 'Pancakes');
    expect(recipe.ingredients, hasLength(2));
    expect(recipe.ingredients.first.name, 'flour');
    expect(recipe.steps, ['Mix and cook.']);
  });

  test('extracts a whole recipe without blank lines between items', () {
    final recipe = parser.parse('''
Tomato pasta
Serves 2
Ingredients:
200 g pasta
1 tbsp olive oil
Salt to taste
Instructions:
Boil the pasta.
Stir in the oil and serve.
''');

    expect(recipe, isNotNull);
    expect(recipe!.title, 'Tomato pasta');
    expect(recipe.servings, 2);
    expect(recipe.ingredients, hasLength(3));
    expect(recipe.ingredients[0].name, 'pasta');
    expect(recipe.ingredients[1].name, 'olive oil');
    expect(recipe.ingredients[2].name, 'Salt to taste');
    expect(recipe.steps, ['Boil the pasta.', 'Stir in the oil and serve.']);
  });

  test('extracts metadata and ingredient notes from shared recipe text', () {
    final sharedText = formatRecipeForSharing(
      Recipe.create(
        title: 'Tomato pasta',
        servings: 2,
        description: 'A quick weeknight dinner.',
        prepMinutes: 20,
        cookMinutes: 75,
        ingredients: const [
          Ingredient(
            quantity: 1,
            unit: 'tbsp',
            name: 'olive oil',
            note: 'extra virgin',
            substitute: 'avocado oil',
          ),
          Ingredient(name: 'Salt to taste'),
        ],
        steps: const ['Boil the pasta.'],
      ),
      servings: 2,
      ingredients: const [
        Ingredient(
          quantity: 1,
          unit: 'tbsp',
          name: 'olive oil',
          note: 'extra virgin',
          substitute: 'avocado oil',
        ),
        Ingredient(name: 'Salt to taste'),
      ],
    );
    final recipe = parser.parse(sharedText);

    expect(recipe, isNotNull);
    expect(recipe!.title, 'Tomato pasta');
    expect(recipe.description, 'A quick weeknight dinner.');
    expect(recipe.servings, 2);
    expect(recipe.prepMinutes, 20);
    expect(recipe.cookMinutes, 75);
    expect(recipe.ingredients[0].name, 'olive oil');
    expect(recipe.ingredients[0].note, 'extra virgin');
    expect(recipe.ingredients[0].substitute, 'avocado oil');
    expect(recipe.ingredients[1].name, 'Salt to taste');
    expect(recipe.steps, ['Boil the pasta.']);
  });

  test('uses plain text paragraphs as method steps', () {
    final recipe = parser.parse(
      'Simple soup\nChop the vegetables. Simmer them until tender.',
    );

    expect(recipe, isNotNull);
    expect(recipe!.title, 'Simple soup');
    expect(recipe.steps, ['Chop the vegetables.', 'Simmer them until tender.']);
  });

  test('keeps unclassified text in the description', () {
    final recipe = parser.parse('''
Grandma's stew
A comforting family favorite for cold evenings.
Best served with crusty bread.
''');

    expect(recipe, isNotNull);
    expect(recipe!.title, "Grandma's stew");
    expect(
      recipe.description,
      'A comforting family favorite for cold evenings. '
      'Best served with crusty bread.',
    );
    expect(recipe.ingredients, isEmpty);
    expect(recipe.steps, isEmpty);
  });

  test('recognizes unheaded bullet ingredients and numbered steps', () {
    final recipe = parser.parse('''
Quick omelette
- 2 eggs
- Butter
1. Beat the eggs.
2. Cook in a hot pan.
''');

    expect(recipe, isNotNull);
    expect(recipe!.ingredients, hasLength(2));
    expect(recipe.ingredients.first.name, 'eggs');
    expect(recipe.ingredients.first.quantity, 2);
    expect(recipe.ingredients.last.name, 'Butter');
    expect(recipe.steps, ['Beat the eggs.', 'Cook in a hot pan.']);
  });

  test('splits extracted ingredients and methods on blank lines', () {
    final ingredients = parser.parseIngredientText('''
- 2 eggs

- 1 cup flour
''');
    final steps = parser.parseMethodText(
      'Beat the eggs.\n\nCook until golden.',
    );

    expect(ingredients, hasLength(2));
    expect(ingredients.first.name, 'eggs');
    expect(ingredients.first.quantity, 2);
    expect(steps, ['Beat the eggs.', 'Cook until golden.']);
  });

  test('keeps wrapped lines in one blank-line-separated item', () {
    final ingredients = parser.parseIngredientText(
      '2 cups all-purpose\nflour\n\n3 eggs',
    );
    final steps = parser.parseMethodText(
      'Mix the flour and eggs\nuntil just combined.\n\nCook until golden.',
    );

    expect(ingredients, hasLength(2));
    expect(ingredients.first.name, 'all-purpose flour');
    expect(steps, [
      'Mix the flour and eggs until just combined.',
      'Cook until golden.',
    ]);
  });

  test('returns null for empty input', () {
    expect(parser.parse(' \n '), isNull);
  });
}
