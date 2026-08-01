import 'package:flame/game.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hisab/core/celebration/celebration_fx.dart';
import 'package:hisab/core/celebration/celebration_game.dart';
import 'package:hisab/core/celebration/celebration_kind.dart';
import 'package:hisab/core/celebration/scenes/celebration_scenes.dart';
import 'package:hisab/core/celebration/scenes/dusk_scene.dart';
import 'package:hisab/core/celebration/scenes/forest_scene.dart';
import 'package:hisab/core/celebration/scenes/grove_scene.dart';
import 'package:hisab/core/celebration/scenes/jungle_scene.dart';
import 'package:hisab/core/celebration/scenes/plants_scene.dart';
import 'package:hisab/core/celebration/scenes/sea_scene.dart';
import 'package:hisab/core/celebration/scenes/sky_scene.dart';

void main() {
  test('celebrationDuration maps each kind', () {
    expect(
      celebrationDuration(CelebrationKind.firstExpense).inMilliseconds,
      3200,
    );
    expect(
      celebrationDuration(CelebrationKind.newExpense).inMilliseconds,
      2200,
    );
    expect(
      celebrationDurationSeconds(CelebrationKind.settlement),
      closeTo(2.6, 0.001),
    );
  });

  test('celebrationSceneType matches biome components', () {
    expect(
      celebrationSceneType(CelebrationKind.firstExpense),
      ForestScene,
    );
    expect(celebrationSceneType(CelebrationKind.newExpense), PlantsScene);
    expect(celebrationSceneType(CelebrationKind.settlement), SeaScene);
    expect(celebrationSceneType(CelebrationKind.personJoined), JungleScene);
    expect(celebrationSceneType(CelebrationKind.personLeft), SkyScene);
    expect(celebrationSceneType(CelebrationKind.newGroup), GroveScene);
    expect(
      celebrationSceneType(CelebrationKind.newPersonalList),
      DuskScene,
    );
  });

  test('celebrationSceneAlpha fades in and out', () {
    expect(celebrationSceneAlpha(0), 0);
    expect(celebrationSceneAlpha(0.5), 1);
    expect(celebrationSceneAlpha(1), lessThan(0.05));
    expect(celebrationSceneAlpha(0.06), greaterThan(0.3));
  });

  test('CelebrationGame completes after duration', () async {
    var completed = false;
    final game = CelebrationGame(
      kind: CelebrationKind.newExpense,
      onComplete: () => completed = true,
    );

    game.onGameResize(Vector2(400, 800));
    await game.load();
    await game.ready();

    expect(completed, isFalse);
    game.debugAdvance(celebrationDurationSeconds(CelebrationKind.newExpense));
    expect(completed, isTrue);
    expect(game.progress, 1.0);
  });

  test('CelebrationGame builds a scene for every kind', () async {
    for (final kind in CelebrationKind.values) {
      var completed = false;
      final game = CelebrationGame(
        kind: kind,
        onComplete: () => completed = true,
      );
      game.onGameResize(Vector2(390, 844));
      await game.load();
      await game.ready();

      final expectedType = celebrationSceneType(kind);
      expect(
        game.camera.viewport.children.any((c) => c.runtimeType == expectedType),
        isTrue,
        reason: 'missing scene for $kind '
            '(viewport: ${game.camera.viewport.children.map((c) => c.runtimeType).toList()})',
      );

      game.debugAdvance(celebrationDurationSeconds(kind) + 0.05);
      expect(completed, isTrue, reason: 'did not complete for $kind');
    }
  });
}
