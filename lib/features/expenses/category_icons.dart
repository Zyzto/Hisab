import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../../../domain/domain.dart';

/// Preset expense categories with Material icons. [id] is stored when selected.
const List<({String id, String label, IconData icon})> presetCategoryTags = [
  (id: 'food', label: 'Food', icon: Icons.restaurant),
  (id: 'groceries', label: 'Groceries', icon: Icons.shopping_cart),
  (id: 'transport', label: 'Transport', icon: Icons.directions_car),
  (id: 'shopping', label: 'Shopping', icon: Icons.shopping_bag),
  (id: 'entertainment', label: 'Entertainment', icon: Icons.movie_outlined),
  (id: 'bills', label: 'Bills & Utilities', icon: Icons.receipt_long),
  (id: 'health', label: 'Health', icon: Icons.local_hospital_outlined),
  (id: 'personal', label: 'Personal', icon: Icons.person_outline),
  (id: 'coffee', label: 'Coffee & Drinks', icon: Icons.coffee),
  (id: 'travel', label: 'Travel', icon: Icons.flight),
  (id: 'subscriptions', label: 'Subscriptions', icon: Icons.subscriptions),
  (id: 'education', label: 'Education', icon: Icons.school_outlined),
  (id: 'gifts', label: 'Gifts & Donations', icon: Icons.card_giftcard_outlined),
];

/// Icon names for custom tag icon picker. Keys stored in [ExpenseTag.iconName].
const Map<String, IconData> selectableCategoryIcons = {
  'restaurant': Icons.restaurant,
  'shopping_cart': Icons.shopping_cart,
  'directions_car': Icons.directions_car,
  'shopping_bag': Icons.shopping_bag,
  'movie_outlined': Icons.movie_outlined,
  'receipt_long': Icons.receipt_long,
  'local_hospital_outlined': Icons.local_hospital_outlined,
  'person_outline': Icons.person_outline,
  'coffee': Icons.coffee,
  'flight': Icons.flight,
  'subscriptions': Icons.subscriptions,
  'school_outlined': Icons.school_outlined,
  'card_giftcard_outlined': Icons.card_giftcard_outlined,
  'label': Icons.label_outlined,
  'home': Icons.home_outlined,
  'fitness': Icons.fitness_center,
  'pets': Icons.pets,
  'local_gas_station': Icons.local_gas_station,
  'restaurant_menu': Icons.restaurant_menu,
};

/// Default icon when no tag or unknown tag.
const IconData defaultExpenseIcon = Icons.receipt_long;

/// WCAG AA contrast target for normal text.
const double kTagTextContrastRatio = 4.5;

/// Stable seed colors per preset category (hue stays consistent across themes).
const Map<String, Color> _presetTagColors = {
  'food': Color(0xFFE67E22),
  'groceries': Color(0xFF2EAD5B),
  'transport': Color(0xFF3B82F6),
  'shopping': Color(0xFFEC4899),
  'entertainment': Color(0xFF8B5CF6),
  'bills': Color(0xFF64748B),
  'health': Color(0xFFEF4444),
  'personal': Color(0xFF14B8A6),
  'coffee': Color(0xFFA16207),
  'travel': Color(0xFF0EA5E9),
  'subscriptions': Color(0xFF6366F1),
  'education': Color(0xFFD97706),
  'gifts': Color(0xFFF43F5E),
};

/// Fallback palette for custom / unknown tags (picked by stable hash of id).
const List<Color> _customTagPalette = [
  Color(0xFF0D9488),
  Color(0xFF2563EB),
  Color(0xFFDB2777),
  Color(0xFFCA8A04),
  Color(0xFF7C3AED),
  Color(0xFF059669),
  Color(0xFFEA580C),
  Color(0xFF0891B2),
];

/// Resolved colors for rendering a tag with readable text/icons.
class ExpenseTagChrome {
  /// Brand accent for the tag (borders, soft fills).
  final Color accent;

  /// Background for filled chips / icon badges.
  final Color container;

  /// Text/icon color on [container] (meets [kTagTextContrastRatio]).
  final Color onContainer;

  /// Accent tuned to sit on [surface] (list icons, outline chips).
  final Color onSurface;

  const ExpenseTagChrome({
    required this.accent,
    required this.container,
    required this.onContainer,
    required this.onSurface,
  });
}

