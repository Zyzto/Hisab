import 'package:flutter/material.dart';

import '../../../theme/accent_style.dart';
import '../../../widgets/app_brand_mark.dart';

/// Branded header for the sign-in sheet.
///
/// The modal used to open with a bare line of body text, which made the one
/// screen where a stranger decides whether to trust Hisab the only screen in
/// the app with no sign of Hisab on it.
///
/// The headline carries this header, so it gets the full width and a display
/// weight rather than sharing a row with the mark. The accent behind it is a
/// wash that fades out instead of a bordered panel: a box around a greeting
/// reads as an alert, which is the opposite of a welcome.
class AuthHero extends StatelessWidget {
  const AuthHero({
    super.key,
    required this.headline,
    required this.subtitle,
    this.showMark = true,
  });

  final String headline;
  final String subtitle;

  /// False when a brand panel is alongside, which already shows the mark.
  /// Two Hisab logos on one dialog read as a mistake.
  final bool showMark;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final align = showMark ? TextAlign.center : TextAlign.start;

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            cs.primaryContainer.withValues(
              alpha: context.subtleAccents ? 0.18 : 0.30,
            ),
            cs.primaryContainer.withValues(alpha: 0.0),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 18, 14, 14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: showMark
              ? CrossAxisAlignment.center
              : CrossAxisAlignment.start,
          children: [
            if (showMark) ...[
              const AppBrandMark(size: 56),
              const SizedBox(height: 12),
            ],
            Text(
              headline,
              textAlign: align,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
                height: 1.15,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: align,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: cs.onSurfaceVariant,
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
