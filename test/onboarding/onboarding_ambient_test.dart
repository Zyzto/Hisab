import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hisab/features/onboarding/widgets/onboarding_ambient.dart';

void main() {
  testWidgets('OnboardingBreathing builds child', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: OnboardingBreathing(child: Text('logo'))),
      ),
    );
    expect(find.text('logo'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('logo'), findsOneWidget);
  });

  testWidgets('OnboardingIconPulse builds child', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: OnboardingIconPulse(phase: 0.2, child: Icon(Icons.star)),
        ),
      ),
    );
    expect(find.byIcon(Icons.star), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byIcon(Icons.star), findsOneWidget);
  });
}
