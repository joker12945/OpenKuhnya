import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../models/shopping_item.dart';
import '../../providers/shopping_list_provider.dart';
import '../../utils/quantity_format.dart';
import '../../utils/shopping_list_share_text.dart';
import '../widgets/app_spacing.dart';
import '../widgets/section_heading.dart';
import '../widgets/section_panel.dart';

class ShoppingListScreen extends ConsumerStatefulWidget {
  const ShoppingListScreen({super.key});

  @override
  ConsumerState<ShoppingListScreen> createState() => _ShoppingListScreenState();
}

class _ShoppingListScreenState extends ConsumerState<ShoppingListScreen> {
  bool _hideBought = false;
  final _manualFormKey = GlobalKey();

  void _scrollToAddForm() {
    final formContext = _manualFormKey.currentContext;
    if (formContext == null) return;
    unawaited(
      Scrollable.ensureVisible(
        formContext,
        duration: const Duration(milliseconds: 250),
        alignment: 0.15,
      ),
    );
  }

  void _showError(BuildContext context, Object error) {
    _showListMessage(
      context,
      'Could not update the list: $error',
      isError: true,
    );
  }

  void _showUndo(
    BuildContext context,
    String message,
    Future<void> Function() undo,
  ) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () => unawaited(
            undo().catchError((error) {
              if (context.mounted) _showError(context, error);
            }),
          ),
        ),
      ),
    );
  }

  Future<void> _removeItem(
    BuildContext context,
    WidgetRef ref,
    ShoppingItem item,
    int index,
  ) async {
    try {
      await ref.read(shoppingListProvider.notifier).remove(item.id);
      if (context.mounted) {
        _showUndo(
          context,
          'Removed ${item.name}.',
          () => ref
              .read(shoppingListProvider.notifier)
              .restoreItem(item, index: index),
        );
      }
    } catch (error) {
      if (context.mounted) _showError(context, error);
    }
  }

  Future<void> _clearBought(
    BuildContext context,
    WidgetRef ref,
    List<ShoppingItem> items,
  ) async {
    final bought = items.where((item) => item.isBought).toList();
    if (bought.isEmpty) return;
    try {
      await ref.read(shoppingListProvider.notifier).clearBought();
      if (context.mounted) {
        _showUndo(
          context,
          'Cleared ${bought.length} bought ${bought.length == 1 ? 'item' : 'items'}.',
          () => ref.read(shoppingListProvider.notifier).restoreItems(bought),
        );
      }
    } catch (error) {
      if (context.mounted) _showError(context, error);
    }
  }

  Future<void> _editItem(
    BuildContext context,
    WidgetRef ref,
    ShoppingItem item,
  ) async {
    final changes =
        await showDialog<({String name, String amount, String unit})>(
          context: context,
          builder: (_) => _EditShoppingItemDialog(item: item),
        );
    if (changes == null || !context.mounted) return;

    try {
      await ref
          .read(shoppingListProvider.notifier)
          .updateItem(
            item.id,
            name: changes.name,
            amountText: changes.amount,
            unit: changes.unit,
          );
    } catch (error) {
      if (context.mounted) _showError(context, error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final itemsAsync = ref.watch(shoppingListProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Shopping List'),
        actions: [
          itemsAsync.maybeWhen(
            data: (items) => Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (items.isNotEmpty)
                  IconButton(
                    tooltip: 'Share shopping list as text',
                    onPressed: () async {
                      try {
                        await SharePlus.instance.share(
                          ShareParams(
                            text: formatShoppingListForSharing(items),
                            subject: 'Shopping List',
                          ),
                        );
                      } catch (error) {
                        if (context.mounted) {
                          _showError(context, error);
                        }
                      }
                    },
                    icon: const Icon(Icons.share_outlined),
                  ),
                if (items.any((item) => item.isBought))
                  IconButton(
                    tooltip: 'Clear bought items',
                    onPressed: () => _clearBought(context, ref, items),
                    icon: const Icon(Icons.cleaning_services_outlined),
                  ),
              ],
            ),
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          itemsAsync.when(
            loading: () => const SliverToBoxAdapter(child: SizedBox.shrink()),
            error: (_, _) => const SliverToBoxAdapter(child: SizedBox.shrink()),
            data: (items) => SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.pageGutter,
                  AppSpacing.pageTop,
                  AppSpacing.pageGutter,
                  AppSpacing.element,
                ),
                child: _ShoppingListSummary(
                  items: items,
                  hideBought: _hideBought,
                  onHideBoughtChanged: (hideBought) {
                    setState(() => _hideBought = hideBought);
                  },
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(child: _ManualIngredientForm(key: _manualFormKey)),
          itemsAsync.when(
            loading: () => const SliverFillRemaining(
              hasScrollBody: false,
              child: _ShoppingListLoadingState(),
            ),
            error: (error, _) => SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 44,
                        color: Theme.of(context).colorScheme.error,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Your shopping list couldn’t be opened',
                        style: Theme.of(context).textTheme.titleLarge
                            ?.copyWith(fontWeight: FontWeight.w700),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Try again. If the problem continues, check your device storage.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        error.toString(),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: () => ref.invalidate(shoppingListProvider),
                        icon: const Icon(Icons.refresh),
                        label: const Text('Try again'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            data: (items) {
              final visibleItems = _hideBought
                  ? items.where((item) => !item.isBought).toList()
                  : items;
              if (items.isEmpty) {
                return SliverFillRemaining(
                  hasScrollBody: false,
                  child: _EmptyShoppingList(onAddItem: _scrollToAddForm),
                );
              }
              if (visibleItems.isEmpty) {
                return SliverFillRemaining(
                  hasScrollBody: false,
                  child: _AllBoughtState(
                    onShowBought: () => setState(() => _hideBought = false),
                  ),
                );
              }
              return SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.pageGutter,
                  0,
                  AppSpacing.pageGutter,
                  AppSpacing.section,
                ),
                sliver: SliverReorderableList(
                  itemCount: visibleItems.length,
                  onReorderItem: (oldIndex, newIndex) async {
                    try {
                      await ref
                          .read(shoppingListProvider.notifier)
                          .reorder(oldIndex, newIndex);
                    } catch (error) {
                      if (context.mounted) _showError(context, error);
                    }
                  },
                  itemBuilder: (context, index) {
                    final item = visibleItems[index];
                    return Padding(
                      key: ValueKey(item.id),
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _ShoppingItemTile(
                        index: index,
                        item: item,
                        onBoughtChanged: (value) async {
                          try {
                            await ref
                                .read(shoppingListProvider.notifier)
                                .setBought(item.id, value);
                          } catch (error) {
                            if (context.mounted) {
                              _showError(context, error);
                            }
                          }
                        },
                        onRemove: () => _removeItem(context, ref, item, index),
                        onEdit: () => _editItem(context, ref, item),
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ShoppingListSummary extends StatelessWidget {
  const _ShoppingListSummary({
    required this.items,
    required this.hideBought,
    required this.onHideBoughtChanged,
  });

  final List<ShoppingItem> items;
  final bool hideBought;
  final ValueChanged<bool> onHideBoughtChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final remaining = items.where((item) => !item.isBought).length;
    final progress = items.isEmpty
        ? 0.0
        : (items.length - remaining) / items.length;

    final remainingLabel = Text(
      items.isEmpty
          ? 'Ready for your next shop'
          : '$remaining ${remaining == 1 ? 'item' : 'items'} left',
      style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
    );
    final totalLabel = Text(
      '${items.length} ${items.length == 1 ? 'item' : 'items'} total',
      style: theme.textTheme.bodyMedium?.copyWith(
        color: colors.onSurfaceVariant,
      ),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final compact =
                  constraints.maxWidth < 400 ||
                  MediaQuery.textScalerOf(context).scale(16) >= 20;
              return compact
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [remainingLabel, totalLabel],
                    )
                  : Row(
                      children: [
                        Expanded(child: remainingLabel),
                        totalLabel,
                      ],
                    );
            },
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              color: colors.primary,
              backgroundColor: colors.surfaceContainerHighest,
            ),
          ),
          if (items.any((item) => item.isBought)) ...[
            const SizedBox(height: 8),
            FilterChip(
              label: const Text('Hide bought'),
              avatar: const Icon(Icons.visibility_off_outlined, size: 18),
              selected: hideBought,
              onSelected: onHideBoughtChanged,
              visualDensity: VisualDensity.compact,
            ),
          ],
        ],
      ),
    );
  }
}

class _AllBoughtState extends StatelessWidget {
  const _AllBoughtState({required this.onShowBought});

  final VoidCallback onShowBought;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.pageGutter),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle_outline, size: 52, color: colors.primary),
            const SizedBox(height: AppSpacing.element),
            Text(
              'All caught up',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Bought items are hidden.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.element),
            OutlinedButton.icon(
              onPressed: onShowBought,
              icon: const Icon(Icons.visibility_outlined),
              label: const Text('Show bought items'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ShoppingListLoadingState extends StatelessWidget {
  const _ShoppingListLoadingState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(
            'Loading your shopping list',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

void _showListMessage(
  BuildContext context,
  String message, {
  bool isError = false,
}) {
  if (!context.mounted) return;
  final colors = Theme.of(context).colorScheme;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              color: colors.onInverseSurface,
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
      ),
    );
}

class _ManualIngredientForm extends ConsumerStatefulWidget {
  const _ManualIngredientForm({super.key});

  @override
  ConsumerState<_ManualIngredientForm> createState() =>
      _ManualIngredientFormState();
}

class _ManualIngredientFormState extends ConsumerState<_ManualIngredientForm> {
  final _formKey = GlobalKey<FormState>();
  final _amount = TextEditingController();
  final _unit = TextEditingController();
  final _name = TextEditingController();
  bool _adding = false;

  @override
  void dispose() {
    _amount.dispose();
    _unit.dispose();
    _name.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    if (_adding || !_formKey.currentState!.validate()) return;
    setState(() => _adding = true);
    final name = _name.text.trim();
    final amount = _amount.text.trim();
    final unit = _unit.text.trim();

    try {
      await ref
          .read(shoppingListProvider.notifier)
          .addManualItem(name: name, amountText: amount, unit: unit);
      if (!mounted) return;
      _name.clear();
      _amount.clear();
      _unit.clear();
      _showListMessage(context, 'Added $name to the list.');
    } catch (error) {
      if (!mounted) return;
      _showListMessage(context, 'Could not add $name: $error', isError: true);
    } finally {
      if (mounted) setState(() => _adding = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.pageGutter,
        0,
        AppSpacing.pageGutter,
        AppSpacing.panel,
      ),
      child: SectionPanel(
        emphasized: true,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.panel),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SectionHeading(
                  title: 'Add an item',
                  icon: Icons.add_shopping_cart_outlined,
                ),
                const SizedBox(height: 12),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final useStackedLayout =
                        constraints.maxWidth < 440 ||
                        MediaQuery.textScalerOf(context).scale(14) >= 20;
                    final amountField = TextFormField(
                      key: const ValueKey('shopping-amount'),
                      controller: _amount,
                      decoration: const InputDecoration(
                        labelText: 'Amount',
                        hintText: 'e.g. 2',
                      ),
                      keyboardType: TextInputType.text,
                      textInputAction: TextInputAction.next,
                      textCapitalization: TextCapitalization.sentences,
                    );
                    final unitField = TextFormField(
                      key: const ValueKey('shopping-unit'),
                      controller: _unit,
                      decoration: const InputDecoration(
                        labelText: 'Unit',
                        hintText: 'e.g. cups',
                      ),
                      textInputAction: TextInputAction.next,
                      textCapitalization: TextCapitalization.sentences,
                    );
                    final nameField = TextFormField(
                      key: const ValueKey('shopping-ingredient-name'),
                      controller: _name,
                      decoration: const InputDecoration(
                        labelText: 'Ingredient',
                        hintText: 'e.g. Tomatoes',
                      ),
                      textCapitalization: TextCapitalization.sentences,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _add(),
                      validator: (value) => (value ?? '').trim().isEmpty
                          ? 'Enter an ingredient'
                          : null,
                    );
                    final addButton = FilledButton.icon(
                      key: const ValueKey('add-shopping-ingredient'),
                      onPressed: _adding ? null : _add,
                      icon: _adding
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.add),
                      label: const Text('Add'),
                    );

                    if (useStackedLayout) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          amountField,
                          const SizedBox(height: 8),
                          unitField,
                          const SizedBox(height: 8),
                          nameField,
                          const SizedBox(height: 8),
                          Align(
                            alignment: Alignment.centerRight,
                            child: addButton,
                          ),
                        ],
                      );
                    }

                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(width: 92, child: amountField),
                        const SizedBox(width: 8),
                        SizedBox(width: 100, child: unitField),
                        const SizedBox(width: 8),
                        Expanded(child: nameField),
                        const SizedBox(width: 8),
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Tooltip(
                            message: 'Add ingredient',
                            child: IconButton.filled(
                              key: const ValueKey('add-shopping-ingredient'),
                              onPressed: _adding ? null : _add,
                              icon: _adding
                                  ? const SizedBox.square(
                                      dimension: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.add),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyShoppingList extends StatelessWidget {
  const _EmptyShoppingList({required this.onAddItem});

  final VoidCallback onAddItem;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(32),
              ),
              child: Icon(
                Icons.shopping_basket_outlined,
                size: 48,
                color: theme.colorScheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Your list is empty',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Start a list here, or add ingredients from any recipe.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.element),
            FilledButton.tonalIcon(
              onPressed: onAddItem,
              icon: const Icon(Icons.add),
              label: const Text('Add your first item'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ShoppingItemTile extends StatelessWidget {
  const _ShoppingItemTile({
    required this.index,
    required this.item,
    required this.onBoughtChanged,
    required this.onRemove,
    required this.onEdit,
  });

  final int index;
  final ShoppingItem item;
  final ValueChanged<bool> onBoughtChanged;
  final VoidCallback onRemove;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = item.isBought ? theme.colorScheme.onSurfaceVariant : null;
    final quantity = item.amountText != null
        ? [
            item.amountText!,
            if (parseQuantity(item.amountText!) != null && item.unit.isNotEmpty)
              item.unit,
          ].join(' ')
        : (item.quantity == null
              ? ''
              : [
                  formatQuantity(item.quantity!),
                  if (item.unit.isNotEmpty) item.unit,
                ].join(' '));
    final dragHandle = ReorderableDragStartListener(
      index: index,
      child: SizedBox(
        width: 40,
        height: 48,
        child: Center(
          child: Tooltip(
            message: 'Reorder ${item.name}',
            child: Icon(
              Icons.drag_handle,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
    final checkbox = Checkbox(
      value: item.isBought,
      onChanged: (value) {
        if (value != null) onBoughtChanged(value);
      },
    );
    final details = Opacity(
      opacity: item.isBought ? 0.58 : 1,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            [if (quantity.isNotEmpty) quantity, item.name].join(' '),
            style: theme.textTheme.titleMedium?.copyWith(
              color: color,
              decoration: item.isBought
                  ? TextDecoration.lineThrough
                  : TextDecoration.none,
            ),
          ),
          if (item.note.isNotEmpty || item.recipeTitle.isNotEmpty)
            Text(
              [
                if (item.note.isNotEmpty) item.note,
                if (item.recipeTitle.isNotEmpty) 'From ${item.recipeTitle}',
              ].join(' · '),
              style: theme.textTheme.bodySmall?.copyWith(color: color),
            ),
        ],
      ),
    );
    final editButton = IconButton(
      constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
      key: ValueKey('edit-shopping-item-${item.id}'),
      tooltip: 'Edit ${item.name}',
      onPressed: onEdit,
      icon: const Icon(Icons.edit_outlined),
    );
    final removeButton = IconButton(
      constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
      tooltip: 'Remove ${item.name}',
      onPressed: onRemove,
      icon: Icon(Icons.delete_outline, color: theme.colorScheme.error),
    );

    return Card(
      color: theme.colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.55),
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact =
              constraints.maxWidth < 520 ||
              MediaQuery.textScalerOf(context).scale(14) >= 20;
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
            child: compact
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          dragHandle,
                          checkbox,
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(top: 10),
                              child: details,
                            ),
                          ),
                        ],
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [editButton, removeButton],
                        ),
                      ),
                    ],
                  )
                : Row(
                    children: [
                      dragHandle,
                      checkbox,
                      Expanded(child: details),
                      editButton,
                      removeButton,
                    ],
                  ),
          );
        },
      ),
    );
  }
}

