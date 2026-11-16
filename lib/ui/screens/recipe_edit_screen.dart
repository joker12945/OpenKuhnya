import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/ingredient.dart';
import '../../models/recipe.dart';
import '../../providers/recipe_providers.dart';
import '../../utils/quantity_format.dart';
import '../widgets/app_spacing.dart';
import '../widgets/section_heading.dart';
import '../widgets/section_panel.dart';

class _IngredientFields {
  _IngredientFields([Ingredient? i])
    : qty = TextEditingController(text: _qtyText(i)),
      unit = TextEditingController(text: i?.unit ?? ''),
      name = TextEditingController(text: i?.name ?? ''),
      note = TextEditingController(text: i?.note ?? ''),
      substitute = TextEditingController(text: i?.substitute ?? '');

  final TextEditingController qty;
  final TextEditingController unit;
  final TextEditingController name;
  final TextEditingController note;
  final TextEditingController substitute;

  static String _qtyText(Ingredient? i) {
    final q = i?.quantity;
    return q == null ? '' : formatNumber(q);
  }

  void dispose() {
    qty.dispose();
    unit.dispose();
    name.dispose();
    note.dispose();
    substitute.dispose();
  }
}

class RecipeEditScreen extends ConsumerStatefulWidget {
  const RecipeEditScreen({super.key, this.recipe});

  /// Null = create a new recipe.
  final Recipe? recipe;

  @override
  ConsumerState<RecipeEditScreen> createState() => _RecipeEditScreenState();
}

