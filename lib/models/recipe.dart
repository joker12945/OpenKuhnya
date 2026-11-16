import 'dart:math';

import 'ingredient.dart';

class Recipe {
  const Recipe({
    required this.id,
    required this.title,
    required this.servings,
    required this.createdAt,
    required this.updatedAt,
    this.description = '',
    this.prepMinutes,
    this.cookMinutes,
    this.ingredients = const [],
    this.steps = const [],
    this.tags = const [],
    this.isFavorite = false,
  });

  final String id;
  final String title;
  final String description;

  /// The serving size the ingredient quantities are written for.
  final int servings;

  final int? prepMinutes;
  final int? cookMinutes;
  final List<Ingredient> ingredients;
  final List<String> steps;
  final List<String> tags;
  final bool isFavorite;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory Recipe.create({
    required String title,
    required int servings,
    String description = '',
    int? prepMinutes,
    int? cookMinutes,
    List<Ingredient> ingredients = const [],
    List<String> steps = const [],
    List<String> tags = const [],
    bool isFavorite = false,
  }) {
    final now = DateTime.now().toUtc();
    return Recipe(
      id: _generateId(),
      title: title,
      servings: servings,
      description: description,
      prepMinutes: prepMinutes,
      cookMinutes: cookMinutes,
      ingredients: ingredients,
      steps: steps,
      tags: tags,
      isFavorite: isFavorite,
      createdAt: now,
      updatedAt: now,
    );
  }

  /// Ingredients with quantities multiplied for [targetServings].
  List<Ingredient> ingredientsFor(int targetServings) {
    final factor = targetServings / servings;
    return ingredients.map((i) => i.scaled(factor)).toList();
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    if (description.isNotEmpty) 'description': description,
    'servings': servings,
    if (prepMinutes != null) 'prepMinutes': prepMinutes,
    if (cookMinutes != null) 'cookMinutes': cookMinutes,
    'ingredients': ingredients.map((i) => i.toJson()).toList(),
    'steps': steps,
    'tags': tags,
    if (isFavorite) 'isFavorite': true,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  /// Lenient on purpose: imported files may be hand-written or older.
  factory Recipe.fromJson(Map<String, dynamic> json) {
    final now = DateTime.now().toUtc();
    final servings = (json['servings'] as num?)?.toInt() ?? 1;
    return Recipe(
      id: (json['id'] as String?)?.isNotEmpty == true
          ? json['id'] as String
          : _generateId(),
      title: (json['title'] as String?)?.trim().isNotEmpty == true
          ? (json['title'] as String).trim()
          : 'Untitled recipe',
      description: (json['description'] as String?) ?? '',
      servings: servings < 1 ? 1 : servings,
      prepMinutes: (json['prepMinutes'] as num?)?.toInt(),
      cookMinutes: (json['cookMinutes'] as num?)?.toInt(),
      ingredients: ((json['ingredients'] as List?) ?? const [])
          .whereType<Map>()
          .map((m) => Ingredient.fromJson(Map<String, dynamic>.from(m)))
          .where((i) => i.name.isNotEmpty)
          .toList(),
      steps: ((json['steps'] as List?) ?? const [])
          .whereType<String>()
          .toList(),
      tags: ((json['tags'] as List?) ?? const []).whereType<String>().toList(),
      isFavorite: json['isFavorite'] == true,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? now,
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? '') ?? now,
    );
  }

  Recipe copyWith({bool? isFavorite}) => Recipe(
    id: id,
    title: title,
    description: description,
    servings: servings,
    prepMinutes: prepMinutes,
    cookMinutes: cookMinutes,
    ingredients: ingredients,
    steps: steps,
    tags: tags,
    isFavorite: isFavorite ?? this.isFavorite,
    createdAt: createdAt,
    updatedAt: updatedAt,
  );

  Recipe sanitize() => Recipe(
    id: id,
    title: title.trim(),
    description: description.trim(),
    servings: servings > 0 ? servings : 1,
    prepMinutes: prepMinutes == null || prepMinutes! < 0 ? null : prepMinutes,
    cookMinutes: cookMinutes == null || cookMinutes! < 0 ? null : cookMinutes,
    ingredients: ingredients
        .map(
          (ingredient) => Ingredient(
            name: ingredient.name.trim(),
            quantity: ingredient.quantity == null || ingredient.quantity! < 0
                ? null
                : ingredient.quantity,
            unit: ingredient.unit.trim(),
            note: ingredient.note.trim(),
            substitute: ingredient.substitute.trim(),
          ),
        )
        .where((ingredient) => ingredient.name.isNotEmpty)
        .toList(),
    steps: steps
        .map((step) => step.trim())
        .where((step) => step.isNotEmpty)
        .toList(),
    tags: tags.map((tag) => tag.trim()).where((tag) => tag.isNotEmpty).toList(),
    isFavorite: isFavorite,
    createdAt: createdAt,
    updatedAt: updatedAt,
  );

  static String _generateId() {
    final rand = Random.secure();
    final bytes = List<int>.generate(8, (_) => rand.nextInt(256));
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}-$hex';
  }
}