/// Returns the icon for an expense tag (preset id or custom tag id).
IconData iconForExpenseTag(String? tagId, List<ExpenseTag>? customTags) {
  if (tagId == null || tagId.isEmpty) return defaultExpenseIcon;
  for (final t in presetCategoryTags) {
    if (t.id == tagId) return t.icon;
  }
  final customTag = customTags?.where((t) => t.id == tagId).firstOrNull;
  if (customTag != null) {
    return selectableCategoryIcons[customTag.iconName] ?? Icons.label_outlined;
  }
  return defaultExpenseIcon;
}

/// Memorable accent color for a category/tag. Same id → same color every time.
///
/// Prefer [chromeForExpenseTag] when painting text or icons so contrast stays
/// readable.
Color colorForExpenseTag(
  String? tagId, {
  Brightness brightness = Brightness.light,
}) {
  return chromeForExpenseTag(
    tagId,
    brightness: brightness,
    surface: brightness == Brightness.dark
        ? const Color(0xFF121212)
        : const Color(0xFFFFFFFF),
  ).accent;
}

/// Contrast-safe colors for a tag against the current surface.
///
/// Uses a solid accent [ExpenseTagChrome.container] with black/white
/// [ExpenseTagChrome.onContainer] so label + icon stay clearly readable.
ExpenseTagChrome chromeForExpenseTag(
  String? tagId, {
  required Brightness brightness,
  required Color surface,
}) {
  final base = _rawTagColor(tagId);
  // Keep accents vivid; darken slightly in light mode if needed so white text
  // can pass AA on the solid fill. Lighten a touch in dark mode for presence.
  var accent = base;
  if (brightness == Brightness.dark) {
    accent = Color.lerp(base, Colors.white, 0.12) ?? base;
  } else if (contrastRatio(Colors.white, base) < kTagTextContrastRatio &&
      contrastRatio(const Color(0xFF0F172A), base) < kTagTextContrastRatio) {
    // Extremely mid-luminance oddities: nudge darker for white text.
    accent = Color.lerp(base, const Color(0xFF0F172A), 0.25) ?? base;
  }

  // Solid fill = memorable color; on-color is pure black/white for max contrast.
  final container = accent;
  final onContainer = contrastingForeground(container);
  // If solid accent still can't host white/black at AA (rare), darken fill.
  final ensuredContainer =
      contrastRatio(onContainer, container) >= kTagTextContrastRatio
      ? container
      : (Color.lerp(container, const Color(0xFF0F172A), 0.35) ?? container);
  final ensuredOn = contrastingForeground(ensuredContainer);

  final onSurface = readableOnBackground(
    accent,
    surface,
    minRatio: kTagTextContrastRatio,
  );

  return ExpenseTagChrome(
    accent: accent,
    container: ensuredContainer,
    onContainer: ensuredOn,
    onSurface: onSurface,
  );
}

/// WCAG contrast ratio between two colors.
double contrastRatio(Color a, Color b) {
  final l1 = a.computeLuminance();
  final l2 = b.computeLuminance();
  final lighter = math.max(l1, l2);
  final darker = math.min(l1, l2);
  return (lighter + 0.05) / (darker + 0.05);
}

/// Black or white — whichever has the higher contrast on [background].
Color contrastingForeground(Color background) {
  const dark = Color(0xFF0F172A);
  const light = Color(0xFFFFFFFF);
  return contrastRatio(dark, background) >= contrastRatio(light, background)
      ? dark
      : light;
}

/// Adjusts [color] toward black/white until it meets [minRatio] on [background].
Color readableOnBackground(
  Color color,
  Color background, {
  double minRatio = kTagTextContrastRatio,
}) {
  if (contrastRatio(color, background) >= minRatio) return color;

  final bgLum = background.computeLuminance();
  final towardDark = bgLum > 0.45;
  final target = towardDark ? const Color(0xFF0F172A) : Colors.white;

  for (var t = 0.05; t <= 1.0001; t += 0.05) {
    final candidate = Color.lerp(color, target, t)!;
    if (contrastRatio(candidate, background) >= minRatio) return candidate;
  }
  return contrastingForeground(background);
}

Color _rawTagColor(String? tagId) {
  if (tagId == null || tagId.isEmpty) return const Color(0xFF64748B);
  return _presetTagColors[tagId] ?? _colorForCustomTag(tagId);
}

Color _colorForCustomTag(String tagId) {
  var hash = 0;
  for (final unit in tagId.codeUnits) {
    hash = (hash * 31 + unit) & 0x7fffffff;
  }
  return _customTagPalette[hash % _customTagPalette.length];
}
