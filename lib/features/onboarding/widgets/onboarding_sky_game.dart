import 'package:flame/camera.dart' as flame_camera;
import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flame/parallax.dart';
import 'package:flutter/material.dart';

import '../../../core/platform/ui_perf.dart';
import 'onboarding_celestial.dart';

/// Onboarding meadow via Flame [ParallaxComponent] + real layer images.
///
/// Sky is a single non-tiling layer (avoids seams). Hills/grass scroll with
/// `repeatX`. The sun/moon is drawn procedurally by [OnboardingCelestial] so it
/// can animate. Assets under `assets/images/parallax/`.
class OnboardingSkyGame extends FlameGame {
  OnboardingSkyGame({
    required bool night,
    Color accent = const Color(0xFF64B5F6),
  })  : _night = night,
        _accent = accent;

  bool _night;
  Color _accent;
  final List<Component> _sceneComponents = [];
  bool _loading = false;

  bool get night => _night;
  Color get accent => _accent;

  bool get _cheap => UiPerf.preferCheapCharts;

  void applyTheme({required bool night, required Color accent}) {
    if (_night == night && _accent == accent) return;
    _night = night;
    _accent = accent;
    if (hasLayout) {
      _reloadParallax();
    }
  }

  @override
  Color backgroundColor() => const Color(0x00000000);

  @override
  Future<void> onLoad() async {
    await _reloadParallax();
  }

  String _path(String name) =>
      _night ? 'parallax/${name}_night.webp' : 'parallax/$name.webp';

  Future<void> _reloadParallax() async {
    if (_loading) return;
    _loading = true;
    try {
      for (final component in _sceneComponents) {
        component.removeFromParent();
      }
      _sceneComponents.clear();

      final base = _cheap ? 14.0 : 22.0;
      final delta = _cheap ? 1.55 : 1.75;

      // Per-layer load so sky can avoid repeatX (AI sky is not seamless).
      final sky = await loadParallaxLayer(
        ParallaxImageData(_path('bg')),
        velocityMultiplier: Vector2.zero(),
        // Not tileable — cover viewport once, no horizontal repeat seams.
        repeat: ImageRepeat.noRepeat,
        // Keep the upper-right sun/moon visible when a wide sky is cropped
        // into a narrow portrait viewport.
        alignment: Alignment.topRight,
        fill: LayerFill.height,
        filterQuality: FilterQuality.medium,
      );
      // `medium` rather than `high`: these layers are minified 3-4x, and only
      // medium is mipmapped. Cubic without mipmaps aliases the silhouettes and
      // makes them shimmer while scrolling (and costs more).
      final far = await loadParallaxLayer(
        ParallaxImageData(_path('hills_far')),
        velocityMultiplier: Vector2(1, 1),
        repeat: ImageRepeat.repeatX,
        alignment: Alignment.bottomCenter,
        fill: LayerFill.height,
        filterQuality: FilterQuality.medium,
      );
      final mid = await loadParallaxLayer(
        ParallaxImageData(_path('hills_mid')),
        velocityMultiplier: Vector2(delta, 1),
        repeat: ImageRepeat.repeatX,
        alignment: Alignment.bottomCenter,
        fill: LayerFill.height,
        filterQuality: FilterQuality.medium,
      );
      final grass = await loadParallaxLayer(
        ParallaxImageData(_path('grass')),
        velocityMultiplier: Vector2(delta * delta, 1),
        repeat: ImageRepeat.repeatX,
        alignment: Alignment.bottomCenter,
        fill: LayerFill.height,
        filterQuality: FilterQuality.medium,
      );
      final front = await loadParallaxLayer(
        ParallaxImageData(_path('grass_front')),
        velocityMultiplier: Vector2(delta * delta * delta, 1),
        repeat: ImageRepeat.repeatX,
        alignment: Alignment.bottomCenter,
        fill: LayerFill.height,
        filterQuality: FilterQuality.medium,
      );

      final skyComponent = ParallaxComponent<OnboardingSkyGame>(
        parallax: Parallax(
          [sky],
          baseVelocity: Vector2.zero(),
        ),
        priority: 0,
      );
      final components = <Component>[
        skyComponent,
        // Sits above the sky but below the hills, so the body can set behind
        // the horizon rather than floating over it.
        OnboardingCelestial(night: _night, priority: 1),
        _BottomParallaxComponent(
          parallax: Parallax([far], baseVelocity: Vector2(base, 0)),
          heightFactor: 0.26,
          priority: 2,
        ),
        _BottomParallaxComponent(
          parallax: Parallax([mid], baseVelocity: Vector2(base, 0)),
          heightFactor: 0.36,
          priority: 3,
        ),
        _BottomParallaxComponent(
          parallax: Parallax(
            [grass],
            baseVelocity: Vector2(base, 0),
          ),
          heightFactor: 0.25,
          priority: 4,
        ),
        _BottomParallaxComponent(
          parallax: Parallax(
            [front],
            baseVelocity: Vector2(base, 0),
          ),
          heightFactor: 0.20,
          priority: 5,
        ),
      ];
      _sceneComponents.addAll(components);
      for (final component in components) {
        await camera.viewport.add(component);
      }
    } finally {
      _loading = false;
    }
  }
}

/// Gives a tightly cropped image strip only the portion of the viewport that
/// it should occupy, instead of stretching it over the full screen.
class _BottomParallaxComponent
    extends ParallaxComponent<OnboardingSkyGame> {
  _BottomParallaxComponent({
    required Parallax parallax,
    required this.heightFactor,
    required int priority,
  }) : super(
         parallax: parallax,
         size: Vector2.zero(),
         priority: priority,
       );

  final double heightFactor;

  @override
  void onGameResize(Vector2 canvasSize) {
    super.onGameResize(canvasSize);
    final availableSize = parent is flame_camera.Viewport
        ? (parent! as flame_camera.Viewport).virtualSize
        : canvasSize;
    size.setValues(availableSize.x, availableSize.y * heightFactor);
    position.setValues(0, availableSize.y - size.y);
    parallax?.resize(size);
  }
}