class _RecipeEditScreenState extends ConsumerState<RecipeEditScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _title;
  late final TextEditingController _desc;
  late final TextEditingController _servings;
  late final TextEditingController _prep;
  late final TextEditingController _cook;
  late final TextEditingController _tags;
  final List<_IngredientFields> _ings = [];
  final List<TextEditingController> _steps = [];

  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final r = widget.recipe;
    _title = TextEditingController(text: r?.title ?? '');
    _desc = TextEditingController(text: r?.description ?? '');
    _servings = TextEditingController(text: '${r?.servings ?? 4}');
    _prep = TextEditingController(text: r?.prepMinutes?.toString() ?? '');
    _cook = TextEditingController(text: r?.cookMinutes?.toString() ?? '');
    _tags = TextEditingController(text: r?.tags.join(', ') ?? '');

    if (r != null) {
      _ings.addAll(r.ingredients.map(_IngredientFields.new));
      _steps.addAll(r.steps.map((s) => TextEditingController(text: s)));
    }
    if (_ings.isEmpty) _ings.add(_IngredientFields());
    if (_steps.isEmpty) _steps.add(TextEditingController());
  }

  @override
  void dispose() {
    for (final c in [_title, _desc, _servings, _prep, _cook, _tags]) {
      c.dispose();
    }
    for (final f in _ings) {
      f.dispose();
    }
    for (final c in _steps) {
      c.dispose();
    }
    super.dispose();
  }

  void _removeIngredient(_IngredientFields f) {
    setState(() => _ings.remove(f));
    WidgetsBinding.instance.addPostFrameCallback((_) => f.dispose());
  }

  void _removeStep(TextEditingController c) {
    setState(() => _steps.remove(c));
    WidgetsBinding.instance.addPostFrameCallback((_) => c.dispose());
  }

  void _reorderStep(int oldIndex, int newIndex) {
    setState(() {
      final step = _steps.removeAt(oldIndex);
      _steps.insert(newIndex, step);
    });
  }

  String? _optionalInt(String? v) {
    final t = (v ?? '').trim();
    if (t.isEmpty) return null;
    final n = int.tryParse(t);
    return (n == null || n < 0) ? 'Enter a whole number 0 or greater' : null;
  }

  Future<void> _save() async {
    if (_saving || !_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final ingredients = _ings
        .where((f) => f.name.text.trim().isNotEmpty)
        .map(
          (f) => Ingredient(
            name: f.name.text.trim(),
            quantity: parseQuantity(f.qty.text),
            unit: f.unit.text.trim(),
            note: f.note.text.trim(),
            substitute: f.substitute.text.trim(),
          ),
        )
        .toList();
    final steps = _steps
        .map((c) => c.text.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    final tags = _tags.text
        .split(',')
        .map((t) => t.trim())
        .where((t) => t.isNotEmpty)
        .toList();
    final servings = int.parse(_servings.text.trim());
    final prep = int.tryParse(_prep.text.trim());
    final cook = int.tryParse(_cook.text.trim());

    final existing = widget.recipe;
    final recipe = existing == null
        ? Recipe.create(
            title: _title.text.trim(),
            description: _desc.text.trim(),
            servings: servings,
            prepMinutes: prep,
            cookMinutes: cook,
            ingredients: ingredients,
            steps: steps,
            tags: tags,
          )
        : Recipe(
            id: existing.id,
            createdAt: existing.createdAt,
            updatedAt: DateTime.now().toUtc(),
            title: _title.text.trim(),
            description: _desc.text.trim(),
            servings: servings,
            prepMinutes: prep,
            cookMinutes: cook,
            ingredients: ingredients,
            steps: steps,
            tags: tags,
            isFavorite: existing.isFavorite,
          );

    try {
      await ref.read(recipesProvider.notifier).upsert(recipe);
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not save the recipe.')),
      );
    }
  }

  InputDecoration _dec(String label, {String? helperText}) => InputDecoration(
    labelText: label,
    helperText: helperText,
    floatingLabelBehavior: FloatingLabelBehavior.always,
    isDense: true,
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isNew = widget.recipe == null;

    return Scaffold(
      appBar: AppBar(title: Text(isNew ? 'New recipe' : 'Edit recipe')),
      bottomNavigationBar: SafeArea(
        top: false,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            border: Border(
              top: BorderSide(color: theme.colorScheme.outlineVariant),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.pageGutter),
            child: FilledButton(
              key: const ValueKey('save-recipe-button'),
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(isNew ? 'Save recipe' : 'Save changes'),
            ),
          ),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.pageGutter,
            AppSpacing.pageTop,
            AppSpacing.pageGutter,
            AppSpacing.pageGutter,
          ),
          children: [
            SectionPanel(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.panel),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SectionHeading(
                      title: 'Recipe details',
                      icon: Icons.description_outlined,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _title,
                      decoration: _dec('Title'),
                      textCapitalization: TextCapitalization.sentences,
                      validator: (v) => (v ?? '').trim().isEmpty
                          ? 'Enter a recipe title'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _desc,
                      decoration: _dec('Description'),
                      textCapitalization: TextCapitalization.sentences,
                      minLines: 2,
                      maxLines: 4,
                    ),
                    const SizedBox(height: 12),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final useCompactRow =
                            constraints.maxWidth >= 500 &&
                            MediaQuery.textScalerOf(context).scale(16) < 20;
                        final fields = [
                          TextFormField(
                            controller: _servings,
                            decoration: _dec('Servings'),
                            keyboardType: TextInputType.number,
                            validator: (v) {
                              final n = int.tryParse((v ?? '').trim());
                              return (n == null || n < 1)
                                  ? 'Enter at least 1 serving'
                                  : null;
                            },
                          ),
                          TextFormField(
                            controller: _prep,
                            decoration: _dec('Prep time (min)'),
                            keyboardType: TextInputType.number,
                            validator: _optionalInt,
                          ),
                          TextFormField(
                            controller: _cook,
                            decoration: _dec('Cook time (min)'),
                            keyboardType: TextInputType.number,
                            validator: _optionalInt,
                          ),
                        ];
                        if (!useCompactRow) {
                          return Column(
                            children: [
                              for (
                                var index = 0;
                                index < fields.length;
                                index++
                              )
                                Padding(
                                  padding: EdgeInsets.only(
                                    bottom: index == fields.length - 1 ? 0 : 12,
                                  ),
                                  child: fields[index],
                                ),
                            ],
                          );
                        }
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            for (var index = 0; index < fields.length; index++)
                              Expanded(
                                child: Padding(
                                  padding: EdgeInsets.only(
                                    right: index == fields.length - 1 ? 0 : 12,
                                  ),
                                  child: fields[index],
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _tags,
                      decoration: _dec(
                        'Tags',
                        helperText: 'Separate with commas',
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.section),
            SectionPanel(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.panel),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SectionHeading(
                      title: 'Ingredients',
                      icon: Icons.checklist,
                      trailing: Text(
                        '${_ings.length} ${_ings.length == 1 ? 'item' : 'items'}',
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Quantities accept 2, 0.5, 1/2, 1 1/2 or ½. Leave empty for “to taste”.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 12),
                    for (var index = 0; index < _ings.length; index++)
                      _ingredientRow(_ings[index], index),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: () =>
                            setState(() => _ings.add(_IngredientFields())),
                        icon: const Icon(Icons.add),
                        label: const Text('Add ingredient'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.section),
            SectionPanel(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.panel),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SectionHeading(
                      title: 'Method',
                      icon: Icons.menu_book_outlined,
                      trailing: Text(
                        '${_steps.length} ${_steps.length == 1 ? 'step' : 'steps'}',
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    ReorderableListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      buildDefaultDragHandles: false,
                      itemCount: _steps.length,
                      onReorderItem: _reorderStep,
                      itemBuilder: (context, index) =>
                          _stepRow(index, _steps[index]),
                    ),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: () =>
                            setState(() => _steps.add(TextEditingController())),
                        icon: const Icon(Icons.add),
                        label: const Text('Add step'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _ingredientRow(_IngredientFields f, int index) {
    final qtyField = TextFormField(
      key: ValueKey('ingredient-quantity-$index'),
      controller: f.qty,
      decoration: _dec('Quantity'),
      validator: (v) {
        final t = (v ?? '').trim();
        return (t.isEmpty || parseQuantity(t) != null)
            ? null
            : 'Enter a valid amount or fraction';
      },
    );
    final unitField = TextFormField(
      key: ValueKey('ingredient-unit-$index'),
      controller: f.unit,
      decoration: _dec('Unit'),
    );
    final nameField = TextFormField(
      controller: f.name,
      decoration: _dec('Ingredient'),
      textCapitalization: TextCapitalization.sentences,
      validator: (v) {
        if ((v ?? '').trim().isNotEmpty) return null;
        final other =
            f.qty.text.trim().isNotEmpty || f.unit.text.trim().isNotEmpty;
        final hasSubstitute = f.substitute.text.trim().isNotEmpty;
        return other || hasSubstitute ? 'Enter an ingredient name' : null;
      },
    );
    final noteField = TextFormField(
      key: ValueKey('ingredient-note-${identityHashCode(f)}'),
      controller: f.note,
      decoration: _dec('Note (optional)'),
      textCapitalization: TextCapitalization.sentences,
    );
    final substituteField = TextFormField(
      key: ValueKey('ingredient-substitute-${identityHashCode(f)}'),
      controller: f.substitute,
      decoration: _dec('Substitute (optional)'),
      textCapitalization: TextCapitalization.sentences,
    );
    final removeButton = IconButton(
      tooltip: 'Remove ingredient',
      icon: const Icon(Icons.close),
      onPressed: () => _removeIngredient(f),
    );

    return Padding(
      key: ObjectKey(f),
      padding: const EdgeInsets.only(bottom: 10),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final useStackedMeasurementFields =
              constraints.maxWidth < 360 ||
              MediaQuery.textScalerOf(context).scale(16) >= 24;
          final useCompactRow =
              constraints.maxWidth >= 620 &&
              MediaQuery.textScalerOf(context).scale(16) < 20;
          if (useStackedMeasurementFields) {
            return Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: qtyField),
                    removeButton,
                  ],
                ),
                const SizedBox(height: 8),
                unitField,
                const SizedBox(height: 8),
                nameField,
                const SizedBox(height: 8),
                noteField,
                const SizedBox(height: 8),
                substituteField,
              ],
            );
          }
          if (!useCompactRow) {
            return Column(
              children: [
                Row(
                  children: [
                    Expanded(child: qtyField),
                    const SizedBox(width: 8),
                    Expanded(child: unitField),
                    removeButton,
                  ],
                ),
                const SizedBox(height: 8),
                nameField,
                const SizedBox(height: 8),
                noteField,
                const SizedBox(height: 8),
                substituteField,
              ],
            );
          }
          return Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(width: 128, child: qtyField),
                  const SizedBox(width: 8),
                  SizedBox(width: 112, child: unitField),
                  const SizedBox(width: 8),
                  Expanded(child: nameField),
                  removeButton,
                ],
              ),
              const SizedBox(height: 8),
              noteField,
              const SizedBox(height: 8),
              substituteField,
            ],
          );
        },
      ),
    );
  }

  Widget _stepRow(int index, TextEditingController c) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      key: ObjectKey(c),
      padding: const EdgeInsets.only(bottom: 10),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final stackControls =
              constraints.maxWidth < 360 ||
              MediaQuery.textScalerOf(context).scale(16) >= 24;
          final stepField = TextFormField(
            controller: c,
            decoration: _dec('Describe this step'),
            textCapitalization: TextCapitalization.sentences,
            minLines: 1,
            maxLines: 6,
          );
          final controls = Row(
            children: [
              CircleAvatar(
                radius: 13,
                backgroundColor: cs.primaryContainer,
                child: Text(
                  '${index + 1}',
                  style: TextStyle(fontSize: 12, color: cs.onPrimaryContainer),
                ),
              ),
              const SizedBox(width: 8),
              ReorderableDragStartListener(
                index: index,
                child: SizedBox(
                  width: 40,
                  height: 48,
                  child: Center(
                    child: Tooltip(
                      message: 'Reorder step ${index + 1}',
                      child: Icon(
                        Icons.drag_handle,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
              ),
              const Spacer(),
              IconButton(
                tooltip: 'Remove step',
                icon: const Icon(Icons.close),
                onPressed: () => _removeStep(c),
              ),
            ],
          );
          if (stackControls) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [controls, stepField],
            );
          }
          return Row(
            children: [
              CircleAvatar(
                radius: 13,
                backgroundColor: cs.primaryContainer,
                child: Text(
                  '${index + 1}',
                  style: TextStyle(fontSize: 12, color: cs.onPrimaryContainer),
                ),
              ),
              const SizedBox(width: 8),
              ReorderableDragStartListener(
                index: index,
                child: SizedBox(
                  width: 40,
                  height: 48,
                  child: Center(
                    child: Tooltip(
                      message: 'Reorder step ${index + 1}',
                      child: Icon(
                        Icons.drag_handle,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(child: stepField),
              IconButton(
                tooltip: 'Remove step',
                icon: const Icon(Icons.close),
                onPressed: () => _removeStep(c),
              ),
            ],
          );
        },
      ),
    );
  }
}
