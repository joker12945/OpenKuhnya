import '../models/ingredient.dart';
import '../models/recipe.dart';
import '../utils/quantity_format.dart';

class RecipeTextParser {
  const RecipeTextParser();

  static final _sectionHeadings = RegExp(
    r"\b(ingredients?|what you'll need|what you’ll need|you will need|"
    r'instructions?|directions|method|steps?|how to make)\s*:',
    caseSensitive: false,
  );

  static final _servingsPattern = RegExp(
    r'^\s*(?:serves?|yield(?:s)?|makes?)\s*:?\s*(\d+)\b',
    caseSensitive: false,
  );

  static final _timePattern = RegExp(
    r'^\s*(prep|cook)(?: time)?\s*:?\s*'
    r'(?:(\d+)\s*(?:h|hr|hrs|hours?)\s*)?'
    r'(?:(\d+)\s*(?:m|min|mins|minutes?)\s*)?$',
    caseSensitive: false,
  );

  static final _quantityPattern = RegExp(
    r'^((?:\d+\s+\d+/\d+)|(?:\d+\s*[½⅓⅔¼¾⅛⅜⅝])|(?:\d+/\d+)|'
    r'(?:\d+(?:[.,]\d+)?)|'
    r'[½⅓⅔¼¾⅛⅜⅝])\s*(.*)$',
  );

  static const _units = {
    'g',
    'kg',
    'mg',
    'ml',
    'l',
    'tsp',
    'teaspoon',
    'teaspoons',
    'tbsp',
    'tablespoon',
    'tablespoons',
    'cup',
    'cups',
    'oz',
    'ounce',
    'ounces',
    'lb',
    'lbs',
    'pound',
    'pounds',
    'pinch',
    'clove',
    'cloves',
    'can',
    'cans',
    'slice',
    'slices',
  };

  static const _instructionVerbs = {
    'add',
    'bake',
    'beat',
    'boil',
    'bring',
    'chop',
    'combine',
    'cook',
    'cover',
    'drain',
    'fold',
    'heat',
    'mix',
    'pour',
    'preheat',
    'reduce',
    'remove',
    'roast',
    'serve',
    'simmer',
    'slice',
    'stir',
    'transfer',
    'whisk',
  };

  Recipe? parse(String text) {
    final normalized = text
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n')
        .replaceAllMapped(
          _sectionHeadings,
          (match) => '\n${match.group(1)}:\n',
        );
    final lines = normalized
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
    if (lines.isEmpty) return null;

    var title = '';
    var servings = 4;
    int? prepMinutes;
    int? cookMinutes;
    var section = _Section.other;
    final ingredients = <Ingredient>[];
    final steps = <String>[];
    final otherLines = <String>[];

    for (final line in lines) {
      final heading = _headingFor(line);
      if (heading != null) {
        section = heading;
        continue;
      }

      final servingMatch = _servingsPattern.firstMatch(line);
      if (servingMatch != null) {
        servings = int.tryParse(servingMatch.group(1)!) ?? servings;
        continue;
      }

      final timeMatch = _timePattern.firstMatch(line);
      if (timeMatch != null &&
          (timeMatch.group(2) != null || timeMatch.group(3) != null)) {
        final minutes =
            (int.tryParse(timeMatch.group(2) ?? '') ?? 0) * 60 +
            (int.tryParse(timeMatch.group(3) ?? '') ?? 0);
        if (timeMatch.group(1)!.toLowerCase() == 'prep') {
          prepMinutes = minutes;
        } else {
          cookMinutes = minutes;
        }
        continue;
      }

      if (title.isEmpty && section == _Section.other && !_isPageNoise(line)) {
        title = _cleanLine(line);
        continue;
      }

      switch (section) {
        case _Section.ingredients:
          for (final item in _splitIngredients(line)) {
            final ingredient = _parseIngredient(item);
            if (ingredient != null) ingredients.add(ingredient);
          }
          break;
        case _Section.steps:
          steps.addAll(_splitSteps(line));
          break;
        case _Section.other:
          if (_looksLikeIngredient(line)) {
            for (final item in _splitIngredients(line)) {
              final ingredient = _parseIngredient(item);
              if (ingredient != null) ingredients.add(ingredient);
            }
          } else if (_looksLikeStep(line)) {
            steps.addAll(_splitSteps(line));
          } else {
            otherLines.add(_cleanLine(line));
          }
          break;
      }
    }

    if (title.isEmpty) title = 'Imported recipe';

    return Recipe.create(
      title: title,
      servings: servings < 1 ? 4 : servings,
      description: otherLines.join(' '),
      prepMinutes: prepMinutes,
      cookMinutes: cookMinutes,
      ingredients: ingredients,
      steps: steps,
    );
  }

  List<Ingredient> parseIngredientText(String text) =>
      _paragraphs(text).map(_parseIngredient).whereType<Ingredient>().toList();

