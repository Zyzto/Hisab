import 'package:flame/game.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../settings/providers/settings_framework_providers.dart';
import 'onboarding_ambient.dart';
import 'onboarding_sky_game.dart';

/// Flame meadow behind onboarding via image [ParallaxComponent] layers.
///
/// Skipped when Extra animations are off, UiPerf reduced chrome motion (iOS
/// web), or under widget tests.
class OnboardingSkyBackdrop extends ConsumerWidget {
  const OnboardingSkyBackdrop({super.key});

  static bool get _testBinding {
    final name = WidgetsBinding.instance.runtimeType.toString();
    return name.contains('TestWidgetsFlutterBinding');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (_testBinding || !onboardingAmbientAllowed) {
      return const SizedBox.shrink();
    }
    if (!ref.watch(extraAnimationsEnabledProvider)) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final night = theme.brightness == Brightness.dark;
    final accent = theme.colorScheme.primary;
    return Positioned.fill(
      child: IgnorePointer(
        child: RepaintBoundary(
          child: _OnboardingSkyHost(night: night, accent: accent),
        ),
      ),
    );
  }
}

class _OnboardingSkyHost extends StatefulWidget {
  const _OnboardingSkyHost({required this.night, required this.accent});

  final bool night;
  final Color accent;

  @override
  State<_OnboardingSkyHost> createState() => _OnboardingSkyHostState();
}

class _OnboardingSkyHostState extends State<_OnboardingSkyHost> {
  late final OnboardingSkyGame _game = OnboardingSkyGame(
    night: widget.night,
    accent: widget.accent,
  );

  @override
  void didUpdateWidget(covariant _OnboardingSkyHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Keep one GameWidget attachment — recreating caused load/attach races.
    _game.applyTheme(night: widget.night, accent: widget.accent);
  }

  @override
  void dispose() {
    _game.pauseEngine();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GameWidget<OnboardingSkyGame>(
      game: _game,
      loadingBuilder: (_) => const SizedBox.shrink(),
      errorBuilder: (_, error) {
        if (kDebugMode) {
          debugPrint('OnboardingSkyGame error: $error');
        }
        return const SizedBox.shrink();
      },
    );
  }
}
