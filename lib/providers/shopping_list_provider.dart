import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/ingredient.dart';
import '../models/shopping_item.dart';
import '../services/shopping_list_storage_service.dart';
import '../utils/quantity_format.dart';

final shoppingListStorageServiceProvider = Provider<ShoppingListStorageService>(
  (ref) => ShoppingListStorageService(),
);

final shoppingListProvider =
    AsyncNotifierProvider<ShoppingListNotifier, List<ShoppingItem>>(
      ShoppingListNotifier.new,
    );

class ShoppingListNotifier extends AsyncNotifier<List<ShoppingItem>> {
  Future<void> _writeQueue = Future<void>.value();

  ShoppingListStorageService get _storage =>
      ref.read(shoppingListStorageServiceProvider);

  @override
  Future<List<ShoppingItem>> build() async {
    final items = await _storage.loadAll();
    final normalized = _unboughtFirst(_combineDuplicateItems(items));
    if (!_hasSameOrder(items, normalized)) await _storage.saveAll(normalized);
    return normalized;
  }

  Future<void> addIngredient(
    Ingredient ingredient, {
    required String recipeTitle,
  }) {
    final item = ShoppingItem.fromIngredient(
      ingredient,
      recipeTitle: recipeTitle,
    );
    return _update((items) => [...items, item]);
  }

  Future<void> addIngredients(
    List<Ingredient> ingredients, {
    required String recipeTitle,
  }) {
    final added = ingredients
        .map(
          (ingredient) =>
              ShoppingItem.fromIngredient(ingredient, recipeTitle: recipeTitle),
        )
        .toList();
    return _update((items) => [...items, ...added]);
  }

  Future<void> addManualItem({
    required String name,
    required String amountText,
    String unit = '',
  }) {
    final quantity = parseQuantity(amountText);
    final item = quantity == null
        ? ShoppingItem.fromIngredient(
            Ingredient(name: name, unit: unit),
            recipeTitle: '',
            amountText: amountText,
          )
        : ShoppingItem.fromIngredient(
            Ingredient(name: name, quantity: quantity, unit: unit),
            recipeTitle: '',
            amountText: amountText.trim().isEmpty ? null : amountText.trim(),
          );
    return _update((items) => [...items, item]);
  }

  Future<void> updateItem(
    String id, {
    required String name,
    required String amountText,
    required String unit,
  }) => _update((items) {
    final updated = items.map((item) {
      if (item.id != id) return item;

      final trimmedAmount = amountText.trim();
      final parsedAmount = parseQuantity(trimmedAmount);
      return ShoppingItem(
        id: item.id,
        name: name,
        recipeTitle: item.recipeTitle,
        quantity: trimmedAmount.isEmpty ? null : parsedAmount,
        amountText: trimmedAmount.isEmpty ? null : trimmedAmount,
        unit: unit.trim(),
        note: item.note,
        isBought: item.isBought,
      );
    }).toList();
    return updated;
  });

  Future<void> setBought(String id, bool isBought) => _update((items) {
    final itemIndex = items.indexWhere((item) => item.id == id);
    if (itemIndex == -1) return items;

    final updatedItem = items[itemIndex].copyWith(isBought: isBought);
    final unbought = items
        .where((item) => !item.isBought && item.id != id)
        .toList();
    final bought = items
        .where((item) => item.isBought && item.id != id)
        .toList();
    if (isBought) {
      bought.add(updatedItem);
    } else {
      unbought.add(updatedItem);
    }
    return [...unbought, ...bought];
  });

  Future<void> reorder(int oldIndex, int newIndex) => _update((items) {
    if (oldIndex < 0 ||
        oldIndex >= items.length ||
        newIndex < 0 ||
        newIndex >= items.length) {
      throw RangeError('Shopping list reorder index is out of range.');
    }

    final reordered = List<ShoppingItem>.of(items);
    final item = reordered.removeAt(oldIndex);
    reordered.insert(newIndex, item);
    return reordered;
  });

  Future<void> remove(String id) =>
      _update((items) => items.where((item) => item.id != id).toList());

