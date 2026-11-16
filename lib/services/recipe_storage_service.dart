import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../models/ingredient.dart';
import '../models/recipe.dart';

const int kSchemaVersion = 1;

class ImportResult {
  const ImportResult({
    required this.added,
    required this.updated,
    required this.skipped,
  });
  final int added;
  final int updated;
  final int skipped;
  int get total => added + updated + skipped;
}

class RecipeImportException implements Exception {
  RecipeImportException(this.message);
  final String message;
  @override
  String toString() => message;
}

class RecipeStorageService {
  /// [directoryOverride] lets unit tests point at a temp directory.
  RecipeStorageService({Directory? directoryOverride})
    : _dirOverride = directoryOverride;

  final Directory? _dirOverride;
  static const _fileName = 'recipes.json';
  static const _weeklyBackupFileName = 'recipes-auto-backup.json';

  Future<File> _dataFile() async {
    final dir = _dirOverride ?? await getApplicationDocumentsDirectory();
    return File('${dir.path}/$_fileName');
  }

  // ---------------------------------------------------------------- load

  Future<List<Recipe>> loadAll() async {
    final file = await _dataFile();
    if (!await file.exists()) return [];

    try {
      final raw = await file.readAsString();
      if (raw.trim().isEmpty) return [];
      final recipes = parseRecipes(raw);
      return recipes.map((recipe) => recipe.sanitize()).toList();
    } catch (error, stackTrace) {
      // Corrupt file: preserve it for recovery and start with a clean library.
      debugPrint('Recipe storage load failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      try {
        await file.copy('${file.path}.corrupt');
      } catch (_) {}
      return [];
    }
  }

  // ---------------------------------------------------------------- save

  /// Atomic write: temp file, then rename over the original.
  Future<void> saveAll(List<Recipe> recipes) async {
    final file = await _dataFile();
    await file.parent.create(recursive: true);
    final validated = recipes
        .where((recipe) => recipe.title.trim().isNotEmpty)
        .map(
          (recipe) => Recipe(
            id: recipe.id,
            title: recipe.title.trim(),
            description: recipe.description.trim(),
            servings: recipe.servings > 0 ? recipe.servings : 1,
            prepMinutes: recipe.prepMinutes == null || recipe.prepMinutes! < 0
                ? null
                : recipe.prepMinutes,
            cookMinutes: recipe.cookMinutes == null || recipe.cookMinutes! < 0
                ? null
                : recipe.cookMinutes,
            ingredients: recipe.ingredients
                .where((ingredient) => ingredient.name.trim().isNotEmpty)
                .map(
                  (ingredient) => Ingredient(
                    name: ingredient.name.trim(),
                    quantity:
                        ingredient.quantity == null || ingredient.quantity! < 0
                        ? null
                        : ingredient.quantity,
                    unit: ingredient.unit.trim(),
                    note: ingredient.note.trim(),
                    substitute: ingredient.substitute.trim(),
                  ),
                )
                .toList(),
            steps: recipe.steps
                .map((step) => step.trim())
                .where((step) => step.isNotEmpty)
                .toList(),
            tags: recipe.tags
                .map((tag) => tag.trim())
                .where((tag) => tag.isNotEmpty)
                .toList(),
            isFavorite: recipe.isFavorite,
            createdAt: recipe.createdAt,
            updatedAt: recipe.updatedAt,
          ),
        )
        .toList();
    final tmp = File('${file.path}.tmp');
    await tmp.writeAsString(_encode(validated), flush: true);
    await tmp.rename(file.path);
  }

  /// Safety copy of the current library (recipes.json.bak), taken before
  /// every import.
  Future<void> backupCurrent() async {
    final file = await _dataFile();
    if (await file.exists()) await file.copy('${file.path}.bak');
  }

  /// Stores one rolling backup, creating a new copy no more than once a week.
  Future<bool> createWeeklyBackup(List<Recipe> recipes) async {
    if (recipes.isEmpty) return false;

    final dir = _dirOverride ?? await getApplicationDocumentsDirectory();
    await dir.create(recursive: true);
    final backup = File('${dir.path}/$_weeklyBackupFileName');
    final now = DateTime.now();
    if (await backup.exists()) {
      final lastBackup = await backup.lastModified();
      if (now.isBefore(lastBackup.add(const Duration(days: 7)))) return false;
    }

    final temporary = File('${backup.path}.tmp');
    await temporary.writeAsString(_encode(recipes), flush: true);
    await temporary.rename(backup.path);
    return true;
  }

