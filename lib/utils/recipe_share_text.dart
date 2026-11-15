import '../models/ingredient.dart';
import '../models/recipe.dart';
import 'quantity_format.dart';

String formatRecipeForSharing(
  Recipe recipe, {
  required int servings,
  required List<Ingredient> ingredients,
}) {
  final lines = <String>[
    recipe.title,
    if (recipe.description.isNotEmpty) ...['', recipe.description],
    '',
    'Serves $servings',
    if (recipe.prepMinutes != null)
      'Prep: ${formatMinutes(recipe.prepMinutes!)}',
    if (recipe.cookMinutes != null)
      'Cook: ${formatMinutes(recipe.cookMinutes!)}',
    '',
    'Ingredients',
    for (final ingredient in ingredients) '- ${_formatIngredient(ingredient)}',
    if (recipe.steps.isNotEmpty) ...[
      '',
      'Method',
      for (var index = 0; index < recipe.steps.length; index++)
        '${index + 1}. ${recipe.steps[index]}',
    ],
  ];

  return lines.join('\n');
}

String _formatIngredient(Ingredient ingredient) {
  final amount = ingredient.quantity == null
      ? ''
      : [
          formatQuantity(ingredient.quantity!),
          if (ingredient.unit.isNotEmpty) ingredient.unit,
        ].join(' ');
  final notes = [
    if (ingredient.note.isNotEmpty) ingredient.note,
    if (ingredient.substitute.isNotEmpty)
      'substitute: ${ingredient.substitute}',
  ];
  final note = notes.isEmpty ? '' : ' (${notes.join('; ')})';
  return [if (amount.isNotEmpty) amount, '${ingredient.name}$note'].join(' ');
}