  Future<void> restoreItem(ShoppingItem item, {required int index}) =>
      _update((items) {
        if (items.any((current) => current.id == item.id)) return items;
        final restored = List<ShoppingItem>.of(items);
        restored.insert(index.clamp(0, restored.length).toInt(), item);
        return restored;
      });

  Future<void> clearBought() =>
      _update((items) => items.where((item) => !item.isBought).toList());

  Future<void> restoreItems(List<ShoppingItem> restoredItems) => _update(
    (items) => [
      ...items,
      ...restoredItems.where(
        (restored) => !items.any((current) => current.id == restored.id),
      ),
    ],
  );

  Future<void> _update(
    List<ShoppingItem> Function(List<ShoppingItem>) transform,
  ) {
    final completer = Completer<void>();
    _writeQueue = _writeQueue.then((_) async {
      try {
        if (!state.hasValue) await future;
        final next = _unboughtFirst(
          _combineDuplicateItems(
            transform(state.value ?? const <ShoppingItem>[]),
          ),
        );
        await _storage.saveAll(next);
        state = AsyncData(next);
        completer.complete();
      } catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
      }
    });
    return completer.future;
  }

  List<ShoppingItem> _combineDuplicateItems(List<ShoppingItem> items) {
    final combined = <ShoppingItem>[];
    final indexesByIngredient = <(String, String), List<int>>{};

    for (final item in items) {
      final key = (_normalize(item.name), _normalize(item.unit));
      final matchingIndexes = indexesByIngredient.putIfAbsent(key, () => []);
      var merged = false;

      for (final index in matchingIndexes) {
        final result = _mergeItems(combined[index], item);
        if (result == null) continue;
        combined[index] = result;
        merged = true;
        break;
      }

      if (!merged) {
        matchingIndexes.add(combined.length);
        combined.add(item);
      }
    }

    return combined;
  }

  List<ShoppingItem> _unboughtFirst(List<ShoppingItem> items) => [
    ...items.where((item) => !item.isBought),
    ...items.where((item) => item.isBought),
  ];

  bool _hasSameOrder(List<ShoppingItem> first, List<ShoppingItem> second) {
    if (first.length != second.length) return false;
    for (var index = 0; index < first.length; index++) {
      if (first[index].id != second[index].id) return false;
    }
    return true;
  }

  ShoppingItem? _mergeItems(ShoppingItem first, ShoppingItem second) {
    final firstAmount = _amount(first);
    final secondAmount = _amount(second);

    final double? quantity;
    final String? amountText;
    if (firstAmount.quantity != null && secondAmount.quantity != null) {
      quantity = firstAmount.quantity! + secondAmount.quantity!;
      amountText = null;
    } else if (firstAmount.quantity == null &&
        secondAmount.quantity == null &&
        firstAmount.customText == null &&
        secondAmount.customText == null) {
      quantity = null;
      amountText = null;
    } else if (firstAmount.customText != null &&
        firstAmount.customText == secondAmount.customText) {
      quantity = null;
      amountText = firstAmount.customText;
    } else {
      return null;
    }

    return ShoppingItem(
      id: first.id,
      name: first.name,
      recipeTitle: _joinDistinct(first.recipeTitle, second.recipeTitle),
      quantity: quantity,
      amountText: amountText,
      unit: first.unit,
      note: _joinDistinct(first.note, second.note),
      isBought: first.isBought && second.isBought,
    );
  }

  ({double? quantity, String? customText}) _amount(ShoppingItem item) {
    final amountText = item.amountText?.trim();
    if (amountText != null && amountText.isNotEmpty) {
      final parsed = parseQuantity(amountText);
      return parsed == null
          ? (quantity: null, customText: amountText)
          : (quantity: parsed, customText: null);
    }
    return (quantity: item.quantity, customText: null);
  }

  String _normalize(String value) =>
      value.trim().toLowerCase().split(RegExp(r'\s+')).join(' ');

  String _joinDistinct(String first, String second) {
    final values = <String>{};
    for (final value in [...first.split(' · '), ...second.split(' · ')]) {
      final trimmed = value.trim();
      if (trimmed.isNotEmpty) values.add(trimmed);
    }
    return values.join(' · ');
  }
}
