import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/recipe_text_parser.dart';
import '../widgets/app_spacing.dart';
import 'recipe_edit_screen.dart';

class RecipeSharedImportScreen extends StatefulWidget {
  const RecipeSharedImportScreen({super.key});

  @override
  State<RecipeSharedImportScreen> createState() =>
      _RecipeSharedImportScreenState();
}

class _RecipeSharedImportScreenState extends State<RecipeSharedImportScreen> {
  final _sharedRecipeText = TextEditingController();
  final _parser = const RecipeTextParser();
  String? _message;

  @override
  void dispose() {
    _sharedRecipeText.dispose();
    super.dispose();
  }

  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (!mounted) return;
    final text = data?.text;
    if (text == null || text.trim().isEmpty) {
      setState(() => _message = 'Your clipboard does not contain any text.');
      return;
    }
    setState(() {
      _sharedRecipeText.text = text;
      _message = null;
    });
  }

  Future<void> _reviewRecipe() async {
    final recipe = _parser.parse(_sharedRecipeText.text);
    if (recipe == null ||
        (recipe.ingredients.isEmpty && recipe.steps.isEmpty)) {
      setState(
        () => _message =
            'Could not find a recipe. Paste the text shared from a recipe.',
      );
      return;
    }

    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(builder: (_) => RecipeEditScreen(recipe: recipe)),
    );
    if (saved == true && mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Import shared recipe')),
      body: ListView(
        padding: AppSpacing.pageInsets,
        children: [
          Card.filled(
            color: Theme.of(context).colorScheme.surfaceContainerLow,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: _sharedRecipeText,
                minLines: 8,
                maxLines: 16,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  hintText: 'Paste the shared recipe here',
                  alignLabelWithHint: true,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: _paste,
              icon: const Icon(Icons.content_paste),
              label: const Text('Paste'),
            ),
          ),
          if (_message != null) ...[
            const SizedBox(height: 12),
            Text(
              _message!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          const SizedBox(height: AppSpacing.section),
          FilledButton.icon(
            onPressed: _reviewRecipe,
            icon: const Icon(Icons.rate_review_outlined),
            label: const Text('Review recipe'),
          ),
        ],
      ),
    );
  }
}
