import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hisab/features/onboarding/widgets/onboarding_sky_game.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('parallax meadow loads assets and applies theme', (tester) async {
    final game = OnboardingSkyGame(
      night: false,
      accent: const Color(0xFF64B5F6),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GameWidget<OnboardingSkyGame>(
            game: game,
            errorBuilder: (_, error) => Text('ERR: $error'),
          ),
        ),
      ),
    );
    // Allow Flame to load parallax images from assets.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));
    expect(find.textContaining('ERR:'), findsNothing);
    expect(tester.takeException(), isNull);

    game.applyTheme(night: true, accent: const Color(0xFFCE93D8));
    await tester.pump(const Duration(milliseconds: 800));
    expect(find.textContaining('ERR:'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
