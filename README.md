# OpenKuhnya

A Flutter app for saving, organizing, and cooking from personal recipes.

## Features

- Create, edit, search, import, and export recipes.
- Import copied recipe text offline with separate ingredient and method inputs.
- Scale ingredient quantities to a different serving count.
- Add individual ingredients to a persistent shopping list, combining duplicate
  ingredients when their units match.
- Mark shopping-list items as bought, remove them, or clear all bought items.
- Share the shopping list as readable text.
- Keep the screen awake while viewing a recipe.
- Browse recipes by favorites, tags, and cooking time, or sort by title and speed.
- Filter by multiple tags and ingredients, see active filters, and clear them
  all at once.
- Follow recipe steps one at a time in cooking mode.
- Automatically keep a weekly recipe backup in app storage when the app opens,
  with a Settings toggle and the last backup date.
- Restore the automatic backup from Settings; the current recipe library is
  preserved as a safety copy before restoring.
- Choose a red, green, or blue theme color and toggle night mode in Settings.
  The app follows the device theme by default, with an option to switch back.
- View the app version in Settings.
- See a quick tutorial on first launch, reopenable from the recipe list.

Recipes and the shopping list are stored locally in the app's documents
directory. Recipe JSON files can be imported and backed up to the device from
Settings. In text import, each
blank-line-separated paragraph becomes one ingredient or method step. Review
the assembled recipe before saving.

## Install on iPhone

There is no iOS download in the GitHub Releases yet. You cannot install an iPhone
app directly from this repository like an Android APK; an iOS build must be
signed and distributed through Apple's supported options, such as TestFlight
or the App Store.

To build and run OpenKuhnya from source on your own iPhone, you need a Mac with
Flutter and Xcode installed:

1. Clone this repository and open a Terminal in the project folder.
2. Fetch the Flutter packages:

   ```bash
   flutter pub get
   ```

3. Open the iOS workspace in Xcode:

   ```bash
   open ios/Runner.xcworkspace
   ```

4. In Xcode, select the **Runner** target, open **Signing & Capabilities**, and
   select your Apple development team. Connect your iPhone, select it as the
   run destination, then click **Run**.

The iOS project currently targets iOS 15.0 and later. To distribute the app to
other people, configure Apple distribution signing and publish through
TestFlight or the App Store.

## Development

Run the app with `flutter run` and validate it with `flutter analyze` and
`flutter test`.
