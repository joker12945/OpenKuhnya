import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recipe_box/providers/feature_tour_provider.dart';
import 'package:recipe_box/ui/widgets/feature_tour.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('feature tour completion is saved between launches', () async {
    SharedPreferences.setMockInitialValues({});
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(await container.read(featureTourSeenProvider.future), isFalse);

    await container.read(featureTourSeenProvider.notifier).markSeen();

    expect(container.read(featureTourSeenProvider).requireValue, isTrue);
    expect(
      (await SharedPreferences.getInstance()).getBool('feature_tour_seen'),
      isTrue,
    );
  });

  testWidgets('first launch shows the feature tour only once', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: FeatureTourLauncher(
            child: Scaffold(body: Text('Recipe Box home')),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('QUICK TUTORIAL'), findsOneWidget);
    expect(find.text('Welcome to OpenKuhnya'), findsOneWidget);
    for (final title in [
      'Find the right recipe',
      'Create or import recipes',
      'Make each recipe yours',
      'Cook step by step',
      'Keep a useful shopping list',
      'Share recipes',
      'Back up your collection',
      'Choose your look',
    ]) {
      expect(find.text(title), findsOneWidget);
    }
    expect(
      tester.widgetList<Icon>(find.byType(Icon)).map((icon) => icon.icon),
      [
        Icons.auto_stories_rounded,
        Icons.manage_search,
        Icons.note_add_outlined,
        Icons.tune,
        Icons.play_circle_outline,
        Icons.shopping_cart_outlined,
        Icons.share_outlined,
        Icons.backup_outlined,
        Icons.palette_outlined,
        Icons.check_rounded,
      ],
    );
    await tester.tap(find.text('Got it'));
    await tester.pumpAndSettle();

    expect(find.text('Welcome to OpenKuhnya'), findsNothing);
    expect(
      (await SharedPreferences.getInstance()).getBool('feature_tour_seen'),
      isTrue,
    );

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: FeatureTourLauncher(
            child: Scaffold(body: Text('Recipe Box home')),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Welcome to OpenKuhnya'), findsNothing);
  });

  testWidgets('feature tour can be replayed manually', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showFeatureTourDialog(context),
              child: const Text('Open quick tutorial'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open quick tutorial'));
    await tester.pumpAndSettle();

    expect(find.text('QUICK TUTORIAL'), findsOneWidget);
    expect(find.text('Welcome to OpenKuhnya'), findsOneWidget);
  });
}
