import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../providers/recipe_providers.dart';
import '../../providers/settings_provider.dart';
import '../../services/recipe_storage_service.dart';
import '../widgets/app_spacing.dart';
import '../widgets/section_heading.dart';
import '../widgets/section_panel.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  late final Future<PackageInfo> _packageInfo;

  @override
  void initState() {
    super.initState();
    _packageInfo = PackageInfo.fromPlatform();
  }

  Future<void> _selectThemeColor(ThemeColor color) async {
    try {
      await ref.read(appearanceSettingsProvider.notifier).setThemeColor(color);
    } catch (error) {
      _showMessage('Could not save theme color: $error', isError: true);
    }
  }

  Future<void> _setNightMode(bool enabled) async {
    try {
      await ref.read(appearanceSettingsProvider.notifier).setNightMode(enabled);
    } catch (error) {
      _showMessage('Could not save night mode: $error', isError: true);
    }
  }

  Future<void> _useSystemTheme() async {
    try {
      await ref
          .read(appearanceSettingsProvider.notifier)
          .setThemeMode(ThemeMode.system);
    } catch (error) {
      _showMessage('Could not restore system theme: $error', isError: true);
    }
  }

  Future<void> _setAutoBackupEnabled(bool enabled) async {
    try {
      await ref.read(autoBackupSettingsProvider.notifier).setEnabled(enabled);
    } catch (error) {
      _showMessage(
        'Could not save automatic backup setting: $error',
        isError: true,
      );
    }
  }

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;
    final colors = Theme.of(context).colorScheme;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                isError ? Icons.error_outline : Icons.check_circle_outline,
                color: isError ? colors.error : colors.onInverseSurface,
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(message)),
            ],
          ),
        ),
      );
  }

  Future<void> _importRecipes() async {
    try {
      final result = await ref.read(recipesProvider.notifier).importFromFile();
      if (result == null) return;
      _showMessage(
        'Imported ${result.added} new, ${result.updated} updated, '
        '${result.skipped} unchanged',
      );
    } on RecipeImportException catch (error) {
      _showMessage(error.message, isError: true);
    } catch (error) {
      _showMessage('Import failed: $error', isError: true);
    }
  }

  Future<void> _backupRecipes() async {
    try {
      final recipes = await ref.read(recipesProvider.future);
      if (recipes.isEmpty) {
        _showMessage('Nothing to back up yet.');
        return;
      }
      final saved = await ref.read(recipesProvider.notifier).exportAll();
      if (saved) _showMessage('Recipe backup saved to device.');
    } catch (error) {
      _showMessage('Backup failed: $error', isError: true);
    }
  }

  Future<void> _restoreWeeklyBackup() async {
    final shouldRestore = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Restore automatic backup?'),
        content: const Text(
          'This replaces your current recipe library with the saved backup. '
          'Your current library will be kept as a safety copy.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Restore'),
          ),
        ],
      ),
    );
    if (shouldRestore != true || !mounted) return;

    try {
      final restored = await ref
          .read(recipesProvider.notifier)
          .restoreWeeklyBackup();
      ref.invalidate(weeklyBackupLastModifiedProvider);
      _showMessage('Restored ${restored.length} recipes from the backup.');
    } catch (error) {
      _showMessage('Could not restore automatic backup: $error', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final appearanceSettings = ref.watch(appearanceSettingsProvider);
    final autoBackupSettings = ref.watch(autoBackupSettingsProvider);
    final lastBackup = ref.watch(weeklyBackupLastModifiedProvider);
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: AppSpacing.pageInsets,
        children: [
          SectionPanel(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.panel),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SectionHeading(
                    title: 'Appearance',
                    icon: Icons.palette_outlined,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Choose how the app looks.',
                    style: Theme.of(context).textTheme.bodyMedium
                        ?.copyWith(color: colors.onSurfaceVariant),
                  ),
                  const SizedBox(height: AppSpacing.section),
                  appearanceSettings.when(
                    loading: () => const Center(
                      child: Padding(
                        padding: EdgeInsets.all(12),
                        child: CircularProgressIndicator(),
                      ),
                    ),
                    error: (error, _) => Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Could not load appearance settings: $error'),
                        TextButton(
                          onPressed: () =>
                              ref.invalidate(appearanceSettingsProvider),
                          child: const Text('Try again'),
                        ),
                      ],
                    ),
                    data: (settings) => Column(
                      children: [
                        DropdownButtonFormField<ThemeColor>(
                          initialValue: settings.themeColor,
                          decoration: const InputDecoration(
                            labelText: 'Theme color',
                          ),
                          items: ThemeColor.values
                              .map(
                                (color) => DropdownMenuItem(
                                  value: color,
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.circle,
                                        size: 16,
                                        color: color.seedColor,
                                      ),
                                      const SizedBox(width: 12),
                                      Text(
                                        color.name[0].toUpperCase() +
                                            color.name.substring(1),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (color) {
                            if (color != null) _selectThemeColor(color);
                          },
                        ),
                        const SizedBox(height: 8),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          secondary: Icon(
                            Icons.dark_mode_outlined,
                            color: colors.primary,
                          ),
                          title: const Text('Night mode'),
                          subtitle: Text(
                            settings.themeMode == ThemeMode.system
                                ? 'Following device settings'
                                : 'Use a dark appearance',
                          ),
                          value:
                              settings.themeMode == ThemeMode.dark ||
                              (settings.themeMode == ThemeMode.system &&
                                  MediaQuery.platformBrightnessOf(context) ==
                                      Brightness.dark),
                          onChanged: _setNightMode,
                        ),
                        if (settings.themeMode != ThemeMode.system)
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton.icon(
                              onPressed: _useSystemTheme,
                              icon: const Icon(Icons.settings_suggest_outlined),
                              label: const Text('Use system'),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.section),
          SectionPanel(
            emphasized: true,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.panel),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SectionHeading(
                    title: 'Back up and restore',
                    icon: Icons.backup_outlined,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Keep your recipe collection safe and move recipes between devices.',
                    style: Theme.of(context).textTheme.bodyMedium
                        ?.copyWith(color: colors.onSurfaceVariant),
                  ),
                  const SizedBox(height: AppSpacing.section),
                  autoBackupSettings.when(
                    loading: () => const ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.backup_outlined),
                      title: Text('Automatic weekly backup'),
                      trailing: SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                    error: (error, _) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        Icons.backup_outlined,
                        color: colors.primary,
                      ),
                      title: const Text('Automatic weekly backup'),
                      subtitle: Text('Could not load setting: $error'),
                      trailing: IconButton(
                        tooltip: 'Retry loading backup setting',
                        onPressed: () =>
                            ref.invalidate(autoBackupSettingsProvider),
                        icon: const Icon(Icons.refresh),
                      ),
                    ),
                    data: (settings) => SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      secondary: Icon(
                        Icons.backup_outlined,
                        color: colors.primary,
                      ),
                      title: const Text('Automatic weekly backup'),
                      subtitle: Text(
                        settings.enabled
                            ? 'Saved privately in the app; checked when you open OpenKuhnya.'
                            : 'Automatic backups are off.',
                      ),
                      value: settings.enabled,
                      onChanged: _setAutoBackupEnabled,
                    ),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      Icons.restore_outlined,
                      color: colors.primary,
                    ),
                    title: const Text('Restore automatic backup'),
                    subtitle: lastBackup.when(
                      loading: () => const Text('Loading last backup date…'),
                      error: (error, _) =>
                          Text('Could not load last backup date: $error'),
                      data: (date) => Text(
                        date == null
                            ? 'No automatic backup available'
                            : 'Last backup: ${MaterialLocalizations.of(context).formatMediumDate(date)}',
                      ),
                    ),
                    trailing: lastBackup.when(
                      loading: () => const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      error: (_, _) => IconButton(
                        tooltip: 'Retry loading backup date',
                        onPressed: () =>
                            ref.invalidate(weeklyBackupLastModifiedProvider),
                        icon: const Icon(Icons.refresh),
                      ),
                      data: (date) => IconButton(
                        tooltip: 'Restore automatic backup',
                        onPressed: date == null ? null : _restoreWeeklyBackup,
                        icon: const Icon(Icons.restore),
                      ),
                    ),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.save_alt, color: colors.primary),
                    title: const Text('Backup to device'),
                    subtitle: const Text('Save all recipes as a JSON file'),
                    onTap: _backupRecipes,
                  ),
                  const Divider(height: 1),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      Icons.file_open_outlined,
                      color: colors.primary,
                    ),
                    title: const Text('Import recipes from JSON'),
                    subtitle: const Text('Add recipes from a JSON file'),
                    onTap: _importRecipes,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          SectionPanel(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SectionHeading(
                    title: 'About',
                    icon: Icons.info_outline,
                  ),
                  const SizedBox(height: 8),
                  FutureBuilder<PackageInfo>(
                    future: _packageInfo,
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return Text(
                          'Could not load version: ${snapshot.error}',
                          style: Theme.of(context).textTheme.bodySmall,
                        );
                      }
                      if (!snapshot.hasData) {
                        return const SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        );
                      }
                      final info = snapshot.data!;
                      return Text(
                        'OpenKuhnya ${info.version} (${info.buildNumber})',
                        style: Theme.of(context).textTheme.bodyMedium
                            ?.copyWith(color: colors.onSurfaceVariant),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