  Future<DateTime?> weeklyBackupLastModified() async {
    final dir = _dirOverride ?? await getApplicationDocumentsDirectory();
    final backup = File('${dir.path}/$_weeklyBackupFileName');
    if (!await backup.exists()) return null;
    return backup.lastModified();
  }

  Future<List<Recipe>> restoreWeeklyBackup() async {
    final dir = _dirOverride ?? await getApplicationDocumentsDirectory();
    final backup = File('${dir.path}/$_weeklyBackupFileName');
    if (!await backup.exists()) {
      throw RecipeImportException('No automatic backup is available.');
    }

    final recipes = parseRecipes(await backup.readAsString());
    await backupCurrent();
    await saveAll(recipes);
    return recipes;
  }

  // -------------------------------------------------------------- export

  /// Opens a "save as" dialog so the user picks where the file goes.
  /// Returns true if the file was saved, false if the user cancelled.
  Future<bool> exportToDevice(List<Recipe> recipes, {String? name}) async {
    final safe = _sanitizeFileName(
      name ?? (recipes.length == 1 ? recipes.first.title : 'all-recipes'),
    );
    final saved = await FilePicker.saveFile(
      dialogTitle: 'Save recipes',
      fileName: '$safe.json',
      bytes: Uint8List.fromList(utf8.encode(_encode(recipes))),
    );
    return saved != null;
  }

  // -------------------------------------------------------------- import

  /// Opens the system file picker. Returns null if the user cancels.
  Future<({List<Recipe> merged, ImportResult result})?> pickAndImport(
    List<Recipe> existing,
  ) async {
    final picked = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: const ['json'],
    );
    if (picked == null) return null;

    final List<int> bytes;
    try {
      bytes = await picked.readAsBytes();
    } catch (_) {
      throw RecipeImportException('Could not read the file.');
    }

    final incoming = parseRecipes(utf8.decode(bytes));
    return mergeImported(existing, incoming);
  }

  /// Never removes anything:
  /// new id -> added; same id & newer -> updated; otherwise skipped.
  ({List<Recipe> merged, ImportResult result}) mergeImported(
    List<Recipe> existing,
    List<Recipe> incoming,
  ) {
    final byId = {for (final r in existing) r.id: r};
    var added = 0, updated = 0, skipped = 0;

    for (final r in incoming) {
      final current = byId[r.id];
      if (current == null) {
        byId[r.id] = r;
        added++;
      } else if (r.updatedAt.isAfter(current.updatedAt)) {
        byId[r.id] = r;
        updated++;
      } else {
        skipped++;
      }
    }

    return (
      merged: byId.values.toList(),
      result: ImportResult(added: added, updated: updated, skipped: skipped),
    );
  }

  // ---------------------------------------------------------- (de)coding

  /// Accepts {"version":1,"recipes":[...]}, a bare [...], or one {...}.
  List<Recipe> parseRecipes(String raw) {
    final dynamic decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException {
      throw RecipeImportException('This file is not valid JSON.');
    }

    final List<dynamic> items;
    if (decoded is Map<String, dynamic> && decoded['recipes'] is List) {
      items = decoded['recipes'] as List;
    } else if (decoded is List) {
      items = decoded;
    } else if (decoded is Map<String, dynamic> &&
        decoded.containsKey('title')) {
      items = [decoded];
    } else {
      throw RecipeImportException('No recipes found in this file.');
    }

    final recipes = items
        .whereType<Map>()
        .map((m) => Recipe.fromJson(Map<String, dynamic>.from(m)))
        .toList();

    if (recipes.isEmpty) {
      throw RecipeImportException('No recipes found in this file.');
    }
    return recipes;
  }

  String encodeRecipes(List<Recipe> recipes) =>
      const JsonEncoder.withIndent('  ').convert({
        'version': kSchemaVersion,
        'recipes': recipes.map((r) => r.toJson()).toList(),
      });

  String _encode(List<Recipe> recipes) => encodeRecipes(recipes);

  String _sanitizeFileName(String input) {
    final cleaned = input
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    return cleaned.isEmpty ? 'recipes' : cleaned;
  }
}
