# OpenKuhnya

A Flutter app for saving, organizing, and cooking from personal recipes.

## Download

Get the latest Android APK and macOS DMG from the
[Releases page](https://github.com/joker12945/OpenKuhnya/releases/latest).

## Screenshots

<p align="center">
  <img src="https://github.com/user-attachments/assets/d1a525cf-c8a8-477c-a009-e6425ad65f90" alt="OpenKuhnya recipe list" width="30%" />
  <img src="https://github.com/user-attachments/assets/a815d6a2-83c0-4d11-9be7-747f5fd9e148" alt="OpenKuhnya shopping list" width="30%" />
  <img src="https://github.com/user-attachments/assets/66f68984-4f59-4c94-9311-ed349be4d23c" alt="OpenKuhnya settings" width="30%" />
</p>

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

## Install on Android

1. Download `OpenKuhnya.apk` from the latest release.
2. Open the downloaded file on your Android device.
3. If Android asks, allow your browser or Files app to install unknown apps.
4. Tap **Install**, then open OpenKuhnya.

## Install on macOS

1. Download `OpenKuhnya.dmg` from the latest release.
2. Open the DMG and drag OpenKuhnya to your Applications folder.
3. Open the app from Applications.

macOS may display a warning because the current release is not notarized by Apple.
Control-click the app, choose **Open**, then choose **Open** again.

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

The iOS project targets iOS 15.0 and later.

## Privacy and data

Recipes and shopping-list data are stored locally on your device. Recipe JSON
files can be imported and backed up from Settings.

## Import and export recipes

### Import from text

From the recipe list, choose **Import from text**. Paste a recipe, then review
and edit its title, ingredients, and method steps before saving. Each
blank-line-separated paragraph in the ingredient or method field becomes one
ingredient or cooking step.

### Import a recipe or backup file

In **Settings**, choose **Import recipes from JSON** and select an OpenKuhnya
JSON file. Imported recipes are merged with your current library: new recipes
are added, changed recipes are updated, and unchanged recipes are skipped. The
app saves a safety copy of your current library before importing.

### Export and back up

- Open a recipe, use its menu, and choose **Export** to save one recipe as a
  JSON file.
- In **Settings**, choose **Backup to device** to save all recipes as one JSON
  backup file.
- You can enable automatic weekly backups in **Settings**. They stay in the
  app's private storage and can be restored from the same screen.

## Development

Run the app:

```bash
flutter run
```

Validate the project:

```bash
flutter analyze
flutter test
```

## License

OpenKuhnya is available under the [MIT License](LICENSE).
