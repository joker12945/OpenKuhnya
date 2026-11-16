import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'providers/settings_provider.dart';
import 'ui/widgets/feature_tour.dart';
import 'ui/widgets/app_spacing.dart';
import 'ui/screens/recipe_list_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: RecipeBoxApp()));
}

class RecipeBoxApp extends ConsumerWidget {
  const RecipeBoxApp({super.key});

  static const _seed = Color(0xFF3F7D58);

  ThemeData _theme(Color seed, Brightness brightness) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: brightness,
      dynamicSchemeVariant: DynamicSchemeVariant.tonalSpot,
    );
    final buttonOverlayColor = WidgetStateProperty.resolveWith<Color?>((
      states,
    ) {
      if (states.contains(WidgetState.pressed)) {
        return colorScheme.primary.withValues(alpha: 0.12);
      }
      if (states.contains(WidgetState.hovered) ||
          states.contains(WidgetState.focused)) {
        return colorScheme.primary.withValues(alpha: 0.08);
      }
      return null;
    });
    const radius = BorderRadius.all(Radius.circular(20));
    final outline = OutlineInputBorder(
      borderRadius: radius,
      borderSide: BorderSide(color: colorScheme.outline),
    );
    final focusedOutline = OutlineInputBorder(
      borderRadius: radius,
      borderSide: BorderSide(color: colorScheme.primary, width: 2),
    );
    final errorOutline = OutlineInputBorder(
      borderRadius: radius,
      borderSide: BorderSide(color: colorScheme.error),
    );
    final focusedErrorOutline = OutlineInputBorder(
      borderRadius: radius,
      borderSide: BorderSide(color: colorScheme.error, width: 2),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      appBarTheme: AppBarTheme(
        centerTitle: false,
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        titleTextStyle: TextStyle(
          color: colorScheme.onSurface,
          fontSize: 24,
          fontWeight: FontWeight.w700,
        ),
        elevation: 0,
        scrolledUnderElevation: 0,
        toolbarHeight: 72,
        actionsPadding: const EdgeInsets.only(right: 8),
      ),
      cardTheme: CardThemeData(
        color: colorScheme.surfaceContainerLow,
        elevation: 0,
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: colorScheme.outlineVariant),
          borderRadius: BorderRadius.all(
            Radius.circular(AppSpacing.cardRadius),
          ),
        ),
      ),
      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(64, 52),
          animationDuration: const Duration(milliseconds: 140),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ).copyWith(overlayColor: buttonOverlayColor),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(64, 52),
          animationDuration: const Duration(milliseconds: 140),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ).copyWith(overlayColor: buttonOverlayColor),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(48, 48),
          animationDuration: const Duration(milliseconds: 140),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ).copyWith(overlayColor: buttonOverlayColor),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(Size(48, 48)),
          overlayColor: buttonOverlayColor,
          animationDuration: const Duration(milliseconds: 140),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
        ),
      ),
      checkboxTheme: CheckboxThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        side: BorderSide(color: colorScheme.outlineVariant),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: colorScheme.primary,
        minVerticalPadding: 12,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      dividerTheme: DividerThemeData(
        color: colorScheme.outlineVariant.withValues(alpha: 0.65),
        thickness: 1,
        space: 24,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.48),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 18,
        ),
        border: outline,
        enabledBorder: outline,
        focusedBorder: focusedOutline,
        errorBorder: errorOutline,
        focusedErrorBorder: focusedErrorOutline,
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appearance = ref
        .watch(appearanceSettingsProvider)
        .maybeWhen<AppearanceSettings?>(
          data: (settings) => settings,
          orElse: () => null,
        );
    final seedColor = appearance?.themeColor.seedColor ?? _seed;
    final themeMode = appearance?.themeMode ?? ThemeMode.system;

    return MaterialApp(
      title: 'OpenKuhnya',
      debugShowCheckedModeBanner: false,
      theme: _theme(seedColor, Brightness.light),
      darkTheme: _theme(seedColor, Brightness.dark),
      themeMode: themeMode,
      home: const FeatureTourLauncher(child: RecipeListScreen()),
    );
  }
}
