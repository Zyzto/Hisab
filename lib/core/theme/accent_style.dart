import 'package:flutter/material.dart';

/// Appearance preference: tone down decorative accent fills.
@immutable
class AccentStyleExtension extends ThemeExtension<AccentStyleExtension> {
  final bool subtleAccents;

  const AccentStyleExtension({this.subtleAccents = false});

  @override
  AccentStyleExtension copyWith({bool? subtleAccents}) {
    return AccentStyleExtension(
      subtleAccents: subtleAccents ?? this.subtleAccents,
    );
  }

  @override
  AccentStyleExtension lerp(
    ThemeExtension<AccentStyleExtension>? other,
    double t,
  ) {
    if (other is! AccentStyleExtension) return this;
    if (t < 0.5) return this;
    return other;
  }
}

extension AccentStyleContext on BuildContext {
  /// When true, prefer flat surfaces over accent gradients / tints.
  bool get subtleAccents =>
      Theme.of(this).extension<AccentStyleExtension>()?.subtleAccents ?? false;
}

/// Shared decorations for bordered panels and accent heroes.
abstract final class AccentSurfaces {
  /// Flat bordered surface used for list/form chrome.
  static BoxDecoration flatPanel(
    ColorScheme colorScheme, {
    double radius = 14,
  }) {
    return BoxDecoration(
      color: colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(
        color: colorScheme.outlineVariant.withValues(alpha: 0.45),
      ),
    );
  }

  /// Hero/summary panel; when [subtle] is true, matches [flatPanel].
  static BoxDecoration panel(
    ColorScheme colorScheme, {
    required bool subtle,
    Color? accentContainer,
    Color? accentBorder,
    double radius = 16,
  }) {
    if (subtle) return flatPanel(colorScheme, radius: radius);
    final container = accentContainer ?? colorScheme.primaryContainer;
    final border = accentBorder ?? colorScheme.primary;
    return BoxDecoration(
      borderRadius: BorderRadius.circular(radius),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          container.withValues(alpha: 0.9),
          colorScheme.surfaceContainerLow,
        ],
      ),
      border: Border.all(color: border.withValues(alpha: 0.14)),
    );
  }

  static Color sectionBar(ColorScheme colorScheme, {required bool subtle}) {
    return subtle ? colorScheme.outlineVariant : colorScheme.primary;
  }

  static Color emphasizedFill(ColorScheme colorScheme, {required bool subtle}) {
    return subtle
        ? colorScheme.surfaceContainerLow
        : colorScheme.primaryContainer.withValues(alpha: 0.35);
  }

  static Color emphasizedBorder(
    ColorScheme colorScheme, {
    required bool subtle,
  }) {
    return subtle
        ? colorScheme.outlineVariant.withValues(alpha: 0.45)
        : colorScheme.primary.withValues(alpha: 0.22);
  }
}

/// Applies [AccentStyleExtension] without dropping other theme extensions.
ThemeData withAccentStyle(ThemeData theme, {required bool subtleAccents}) {
  final exts = List<ThemeExtension<dynamic>>.from(
    theme.extensions.values.where((e) => e is! AccentStyleExtension),
  )..add(AccentStyleExtension(subtleAccents: subtleAccents));
  return theme.copyWith(extensions: exts);
}
