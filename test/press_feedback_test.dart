import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recipe_box/ui/widgets/press_feedback.dart';

void main() {
  testWidgets('scales down while pressed and returns to normal on release', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: PressFeedback(
              child: SizedBox(
                key: Key('press-feedback-target'),
                width: 100,
                height: 100,
                child: ColoredBox(color: Colors.green),
              ),
            ),
          ),
        ),
      ),
    );

    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(const Key('press-feedback-target'))),
    );
    await tester.pump(const Duration(milliseconds: 55));
    expect(
      tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale,
      lessThan(1),
    );

    await gesture.up();
    await tester.pumpAndSettle();
    expect(tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale, 1);
  });
}
