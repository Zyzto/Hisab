import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/settings/providers/settings_framework_providers.dart';
import '../debug/integration_test_mode.dart';
import '../platform/ui_perf.dart';
import '../theme/theme_config.dart';
import 'app_fab_nature.dart';

/// Ensures only one [AppFab] in a cluster runs idle wiggle/bloom at a time.
class AppFabAmbientSlot {
  Object? _holder;

  bool tryAcquire(Object holder) {
    if (_holder == null || identical(_holder, holder)) {
      _holder = holder;
      return true;
    }
    return false;
  }

  void release(Object holder) {
    if (identical(_holder, holder)) _holder = null;
  }
}

/// Shared cartoony floating action button.
///
/// Press: squash/stretch + elastic pop + leaf burst.
/// Idle: finite icon wiggle on mount, then occasional plant blooms
/// (flower / sunflower / dandelion) when ambient nature is allowed.
///
/// Extra motion is skipped when [UiPerf.preferReducedChromeMotion] or the user
/// turns off [extraAnimationsEnabledProvider] in Settings → Appearance.
/// Pass a shared [ambientSlot] when multiple FABs are shown together so only
/// one idle animation runs at a time. Set [playIdleMotion] false to skip
/// wiggle/bloom while keeping press motion.
class AppFab extends ConsumerStatefulWidget {
  const AppFab({
    super.key,
    required this.icon,
    required this.onPressed,
    this.onLongPress,
    this.tooltip,
    this.semanticsLabel,
    this.heroTag,
    this.label,
    this.backgroundColor,
    this.foregroundColor,
    this.ambientSlot,
    this.playIdleMotion = true,
    this.previewAmbientBloom = false,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final VoidCallback? onLongPress;
  final String? tooltip;
  final String? semanticsLabel;
  final Object? heroTag;
  final String? label;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final AppFabAmbientSlot? ambientSlot;

  /// When false, skips mount wiggle and ambient plant blooms (press still animates).
  final bool playIdleMotion;

  /// Debug playground: blooms start quickly, and each press advances through
  /// every plant kind (solo, then bouquets) so they can be reviewed in order.
  final bool previewAmbientBloom;

  static const double size = 56;
  static const double iconSize = 28;

  /// Occasional idle plant blooms (uses [Timer]). Off in widget tests by default
  /// via test `setUp` so pending timers do not fail [testWidgets].
  @visibleForTesting
  static bool enableAmbientNature = true;

  @override
  ConsumerState<AppFab> createState() => _AppFabState();
}

class _AppFabState extends ConsumerState<AppFab>
    with TickerProviderStateMixin {
  static const Duration _pressInDuration = Duration(milliseconds: 90);
  static const Duration _releaseDuration = Duration(milliseconds: 320);
  static const Duration _releaseReducedDuration = Duration(milliseconds: 160);
  static const Duration _wiggleDuration = Duration(milliseconds: 1500);
  static const Duration _leafDuration = Duration(milliseconds: 720);
  /// ~0.9s grow + 10s windy stay + ~1.1s leave.
  static const Duration _bloomDuration = Duration(milliseconds: 12000);
  /// Shorter cycle in the debug FAB playground.
  static const Duration _bloomPreviewDuration = Duration(milliseconds: 4000);
  /// Lets the leaf burst / pop read before navigation replaces the route.
  static const Duration _actionDelay = Duration(milliseconds: 380);

  /// Solo pass over every kind, then bouquet pass with classic heroes.
  static final List<(AppFabPlantKind, bool)> _previewBloomCatalog = [
    for (final kind in AppFabPlantKind.values) (kind, false),
    for (final kind in appFabOriginalPlantKinds) (kind, true),
  ];

  late final AnimationController _pressController;
  late final AnimationController _releaseController;
  late final AnimationController _wiggleController;
  late final AnimationController _leafController;
  late final AnimationController _bloomController;

  final math.Random _rng = math.Random();

  bool _held = false;
  bool _extras = true;
  bool _wiggleStarted = false;
  double _lastCompress = 0;

  List<AppFabLeafSpec> _leaves = const [];
  AppFabPlantKind? _plantKind;
  bool _bloomBouquet = false;
  int _previewBloomIndex = 0;
  Timer? _ambientTimer;
  Timer? _actionTimer;

  @override
  void initState() {
    super.initState();

    _pressController = AnimationController(
      vsync: this,
      duration: _pressInDuration,
    );
    _releaseController = AnimationController(
      vsync: this,
      duration: _releaseDuration,
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed && mounted) {
          _releaseController.value = 0;
          _lastCompress = 0;
        }
      });
    _wiggleController = AnimationController(
      vsync: this,
      duration: _wiggleDuration,
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed && mounted) {
          _releaseAmbientSlot();
          _scheduleAmbientBloom(
            delay: widget.previewAmbientBloom
                ? const Duration(milliseconds: 600)
                : null,
          );
        }
      });
    _leafController = AnimationController(
      vsync: this,
      duration: _leafDuration,
    );
    _bloomController = AnimationController(
      vsync: this,
      duration: widget.previewAmbientBloom
          ? _bloomPreviewDuration
          : _bloomDuration,
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed && mounted) {
          _bloomController.value = 0;
          _plantKind = null;
          _bloomBouquet = false;
          _releaseAmbientSlot();
          // Preview mode is tap-driven; don't auto-queue the next bloom.
          if (!widget.previewAmbientBloom) {
            _scheduleAmbientBloom();
          }
        }
      });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _applyExtrasSetting(ref.read(extraAnimationsEnabledProvider));
      if (_extras) _startWiggleIfNeeded();
    });
  }

  @override
  void dispose() {
    _ambientTimer?.cancel();
    _actionTimer?.cancel();
    _releaseAmbientSlot();
    _pressController.dispose();
    _releaseController.dispose();
    _wiggleController.dispose();
    _leafController.dispose();
    _bloomController.dispose();
    super.dispose();
  }

  bool _acquireAmbientSlot() {
    final slot = widget.ambientSlot;
    if (slot == null) return true;
    return slot.tryAcquire(this);
  }

  void _releaseAmbientSlot() {
    widget.ambientSlot?.release(this);
  }

  bool _platformAllowsExtras() => !UiPerf.preferReducedChromeMotion;

  void _disableExtrasEffects() {
    _ambientTimer?.cancel();
    _ambientTimer = null;
    _wiggleController.stop();
    _wiggleController.value = 0;
    _leafController.stop();
    _leafController.value = 0;
    _bloomController.stop();
    _bloomController.value = 0;
    _leaves = const [];
    _plantKind = null;
    _bloomBouquet = false;
    _wiggleStarted = false;
    _releaseAmbientSlot();
  }

  void _startWiggleIfNeeded() {
    if (!_extras || !widget.playIdleMotion || _wiggleStarted || !mounted) {
      return;
    }
    if (!_acquireAmbientSlot()) {
      // Peer FAB is animating; retry until the shared slot is free.
      _ambientTimer?.cancel();
      _ambientTimer = Timer(const Duration(milliseconds: 450), () {
        if (mounted) _startWiggleIfNeeded();
      });
      return;
    }
    _wiggleStarted = true;
    _wiggleController.forward(from: 0);
  }

  void _applyExtrasSetting(bool settingEnabled) {
    final next = _platformAllowsExtras() && settingEnabled;
    _releaseController.duration =
        next ? _releaseDuration : _releaseReducedDuration;
    final was = _extras;
    _extras = next;
    if (!next) {
      _disableExtrasEffects();
    } else if (!was) {
      _startWiggleIfNeeded();
    }
  }

  bool get _ambientAllowed {
    if (!_extras ||
        !widget.playIdleMotion ||
        !AppFab.enableAmbientNature ||
        !mounted) {
      return false;
    }
    // Release-web integration minifies binding type names, so string checks
    // miss TestWidgetsFlutterBinding — prefer the explicit test flag.
    if (isIntegrationTestMode) return false;
    final binding = WidgetsBinding.instance.runtimeType.toString();
    if (binding.contains('TestWidgetsFlutterBinding')) return false;
    return true;
  }

  void _scheduleAmbientBloom({Duration? delay}) {
    _ambientTimer?.cancel();
    if (!_ambientAllowed) return;
    // Debug playground: only the first auto bloom; further kinds via tap.
    if (widget.previewAmbientBloom && delay == null) return;
    final wait =
        delay ?? Duration(milliseconds: 8000 + _rng.nextInt(10000));
    _ambientTimer = Timer(wait, () {
      if (!_ambientAllowed) return;
      if (_bloomController.isAnimating || _leafController.isAnimating) {
        _scheduleAmbientBloom(delay: const Duration(milliseconds: 600));
        return;
      }
      if (!_acquireAmbientSlot()) {
        // Another FAB in the cluster is busy; try again soon.
        _scheduleAmbientBloom(delay: const Duration(milliseconds: 600));
        return;
      }
      if (widget.previewAmbientBloom) {
        _startPreviewBloom();
        return;
      }
      setState(() {
        // Classic original kinds as hero; sometimes a multi-plant bouquet too.
        _plantKind = appFabOriginalPlantKinds[
            _rng.nextInt(appFabOriginalPlantKinds.length)];
        _bloomBouquet = _rng.nextBool();
      });
      _bloomController
        ..duration = _bloomDuration
        ..forward(from: 0);
    });
  }

  /// Advances through [_previewBloomCatalog], restarting the bloom immediately.
  void _startPreviewBloom() {
    _ambientTimer?.cancel();
    if (!_extras || !mounted) return;
    if (!_acquireAmbientSlot()) {
      _releaseAmbientSlot();
      _acquireAmbientSlot();
    }
    final entry = _previewBloomCatalog[
        _previewBloomIndex % _previewBloomCatalog.length];
    _previewBloomIndex++;
    setState(() {
      _plantKind = entry.$1;
      _bloomBouquet = entry.$2;
    });
    // Skip grow — land in the stay phase so each tap shows the next plant now.
    _bloomController
      ..duration = _bloomPreviewDuration
      ..value = AppFabBloomTimeline.growEnd
      ..forward();
  }

  void _burstLeaves() {
    if (!_extras) return;
    setState(() => _leaves = generateAppFabLeaves(_rng));
    _leafController.forward(from: 0);
  }

  void _queuePressed() {
    final cb = widget.onPressed;
    if (cb == null) return;
    _burstLeaves();
    if (widget.previewAmbientBloom && _extras) {
      _startPreviewBloom();
    }
    _actionTimer?.cancel();
    // Integration / reduced-motion: invoke immediately so tests and a11y
    // paths do not depend on a wall-clock Timer after the press animation.
    if (!_extras || isIntegrationTestMode) {
      cb();
      return;
    }
    _actionTimer = Timer(_actionDelay, () {
      _actionTimer = null;
      cb();
    });
  }

  void _onTapDown(TapDownDetails _) {
    if (widget.onPressed == null) return;
    _held = true;
    _releaseController.stop();
    _releaseController.value = 0;
    _lastCompress = 0;
    _pressController.forward();
    HapticFeedback.lightImpact();
  }

  void _onTapCancel() {
    _finishPress(invoke: false);
  }

  void _finishPress({required bool invoke}) {
    if (!_held && _pressController.value == 0) {
      if (invoke) _queuePressed();
      return;
    }
    _held = false;
    _lastCompress = _pressController.value;
    _pressController.value = 0;
    _releaseController.forward(from: 0);
    if (invoke) _queuePressed();
  }

  void _onLongPress() {
    if (widget.onLongPress == null) return;
    HapticFeedback.mediumImpact();
    widget.onLongPress!();
  }

  double _squashAmount() {
    if (_held || _pressController.isAnimating) {
      return Curves.easeOut.transform(_pressController.value);
    }
    if (_releaseController.isAnimating || _releaseController.value > 0) {
      final raw = _releaseController.value.clamp(0.0, 1.0);
      final t = (_extras ? Curves.elasticOut : Curves.easeOutCubic)
          .transform(raw);
      return _lastCompress * (1.0 - t);
    }
    return 0;
  }

  (double, double) _buttonScale() {
    final s = _squashAmount();
    if (_extras) {
      return (1.0 + 0.08 * s, 1.0 - 0.14 * s);
    }
    return (1.0 - 0.08 * s, 1.0 - 0.08 * s);
  }

  double _iconWiggleRadians() {
    if (!_extras || _wiggleController.isDismissed) return 0;
    final t = _wiggleController.value;
    final envelope = (1.0 - t) * (1.0 - t);
    return math.sin(t * math.pi * 2 * 2.5) * envelope * (12 * math.pi / 180);
  }

  double _iconPressScale() {
    final s = _squashAmount().clamp(0.0, 1.0);
    return 1.0 - 0.06 * s;
  }

  @override
  Widget build(BuildContext context) {
    final settingOn = ref.watch(extraAnimationsEnabledProvider);
    final nextExtras = _platformAllowsExtras() && settingOn;
    if (nextExtras != _extras) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _applyExtrasSetting(settingOn);
        if (mounted) setState(() {});
      });
    }
    // Use the resolved flag for this frame so press/nature match the setting
    // even before the post-frame sync runs.
    _extras = nextExtras;
    _releaseController.duration =
        _extras ? _releaseDuration : _releaseReducedDuration;

    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final bg = widget.backgroundColor ?? scheme.primary;
    final fg = widget.foregroundColor ?? scheme.onPrimary;
    final deeper = Color.lerp(bg, Colors.black, 0.18) ?? bg;
    final radius = BorderRadius.circular(ThemeConfig.radiusXL);
    final tip = widget.tooltip ?? widget.label;

    Widget button = Semantics(
      button: true,
      enabled: widget.onPressed != null,
      label: widget.semanticsLabel ?? tip,
      child: AnimatedBuilder(
        animation: Listenable.merge([
          _pressController,
          _releaseController,
          _wiggleController,
          _leafController,
          _bloomController,
        ]),
        builder: (context, child) {
          final (sx, sy) = _buttonScale();
          final pressedVisual = _squashAmount() > 0.05;
          return SizedBox(
            width: AppFab.size,
            height: AppFab.size,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                if (_extras)
                  Positioned(
                    left: (AppFabNaturePainter.fabSize -
                            AppFabNaturePainter.paintSize.width) /
                        2,
                    // Bias canvas upward so heads grow above the FAB; stems root on it.
                    top: (AppFabNaturePainter.fabSize -
                                AppFabNaturePainter.paintSize.height) /
                            2 -
                        AppFabNaturePainter.paintLift,
                    child: IgnorePointer(
                      child: CustomPaint(
                        size: AppFabNaturePainter.paintSize,
                        painter: AppFabNaturePainter(
                          leafProgress: _leafController.value,
                          leaves: _leaves,
                          bloomProgress: _bloomController.value,
                          plantKind: _plantKind,
                          bouquet: _bloomBouquet,
                        ),
                      ),
                    ),
                  ),
                Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.diagonal3Values(sx, sy, 1),
                  child: _FabSurface(
                    size: AppFab.size,
                    radius: radius,
                    background: bg,
                    deeper: deeper,
                    shadowColor: scheme.shadow,
                    outlineVariant: scheme.outlineVariant,
                    pressed: pressedVisual,
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: radius,
                        splashColor: Colors.transparent,
                        highlightColor: Colors.transparent,
                        // Visual press on down/up; invoke via onTap so
                        // tester.tap / semantics activation always fire.
                        onTapDown:
                            widget.onPressed == null ? null : _onTapDown,
                        onTapUp: widget.onPressed == null
                            ? null
                            : (_) => _finishPress(invoke: false),
                        onTapCancel:
                            widget.onPressed == null ? null : _onTapCancel,
                        onTap: widget.onPressed == null
                            ? null
                            : _queuePressed,
                        onLongPress: widget.onLongPress == null
                            ? null
                            : _onLongPress,
                        child: SizedBox(
                          width: AppFab.size,
                          height: AppFab.size,
                          child: Center(
                            child: Transform.rotate(
                              angle: _iconWiggleRadians(),
                              child: Transform.scale(
                                scale: _iconPressScale(),
                                child: Icon(
                                  widget.icon,
                                  color: fg,
                                  size: AppFab.iconSize,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );

    if (tip != null && tip.isNotEmpty) {
      button = Tooltip(message: tip, child: button);
    }
    if (widget.heroTag != null) {
      button = Hero(tag: widget.heroTag!, child: button);
    }

    final label = widget.label;
    if (label == null) return button;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        button,
        const SizedBox(height: 6),
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: scheme.onSurface,
          ),
        ),
      ],
    );
  }
}

class _FabSurface extends StatelessWidget {
  const _FabSurface({
    required this.size,
    required this.radius,
    required this.background,
    required this.deeper,
    required this.shadowColor,
    required this.outlineVariant,
    required this.pressed,
    required this.child,
  });

  final double size;
  final BorderRadius radius;
  final Color background;
  final Color deeper;
  final Color shadowColor;
  final Color outlineVariant;
  final bool pressed;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final cheap = UiPerf.preferCheapShadows;
    final decoration = BoxDecoration(
      borderRadius: radius,
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [background, deeper],
      ),
      border: cheap
          ? Border.all(color: outlineVariant.withValues(alpha: 0.55))
          : null,
      boxShadow: cheap
          ? [
              BoxShadow(
                color: shadowColor.withValues(alpha: pressed ? 0.08 : 0.12),
                blurRadius: pressed ? 1 : 2,
                offset: Offset(0, pressed ? 0.5 : 1),
              ),
            ]
          : [
              BoxShadow(
                color: shadowColor.withValues(alpha: pressed ? 0.18 : 0.28),
                blurRadius: pressed ? 10 : 18,
                offset: Offset(0, pressed ? 3 : 8),
              ),
              BoxShadow(
                color: shadowColor.withValues(alpha: pressed ? 0.06 : 0.1),
                blurRadius: pressed ? 3 : 6,
                offset: Offset(0, pressed ? 1 : 2),
              ),
            ],
    );

    return Container(
      width: size,
      height: size,
      decoration: decoration,
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }
}
