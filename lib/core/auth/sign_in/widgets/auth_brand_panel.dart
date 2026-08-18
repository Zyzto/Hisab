import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../platform/ui_perf.dart';
import '../../../theme/accent_style.dart';
import '../../../widgets/app_brand_mark.dart';

/// The meadow panel shown beside the sign-in form on desktop.
///
/// Onboarding greets people with the parallax meadow, then sign-in used to drop
/// them onto a bare card that could have belonged to any app. This puts the same
/// horizon back in view so the two screens read as one product.
///
/// The layers are plain [Image.asset] rather than the Flame
/// `OnboardingSkyGame`: nothing here scrolls or animates, and a game loop for a
/// static backdrop would cost a ticker and would not render under `flutter
/// test`. Only the far hills and the front grass are used — the mid layers are
/// 1.4-1.8MB each and add nothing at this width.
class AuthBrandPanel extends StatelessWidget {
  const AuthBrandPanel({super.key, this.width = 320});

  final double width;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final night = theme.brightness == Brightness.dark;
    // Decode at the size we paint, not the source resolution.
    final cacheWidth = (width * MediaQuery.devicePixelRatioOf(context)).round();

    return RepaintBoundary(
      child: ExcludeSemantics(
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                cs.primaryContainer.withValues(
                  alpha: context.subtleAccents ? 0.35 : 0.65,
                ),
                cs.surfaceContainerLow,
              ],
            ),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // The art sits along the bottom edge and the copy along the top,
              // so the text never needs a scrim to stay legible.
              if (!UiPerf.preferCheapCharts) ...[
                _Layer(
                  asset: night
                      ? 'assets/images/parallax/hills_far_night.webp'
                      : 'assets/images/parallax/hills_far.webp',
                  cacheWidth: cacheWidth,
                ),
                _Layer(
                  asset: night
                      ? 'assets/images/parallax/grass_front_night.webp'
                      : 'assets/images/parallax/grass_front.webp',
                  cacheWidth: cacheWidth,
                ),
              ],
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const AppBrandMark(size: 56),
                    const SizedBox(height: 16),
                    Text(
                      'app_name'.tr(),
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'auth_brand_tagline'.tr(),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: cs.onSurfaceVariant,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Layer extends StatelessWidget {
  const _Layer({required this.asset, required this.cacheWidth});

  final String asset;
  final int cacheWidth;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomCenter,
      child: Image.asset(
        asset,
        fit: BoxFit.fitWidth,
        alignment: Alignment.bottomCenter,
        cacheWidth: cacheWidth,
        excludeFromSemantics: true,
        // Decoration only. A missing or undecodable layer should leave the
        // gradient and the copy standing, not tear down the sign-in dialog.
        errorBuilder: (_, _, _) => const SizedBox.shrink(),
      ),
    );
  }
}
