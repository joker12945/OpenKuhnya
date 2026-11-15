import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum ThemeColor {
  red(Color(0xFFC62828)),
  green(Color(0xFF3F7D58)),
  blue(Color(0xFF1565C0)),
  cyan(Color(0xFF0097A7)),
  magenta(Color(0xFFC2185B)),
  yellow(Color(0xFFF9A825));

  const ThemeColor(this.seedColor);

  final Color seedColor;
}

class AppearanceSettings {
  const AppearanceSettings({
    this.themeColor = ThemeColor.green,
    this.themeMode = ThemeMode.system,
  });

  final ThemeColor themeColor;
  final ThemeMode themeMode;

  AppearanceSettings copyWith({ThemeColor? themeColor, ThemeMode? themeMode}) =>
      AppearanceSettings(
        themeColor: themeColor ?? this.themeColor,
        themeMode: themeMode ?? this.themeMode,
      );
}

final appearanceSettingsProvider =
    AsyncNotifierProvider<AppearanceSettingsNotifier, AppearanceSettings>(
      AppearanceSettingsNotifier.new,
    );

final autoBackupSettingsProvider =
    AsyncNotifierProvider<AutoBackupSettingsNotifier, AutoBackupSettings>(
      AutoBackupSettingsNotifier.new,
    );

class AutoBackupSettings {
  const AutoBackupSettings({this.enabled = true});

  final bool enabled;
}

class AutoBackupSettingsNotifier extends AsyncNotifier<AutoBackupSettings> {
  static const _enabledKey = 'automatic_weekly_backup_enabled';

  @override
  Future<AutoBackupSettings> build() async {
    final preferences = await SharedPreferences.getInstance();
    return AutoBackupSettings(
      enabled: preferences.getBool(_enabledKey) ?? true,
    );
  }

  Future<void> setEnabled(bool enabled) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_enabledKey, enabled);
    state = AsyncData(AutoBackupSettings(enabled: enabled));
  }
}

class AppearanceSettingsNotifier extends AsyncNotifier<AppearanceSettings> {
  static const _themeModeKey = 'theme_mode';
  static const _themeColorKey = 'theme_color';
  static const _nightModeKey = 'night_mode';

  @override
  Future<AppearanceSettings> build() async {
    final preferences = await SharedPreferences.getInstance();
    final savedColor = preferences.getString(_themeColorKey);
    final savedMode = preferences.getString(_themeModeKey);
    final savedNightMode = preferences.getBool(_nightModeKey);
    final legacyMode = ThemeMode.values.where(
      (mode) => mode.name == savedMode,
    );

    return AppearanceSettings(
      themeColor: ThemeColor.values.firstWhere(
        (color) => color.name == savedColor,
        orElse: () => ThemeColor.green,
      ),
      themeMode: savedNightMode != null
          ? savedNightMode
                ? ThemeMode.dark
                : ThemeMode.light
          : legacyMode.firstOrNull ?? ThemeMode.system,
    );
  }

  Future<void> setThemeColor(ThemeColor color) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_themeColorKey, color.name);
    state = AsyncData(state.requireValue.copyWith(themeColor: color));
  }

  Future<void> setNightMode(bool enabled) =>
      setThemeMode(enabled ? ThemeMode.dark : ThemeMode.light);

  Future<void> setThemeMode(ThemeMode mode) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_themeModeKey, mode.name);
    await preferences.remove(_nightModeKey);
    state = AsyncData(state.requireValue.copyWith(themeMode: mode));
  }
}