class _EditShoppingItemDialog extends StatefulWidget {
  const _EditShoppingItemDialog({required this.item});

  final ShoppingItem item;

  @override
  State<_EditShoppingItemDialog> createState() =>
      _EditShoppingItemDialogState();
}

class _EditShoppingItemDialogState extends State<_EditShoppingItemDialog> {
  late final TextEditingController _amount;
  late final TextEditingController _unit;
  late final TextEditingController _name;

  String _initialAmount(ShoppingItem item) {
    if (item.amountText != null) return item.amountText!;
    if (item.quantity == null) return '';
    return formatQuantity(item.quantity!);
  }

  @override
  void initState() {
    super.initState();
    _amount = TextEditingController(text: _initialAmount(widget.item));
    _unit = TextEditingController(text: widget.item.unit);
    _name = TextEditingController(text: widget.item.name);
  }

  @override
  void dispose() {
    _amount.dispose();
    _unit.dispose();
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Edit shopping item'),
    scrollable: true,
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          key: const ValueKey('edit-shopping-amount'),
          controller: _amount,
          decoration: const InputDecoration(
            labelText: 'Amount',
            hintText: 'e.g. 2 or 1/2',
          ),
          keyboardType: TextInputType.text,
        ),
        const SizedBox(height: 12),
        TextField(
          key: const ValueKey('edit-shopping-unit'),
          controller: _unit,
          decoration: const InputDecoration(
            labelText: 'Unit',
            hintText: 'e.g. cups',
          ),
          textCapitalization: TextCapitalization.sentences,
        ),
        const SizedBox(height: 12),
        TextField(
          key: const ValueKey('edit-shopping-name'),
          controller: _name,
          decoration: const InputDecoration(labelText: 'Ingredient'),
          textCapitalization: TextCapitalization.sentences,
          autofocus: true,
        ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () {
          final name = _name.text.trim();
          if (name.isEmpty) return;
          Navigator.pop(context, (
            name: name,
            amount: _amount.text.trim(),
            unit: _unit.text.trim(),
          ));
        },
        child: const Text('Save'),
      ),
    ],
  );
}