  List<String> parseMethodText(String text) =>
      _paragraphs(text)
          .map(_cleanLine)
          .where((step) => step.isNotEmpty)
          .toList();

  List<String> _paragraphs(String text) => text
      .replaceAll('\r\n', '\n')
      .replaceAll('\r', '\n')
      .split(RegExp(r'\n\s*\n+'))
      .map(
        (paragraph) => paragraph
            .split('\n')
            .map((line) => line.trim())
            .where((line) => line.isNotEmpty)
            .join(' '),
      )
      .where((paragraph) => paragraph.isNotEmpty)
      .toList();

  _Section? _headingFor(String line) {
    final heading = line
        .replaceAll(RegExp(r'[:\s]+$'), '')
        .toLowerCase()
        .replaceAll('’', "'");
    if (const {
      'ingredient',
      'ingredients',
      "what you'll need",
      'you will need',
    }.contains(heading)) {
      return _Section.ingredients;
    }
    if (const {
      'instruction',
      'instructions',
      'direction',
      'directions',
      'method',
      'step',
      'steps',
      'how to make',
    }.contains(heading)) {
      return _Section.steps;
    }
    return null;
  }

  bool _isPageNoise(String line) {
    final lower = line.toLowerCase();
    return lower.startsWith('http') ||
        const {
          'jump to recipe',
          'print recipe',
          'ingredients',
          'instructions',
          'directions',
          'method',
          'steps',
        }.contains(lower);
  }

  String _cleanLine(String line) =>
      line.replaceFirst(RegExp(r'^\s*(?:[-*•]|\d+[.)])\s*'), '').trim();

  bool _looksLikeIngredient(String line) {
    if (_quantityPattern.hasMatch(_cleanLine(line))) return true;
    final isBullet = RegExp(r'^\s*[-*•]\s+').hasMatch(line);
    final cleaned = _cleanLine(line);
    final firstWord = cleaned.toLowerCase().split(RegExp(r'\s+')).first;
    return isBullet &&
        !_instructionVerbs.contains(firstWord) &&
        !cleaned.contains(RegExp(r'[.!?]')) &&
        cleaned.split(RegExp(r'\s+')).length <= 8;
  }

  bool _looksLikeStep(String line) {
    if (RegExp(r'^\s*\d+[.)]\s*').hasMatch(line)) return true;
    final cleaned = _cleanLine(line).toLowerCase();
    if (cleaned.isEmpty) return false;
    return _instructionVerbs.contains(cleaned.split(RegExp(r'\s+')).first);
  }

  List<String> _splitIngredients(String line) {
    final cleaned = _cleanLine(line);
    if (cleaned.isEmpty) return const [];
    return cleaned
        .split(RegExp(r';(?![^()]*\))|,(?=\s*(?:\d|[½⅓⅔¼¾⅛⅜⅝]))'))
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .toList();
  }

  Ingredient? _parseIngredient(String text) {
    var line = _cleanLine(text).replaceFirst(RegExp(r'\.$'), '').trim();
    if (line.isEmpty) return null;
    final noteMatch = RegExp(r'\s+\(([^()]*)\)\s*$').firstMatch(line);
    var note = noteMatch?.group(1) ?? '';
    var substitute = '';
    final substituteMatch = RegExp(
      r'(?:^|;\s*)substitute:\s*(.+)$',
      caseSensitive: false,
    ).firstMatch(note);
    if (substituteMatch != null) {
      substitute = substituteMatch.group(1)!.trim();
      note = note
          .substring(0, substituteMatch.start)
          .replaceFirst(RegExp(r';\s*$'), '');
    }
    if (noteMatch != null) line = line.substring(0, noteMatch.start).trim();
    final quantityMatch = _quantityPattern.firstMatch(line);
    if (quantityMatch == null) {
      return Ingredient(name: line, note: note, substitute: substitute);
    }

    final quantity = parseQuantity(quantityMatch.group(1)!);
    final remainder = quantityMatch.group(2)!.trim();
    if (remainder.isEmpty) return null;

    final firstSpace = remainder.indexOf(RegExp(r'\s'));
    final firstWord =
        (firstSpace < 0 ? remainder : remainder.substring(0, firstSpace))
            .toLowerCase()
            .replaceAll('.', '');
    final hasUnit = _units.contains(firstWord);
    if (hasUnit && firstSpace < 0) return null;
    return Ingredient(
      quantity: quantity,
      unit: hasUnit ? firstWord : '',
      name: hasUnit && firstSpace >= 0
          ? remainder.substring(firstSpace).trim()
          : hasUnit
          ? firstWord
          : remainder,
      note: note,
      substitute: substitute,
    );
  }

  List<String> _splitSteps(String line) {
    final cleaned = _cleanLine(line);
    if (cleaned.isEmpty) return const [];
    final sentenceParts = cleaned
        .split(RegExp(r'(?<=[.!?])\s+(?=[A-Z0-9])'))
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .toList();
    return sentenceParts;
  }
}

enum _Section { other, ingredients, steps }
