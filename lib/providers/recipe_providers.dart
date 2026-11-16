import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/recipe.dart';
import '../services/recipe_storage_service.dart';
import 'settings_provider.dart';

final storageServiceProvider = Provider<RecipeStorageService>(
  (ref) => RecipeStorageService(),
);

final recipesProvider = AsyncNotifierProvider<RecipesNotifier, List<Recipe>>(
  RecipesNotifier.new,
);

final weeklyBackupProvider = FutureProvider<void>((ref) async {
  final settings = await ref.watch(autoBackupSettingsProvider.future);
  if (!settings.enabled) return;

  final recipes = await ref.watch(recipesProvider.future);
  await ref.read(storageServiceProvider).createWeeklyBackup(recipes);
  ref.invalidate(weeklyBackupLastModifiedProvider);
});

final weeklyBackupLastModifiedProvider = FutureProvider<DateTime?>(
  (ref) => ref.read(storageServiceProvider).weeklyBackupLastModified(),
);

class RecipesNotifier extends AsyncNotifier<List<Recipe>> {
  RecipeStorageService get _svc => ref.read(storageServiceProvider);

  @override
  Future<List<Recipe>> build() => _svc.loadAll();

  List<Recipe> get _current => state.value ?? const <Recipe>[];

  Future<void> _commit(List<Recipe> next) async {
    await _svc.saveAll(next);
    state = AsyncData(next);
  }

  Future<void> upsert(Recipe recipe) async {
    final list = [..._current];
    final i = list.indexWhere((r) => r.id == recipe.id);
    if (i >= 0) {
      list[i] = recipe;
    } else {
      list.add(recipe);
    }
    await _commit(list);
  }

  Future<void> delete(String id) =>
      _commit(_current.where((r) => r.id != id).toList());

  Future<void> setFavorite(String id, bool isFavorite) {
    final list = _current
        .map(
          (recipe) => recipe.id == id
              ? recipe.copyWith(isFavorite: isFavorite)
              : recipe,
        )
        .toList();
    return _commit(list);
  }

  Future<List<Recipe>> restoreWeeklyBackup() async {
    final restored = await _svc.restoreWeeklyBackup();
    state = AsyncData(restored);
    return restored;
  }

  /// Returns null if the user cancelled the picker.
  /// Takes a backup of the current library before merging.
  Future<ImportResult?> importFromFile() async {
    final out = await _svc.pickAndImport(_current);
    if (out == null) return null;
    await _svc.backupCurrent();
    await _commit(out.merged);
    return out.result;
  }

  /// Returns true if saved, false if the user cancelled.
  Future<bool> exportAll() =>
      _svc.exportToDevice(_current, name: 'all-recipes');

  Future<bool> exportOne(Recipe recipe) => _svc.exportToDevice([recipe]);
}
