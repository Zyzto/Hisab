import 'dart:math' as math;

import 'package:collection/collection.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/debug/integration_test_mode.dart';
import '../../../core/platform/ui_perf.dart';
import '../../../core/widgets/app_fab_nature.dart';
import '../../../core/widgets/user_text.dart';
import '../../../domain/domain.dart';
import '../../settings/providers/settings_framework_providers.dart';
import '../category_icons.dart';
import '../constants/expense_form_constants.dart';

/// Ghost "Category" chip that breathes until a tag is chosen, then settles with
/// an AppFab-style elastic pop + leaf burst.
class CategoryAffordanceChip extends ConsumerStatefulWidget {
  const CategoryAffordanceChip({
    super.key,
    required this.selectedTag,
    required this.customTags,
    required this.onTap,
  });

  final String? selectedTag;
  final List<ExpenseTag> customTags;
  final VoidCallback onTap;

  @override
  ConsumerState<CategoryAffordanceChip> createState() =>
      _CategoryAffordanceChipState();
}

class _CategoryAffordanceChipState extends ConsumerState<CategoryAffordanceChip>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  /// Faster, bouncier idle loop for a cartoony “tap me” feel.
  static const _breathDuration = Duration(milliseconds: 1100);
  static const _settleDuration = Duration(milliseconds: 620);

  late final AnimationController _breathController;
  late final AnimationController _settleController;
  late final AnimationController _leafController;

  final math.Random _rng = math.Random();
  List<AppFabLeafSpec> _leaves = const [];
  String? _prevTag;
  bool _initialized = false;
  bool _motionAllowed = true;

  bool get _isTagged =>
      widget.selectedTag != null && widget.selectedTag!.isNotEmpty;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _breathController = AnimationController(
      vsync: this,
      duration: _breathDuration,
    );
    _settleController = AnimationController(
      vsync: this,
      duration: _settleDuration,
    );
    _leafController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 720),
    );
    _prevTag = widget.selectedTag;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _syncMotionAllowed();
      _initialized = true;
      if (!_isTagged && _motionAllowed) {
        _breathController.repeat(reverse: true);
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _breathController.dispose();
    _settleController.dispose();
    _leafController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _resumeBreathIfNeeded();
    } else if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      _breathController.stop();
    }
  }

  @override
  void didUpdateWidget(covariant CategoryAffordanceChip oldWidget) {
    super.didUpdateWidget(oldWidget);
    final prev = _prevTag;
    final next = widget.selectedTag;
    _prevTag = next;

    if (!_initialized) return;

    final prevTagged = prev != null && prev.isNotEmpty;
    final nextTagged = next != null && next.isNotEmpty;

    if (!prevTagged && nextTagged) {
      _playSettle(full: true);
    } else if (prevTagged && nextTagged && prev != next) {
      _playSettle(full: false);
    } else if (prevTagged && !nextTagged) {
      _settleController.stop();
      _settleController.value = 0;
      _leafController.stop();
      _leafController.value = 0;
      _resumeBreathIfNeeded();
    }
  }

  bool _platformAllowsBreath() {
    // Match AppFab: release-web integration minifies binding type names, so
    // string checks miss TestWidgetsFlutterBinding — prefer the explicit flag.
    if (isIntegrationTestMode) return false;
    final binding = WidgetsBinding.instance.runtimeType.toString();
    if (binding.contains('TestWidgetsFlutterBinding')) return false;
    return true;
  }

  void _syncMotionAllowed() {
    final settingOn = ref.read(extraAnimationsEnabledProvider);
    final disableAnims = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    _motionAllowed = !UiPerf.preferReducedChromeMotion &&
        !isIntegrationTestMode &&
        _platformAllowsBreath() &&
        !disableAnims &&
        settingOn;
  }

  void _resumeBreathIfNeeded() {
    _syncMotionAllowed();
    if (!_isTagged && _motionAllowed && !_breathController.isAnimating) {
      _breathController.repeat(reverse: true);
    }
  }

  void _playSettle({required bool full}) {
    _breathController.stop();
    _breathController.value = 0;
    _syncMotionAllowed();
    if (!_motionAllowed) {
      _settleController.value = 0;
      _leafController.value = 0;
      setState(() {});
      return;
    }
    HapticFeedback.lightImpact();
    if (full) {
      setState(() => _leaves = generateCategoryChipLeaves(_rng));
      _leafController.forward(from: 0);
    } else {
      _leaves = const [];
      _leafController.value = 0;
    }
    _settleController.forward(from: 0);
  }

  (String label, IconData icon, ExpenseTagChrome? chrome) _resolve() {
    final tag = widget.selectedTag;
    final theme = Theme.of(context);
    if (tag == null || tag.isEmpty) {
      return ('category'.tr(), Icons.label_outlined, null);
    }
    final preset = presetExpenseTags.firstWhereOrNull((p) => p.id == tag);
    if (preset != null) {
      return (
        'category_${preset.id}'.tr(),
        preset.icon,
        chromeForExpenseTag(
          tag,
          brightness: theme.brightness,
          surface: theme.colorScheme.surface,
          customTags: widget.customTags,
        ),
      );
    }
    final custom = widget.customTags.firstWhereOrNull((t) => t.id == tag);
    if (custom != null) {
      return (
        custom.label,
        selectableExpenseIcons[custom.iconName] ?? Icons.label_outlined,
        chromeForExpenseTag(
          tag,
          brightness: theme.brightness,
          surface: theme.colorScheme.surface,
          customTags: widget.customTags,
        ),
      );
    }
    return (
      tag,
      Icons.label_outlined,
      chromeForExpenseTag(
        tag,
        brightness: theme.brightness,
        surface: theme.colorScheme.surface,
        customTags: widget.customTags,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settingOn = ref.watch(extraAnimationsEnabledProvider);
    final nextAllowed = !UiPerf.preferReducedChromeMotion &&
        !isIntegrationTestMode &&
        _platformAllowsBreath() &&
        !(MediaQuery.maybeOf(context)?.disableAnimations ?? false) &&
        settingOn;
    if (nextAllowed != _motionAllowed) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _motionAllowed = nextAllowed;
        if (_isTagged) {
          _breathController.stop();
        } else if (_motionAllowed) {
          _resumeBreathIfNeeded();
        } else {
          _breathController.stop();
          _breathController.value = 0;
        }
        setState(() {});
      });
    }

    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final (label, icon, chrome) = _resolve();
    final tagged = _isTagged;

    return AnimatedBuilder(
      animation: Listenable.merge([
        _breathController,
        _settleController,
        _leafController,
      ]),
      builder: (context, _) {
        final rawT = (!_motionAllowed || tagged)
            ? (_motionAllowed ? 0.0 : 0.55)
            : _breathController.value;
        // EaseInOutBack-ish bounce without overshooting too hard.
        final breathT = Curves.easeInOutBack.transform(rawT.clamp(0.0, 1.0))
            .clamp(0.0, 1.2);

        final settleT = _settleController.value.clamp(0.0, 1.0);
        final settleScale = tagged && _settleController.isAnimating
            ? 1.0 + 0.1 * math.sin(Curves.easeOut.transform(settleT) * math.pi)
            : 1.0;

        // Cartoony idle: squash/stretch from center + icon wiggle (no upward hop).
        final pulse = tagged ? 0.0 : math.sin(breathT * math.pi);
        final idleScaleX = tagged ? 1.0 : 1.0 + 0.07 * pulse;
        final idleScaleY = tagged ? 1.0 : 1.0 - 0.05 * pulse;
        final iconWiggle = tagged
            ? 0.0
            : math.sin(breathT * math.pi * 2) * (10 * math.pi / 180);

        final borderAlpha = tagged ? 0.0 : (0.35 + 0.55 * rawT);
        final fillAlpha = tagged ? 1.0 : (0.06 + 0.16 * rawT);
        final fg = tagged
            ? chrome!.onContainer
            : Color.lerp(cs.onSurfaceVariant, cs.primary, rawT)!;
        final borderColor = tagged
            ? Colors.transparent
            : cs.primary.withValues(alpha: borderAlpha);

        final chip = Semantics(
          button: true,
          selected: tagged,
          label: label,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: widget.onTap,
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: tagged
                      ? chrome!.container
                      : cs.primary.withValues(alpha: fillAlpha),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    width: tagged ? 1 : (1.2 + 0.8 * rawT),
                    color: tagged
                        ? chrome!.accent.withValues(alpha: 0.0)
                        : borderColor,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Transform.rotate(
                      angle: iconWiggle,
                      child: Icon(icon, size: 18, color: fg),
                    ),
                    const SizedBox(width: 6),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 88),
                      child: tagged
                          ? UserText(
                              label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: fg,
                                fontWeight: FontWeight.w600,
                              ),
                            )
                          : Text(
                              label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: fg,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );

        return RepaintBoundary(
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              // Positioned + OverflowBox so the 96px burst never imposes a
              // min-width on the chip (tight suffix slots were crashing with
              // BoxConstraints(96<=w<=~92; NOT NORMALIZED)).
              if (_leafController.value > 0 && _leaves.isNotEmpty)
                Positioned.fill(
                  child: IgnorePointer(
                    child: OverflowBox(
                      alignment: Alignment.center,
                      minWidth: 96,
                      maxWidth: 96,
                      minHeight: 40,
                      maxHeight: 40,
                      child: Transform.scale(
                        scale: 0.55,
                        child: CustomPaint(
                          size: AppFabNaturePainter.paintSize,
                          painter: AppFabNaturePainter(
                            leafProgress: _leafController.value,
                            leaves: _leaves,
                            bloomProgress: 0,
                            plantKind: null,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              Transform(
                alignment: Alignment.center,
                transform: Matrix4.diagonal3Values(
                  idleScaleX * settleScale,
                  idleScaleY * settleScale,
                  1,
                ),
                child: chip,
              ),
            ],
          ),
        );
      },
    );
  }
}
