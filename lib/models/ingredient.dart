class Ingredient {
  const Ingredient({
    required this.name,
    this.quantity,
    this.unit = '',
    this.note = '',
    this.substitute = '',
  });

  final String name;

  /// Null means "no fixed amount" (e.g. "salt, to taste"). Never scaled.
  final double? quantity;

  final String unit; // "g", "cup", "tbsp", "" for countable items
  final String note; // "finely chopped"
  final String substitute;

  /// Returns a copy with the quantity multiplied by [factor].
  Ingredient scaled(double factor) => Ingredient(
    name: name,
    quantity: quantity == null ? null : quantity! * factor,
    unit: unit,
    note: note,
    substitute: substitute,
  );

  Map<String, dynamic> toJson() => {
    'name': name,
    if (quantity != null) 'quantity': quantity,
    if (unit.isNotEmpty) 'unit': unit,
    if (note.isNotEmpty) 'note': note,
    if (substitute.isNotEmpty) 'substitute': substitute,
  };

  factory Ingredient.fromJson(Map<String, dynamic> json) => Ingredient(
    name: (json['name'] as String?)?.trim() ?? '',
    quantity: (json['quantity'] as num?)?.toDouble(),
    unit: (json['unit'] as String?) ?? '',
    note: (json['note'] as String?) ?? '',
    substitute: (json['substitute'] as String?) ?? '',
  );
}
