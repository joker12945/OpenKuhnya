import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../models/shopping_item.dart';

class ShoppingListStorageService {
  static const _fileName = 'shopping_list.json';

  Future<File> _dataFile() async {
    final directory = await getApplicationDocumentsDirectory();
    return File('${directory.path}/$_fileName');
  }

  Future<List<ShoppingItem>> loadAll() async {
    final file = await _dataFile();
    if (!await file.exists()) return [];

    try {
      final raw = await file.readAsString();
      if (raw.trim().isEmpty) return [];

      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic> || decoded['items'] is! List) {
        throw const FormatException(
          'Shopping list file has an invalid format.',
        );
      }

      return (decoded['items'] as List)
          .whereType<Map>()
          .map((item) => ShoppingItem.fromJson(Map<String, dynamic>.from(item)))
          .where((item) => item.name.trim().isNotEmpty)
          .toList();
    } on FormatException {
      rethrow;
    } on TypeError {
      throw const FormatException('Shopping list file has an invalid format.');
    } catch (_) {
      throw const FormatException('Shopping list file could not be read.');
    }
  }

  Future<void> saveAll(List<ShoppingItem> items) async {
    final file = await _dataFile();
    await file.parent.create(recursive: true);
    final sanitized = items
        .where((item) => item.name.trim().isNotEmpty)
        .map(
          (item) => ShoppingItem(
            id: item.id,
            name: item.name.trim(),
            recipeTitle: item.recipeTitle.trim(),
            quantity: item.quantity != null && item.quantity! < 0
                ? null
                : item.quantity,
            amountText: item.amountText?.trim().isNotEmpty == true
                ? item.amountText!.trim()
                : null,
            unit: item.unit.trim(),
            note: item.note.trim(),
            isBought: item.isBought,
          ),
        )
        .toList();
    final temporaryFile = File('${file.path}.tmp');
    final contents = const JsonEncoder.withIndent('  ').convert({
      'version': 1,
      'items': sanitized.map((item) => item.toJson()).toList(),
    });
    await temporaryFile.writeAsString(contents, flush: true);
    await temporaryFile.rename(file.path);
  }
}
