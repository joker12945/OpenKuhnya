import 'dart:math';

import 'ingredient.dart';

class ShoppingItem {
  const ShoppingItem({
    required this.id,
    required this.name,
    required this.recipeTitle,
    this.quantity,
    this.amountText,
    this.unit = '',
    this.note = '',
    this.isBought = false,
  });

  final String id;
  final String name;
  final String recipeTitle;
  final double? quantity;
  final String? amountText;
  final String unit;
  final String note;
  final bool isBought;

  factory ShoppingItem.fromIngredient(
    Ingredient ingredient, {
    required String recipeTitle,
    String? amountText,
  }) {
    final random = Random.secure();
    final bytes = List<int>.generate(8, (_) => random.nextInt(256));
    final suffix = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

    return ShoppingItem(
      id: '${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}-$suffix',
      name: ingredient.name,
      recipeTitle: recipeTitle,
      quantity: ingredient.quantity,
      amountText: amountText,
      unit: ingredient.unit,
      note: ingredient.note,
    );
  }

  ShoppingItem copyWith({bool? isBought, String? name, String? amountText}) =>
      ShoppingItem(
        id: id,
        name: name ?? this.name,
        recipeTitle: recipeTitle,
        quantity: quantity,
        amountText: amountText ?? this.amountText,
        unit: unit,
        note: note,
        isBought: isBought ?? this.isBought,
      );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'recipeTitle': recipeTitle,
    if (quantity != null) 'quantity': quantity,
    if (amountText != null) 'amountText': amountText,
    if (unit.isNotEmpty) 'unit': unit,
    if (note.isNotEmpty) 'note': note,
    'isBought': isBought,
  };

  factory ShoppingItem.fromJson(Map<String, dynamic> json) {
    final rawId = (json['id'] as String?)?.trim();
    final rawName = (json['name'] as String?) ?? '';
    return ShoppingItem(
      id: rawId != null && rawId.isNotEmpty
          ? rawId
          : 'shopping-item-${DateTime.now().microsecondsSinceEpoch}',
      name: rawName.trim(),
      recipeTitle: (json['recipeTitle'] as String?)?.trim() ?? '',
      quantity: (json['quantity'] as num?)?.toDouble(),
      amountText: json['amountText'] as String?,
      unit: (json['unit'] as String?)?.trim() ?? '',
      note: (json['note'] as String?)?.trim() ?? '',
      isBought: (json['isBought'] as bool?) ?? false,
    );
  }
}
