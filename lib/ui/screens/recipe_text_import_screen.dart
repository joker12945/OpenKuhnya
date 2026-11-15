import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/ingredient.dart';
import '../../models/recipe.dart';
import '../../services/recipe_text_parser.dart';
import '../../utils/quantity_format.dart';
import '../widgets/app_spacing.dart';
import '../widgets/section_heading.dart';
import 'recipe_edit_screen.dart';

class RecipeTextImportScreen extends StatefulWidget {
  const RecipeTextImportScreen({super.key});

  @override
  State<RecipeTextImportScreen> createState() => _RecipeTextImportScreenState();
}

class _RecipeTextImportScreenState extends State<RecipeTextImportScreen> {
  final _title = TextEditingController();
  final _servings = TextEditingController(text: '4');
  final _ingredientText = TextEditingController();
  final _methodText = TextEditingController();
  final _parser = const RecipeTextParser();
  final _ingredients = <Ingredient>[];
  final _steps = <String>[];
  String? _message;

  @override
  void dispose() {
    _title.dispose();
    _servings.dispose();
    _ingredientText.dispose();
    _methodText.dispose();
    super.dispose();
  }

  Future<void> _pasteInto(TextEditingController controller) async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (!mounted) return;
    final text = data?.text;
    if (text == null || text.trim().isEmpty) {
      setState(() => _message = 'Your clipboard does not contain any text.');
      return;
    }
    setState(() {
      controller.text = text;
      _message = null;
    });
  }

  void _extractIngredients() {
    final extracted = _parser.parseIngredientText(_ingredientText.text);
    if (extracted.isEmpty) {
      setState(() => _message = 'Add ingredient text before extracting.');
      return;
    }
    setState(() {
      _ingredients.addAll(extracted);
      _ingredientText.clear();
      _message = null;
    });
  }

  void _extractMethods() {
    final extracted = _parser.parseMethodText(_methodText.text);
    if (extracted.isEmpty) {
      setState(() => _message = 'Add method text before extracting.');
      return;
    }
    setState(() {
      _steps.addAll(extracted);
      _methodText.clear();
      _message = null;
    });
  }

  Future<void> _preview() async {
    final title = _title.text.trim();
    final servings = int.tryParse(_servings.text.trim());
    if (title.isEmpty || servings == null || servings < 1) {
      setState(() => _message = 'Enter a title and a valid serving count.');
      return;
    }
    if (_ingredients.isEmpty && _steps.isEmpty) {
      setState(
        () => _message = 'Extract at least one ingredient or method step.',
      );
      return;
    }

    final recipe = Recipe.create(
      title: title,
      servings: servings,
      ingredients: List.of(_ingredients),
      steps: List.of(_steps),
    );
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => _RecipeTextPreviewScreen(recipe: recipe),
      ),
    );
    if (saved == true && mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Import from text')),
      body: ListView(
        padding: AppSpacing.pageInsets,
        children: [
          Card.outlined(
            margin: EdgeInsets.zero,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(28),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SectionHeading(
                    title: 'Recipe details',
                    icon: Icons.description_outlined,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _title,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      labelText: 'Recipe title',
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: 130,
                    child: TextField(
                      controller: _servings,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Servings'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.section),
          _InputSection(
            title: 'Ingredients',
            hint: 'Example:\n2 eggs\n\n1 cup flour\n\nSalt to taste',
            helper: 'Separate each ingredient with a blank line.',
            controller: _ingredientText,
            onPaste: () => _pasteInto(_ingredientText),
            onExtract: _extractIngredients,
            extractLabel: 'Extract text to ingredients',
          ),
          if (_ingredients.isNotEmpty) ...[
            const SizedBox(height: 8),
            _ExtractedList<Ingredient>(
              items: _ingredients,
              label: (ingredient) => _formatIngredient(ingredient),
              onRemove: (ingredient) =>
                  setState(() => _ingredients.remove(ingredient)),
            ),
          ],
          const SizedBox(height: AppSpacing.section),
          _InputSection(
            title: 'Method',
            hint: 'Example:\nBeat the eggs.\n\nCook in a hot pan.',
            helper: 'Separate each step with a blank line.',
            controller: _methodText,
            onPaste: () => _pasteInto(_methodText),
            onExtract: _extractMethods,
            extractLabel: 'Extract text to methods',
          ),
          if (_steps.isNotEmpty) ...[
            const SizedBox(height: 8),
            _ExtractedList<String>(
              items: _steps,
              label: (step) => step,
              onRemove: (step) => setState(() => _steps.remove(step)),
            ),
          ],
          if (_message != null) ...[
            const SizedBox(height: 12),
            Text(
              _message!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          const SizedBox(height: AppSpacing.section),
          FilledButton.icon(
            onPressed: _preview,
            icon: const Icon(Icons.visibility_outlined),
            label: const Text('Preview recipe'),
          ),
        ],
      ),
    );
  }

  String _formatIngredient(Ingredient ingredient) {
    final amount = ingredient.quantity == null
        ? ''
        : '${formatQuantity(ingredient.quantity!)} ';
    final unit = ingredient.unit.isEmpty ? '' : '${ingredient.unit} ';
    final note = ingredient.note.isEmpty ? '' : ' (${ingredient.note})';
    return '$amount$unit${ingredient.name}$note';
  }
}

class _InputSection extends StatelessWidget {
  const _InputSection({
    required this.title,
    required this.hint,
    required this.helper,
    required this.controller,
    required this.onPaste,
    required this.onExtract,
    required this.extractLabel,
  });

  final String title;
  final String hint;
  final String helper;
  final TextEditingController controller;
  final VoidCallback onPaste;
  final VoidCallback onExtract;
  final String extractLabel;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeading(
          title: title,
          icon: title == 'Ingredients'
              ? Icons.checklist
              : Icons.menu_book_outlined,
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          minLines: 4,
          maxLines: 10,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(
            hintText: hint,
            helperText: helper,
            alignLabelWithHint: true,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: onPaste,
              icon: const Icon(Icons.content_paste),
              label: const Text('Paste'),
            ),
            FilledButton.tonalIcon(
              onPressed: onExtract,
              icon: const Icon(Icons.playlist_add),
              label: Text(extractLabel),
            ),
          ],
        ),
      ],
    );
  }
}

