import 'package:flame/components.dart';

import '../celebration_kind.dart';
import 'dusk_scene.dart';
import 'forest_scene.dart';
import 'grove_scene.dart';
import 'jungle_scene.dart';
import 'plants_scene.dart';
import 'sea_scene.dart';
import 'sky_scene.dart';

Component buildCelebrationScene(CelebrationKind kind) {
  return switch (kind) {
    CelebrationKind.firstExpense => ForestScene(),
    CelebrationKind.newExpense => PlantsScene(),
    CelebrationKind.settlement => SeaScene(),
    CelebrationKind.personJoined => JungleScene(),
    CelebrationKind.personLeft => SkyScene(),
    CelebrationKind.newGroup => GroveScene(),
    CelebrationKind.newPersonalList => DuskScene(),
  };
}

/// Type of scene component for a kind (tests / debug).
Type celebrationSceneType(CelebrationKind kind) {
  return switch (kind) {
    CelebrationKind.firstExpense => ForestScene,
    CelebrationKind.newExpense => PlantsScene,
    CelebrationKind.settlement => SeaScene,
    CelebrationKind.personJoined => JungleScene,
    CelebrationKind.personLeft => SkyScene,
    CelebrationKind.newGroup => GroveScene,
    CelebrationKind.newPersonalList => DuskScene,
  };
}