class _ExtractedList<T> extends StatelessWidget {
  const _ExtractedList({
    required this.items,
    required this.label,
    required this.onRemove,
  });

  final List<T> items;
  final String Function(T item) label;
  final ValueChanged<T> onRemove;

  @override
  Widget build(BuildContext context) {
    return Card.outlined(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Column(
        children: [
          for (final item in items)
            ListTile(
              dense: true,
              title: Text(label(item)),
              trailing: IconButton(
                tooltip: 'Remove',
                onPressed: () => onRemove(item),
                icon: const Icon(Icons.close),
              ),
            ),
        ],
      ),
    );
  }
}

class _RecipeTextPreviewScreen extends StatelessWidget {
  const _RecipeTextPreviewScreen({required this.recipe});

  final Recipe recipe;

  Future<void> _editAndSave(BuildContext context) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(builder: (_) => RecipeEditScreen(recipe: recipe)),
    );
    if (saved == true && context.mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Preview recipe'),
        actions: [
          IconButton(
            tooltip: 'Edit and save recipe',
            onPressed: () => _editAndSave(context),
            icon: const Icon(Icons.edit_outlined),
          ),
        ],
      ),
      body: ListView(
        padding: AppSpacing.pageInsets,
        children: [
          Text(
            recipe.title,
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          if (recipe.description.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              recipe.description,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
          ],
          const SizedBox(height: 8),
          Text(
            'Serves ${recipe.servings}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.section),
          SectionHeading(
            title: 'Ingredients',
            icon: Icons.checklist,
            trailing: Text(
              '${recipe.ingredients.length}',
              style: theme.textTheme.labelLarge?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(height: 8),
          if (recipe.ingredients.isEmpty)
            Text(
              'No ingredients listed.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
          for (final ingredient in recipe.ingredients)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 9),
                    child: Icon(Icons.circle, size: 6, color: colors.primary),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text.rich(
                      TextSpan(
                        children: [
                          if (ingredient.quantity != null) ...[
                            TextSpan(
                              text: [
                                formatQuantity(ingredient.quantity!),
                                if (ingredient.unit.isNotEmpty) ingredient.unit,
                              ].join(' '),
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: colors.primary,
                              ),
                            ),
                            const TextSpan(text: ' '),
                          ],
                          TextSpan(text: ingredient.name),
                          if (ingredient.note.isNotEmpty)
                            TextSpan(
                              text: ', ${ingredient.note}',
                              style: TextStyle(color: colors.onSurfaceVariant),
                            ),
                        ],
                      ),
                      style: theme.textTheme.bodyLarge,
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: AppSpacing.section),
          SectionHeading(
            title: 'Method',
            icon: Icons.menu_book_outlined,
            trailing: Text(
              '${recipe.steps.length} steps',
              style: theme.textTheme.labelLarge?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(height: 8),
          if (recipe.steps.isEmpty)
            Text(
              'No steps listed.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
          for (var index = 0; index < recipe.steps.length; index++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 13,
                    backgroundColor: colors.primaryContainer,
                    child: Text(
                      '${index + 1}',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: colors.onPrimaryContainer,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      recipe.steps[index],
                      style: theme.textTheme.bodyLarge?.copyWith(height: 1.45),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () => _editAndSave(context),
            icon: const Icon(Icons.edit_outlined),
            label: const Text('Edit and save recipe'),
          ),
        ],
      ),
    );
  }
}
