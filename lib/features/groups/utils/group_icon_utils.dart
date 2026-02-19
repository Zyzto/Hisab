import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Group icon definitions (shared between wizard and settings)
// ─────────────────────────────────────────────────────────────────────────────

class GroupIconOption {
  final String key;
  final IconData icon;
  final String labelKey;

  const GroupIconOption(this.key, this.icon, this.labelKey);
}

/// Special key indicating the avatar should show the group name's first letter.
const groupIconLetterKey = 'letter';

const groupIcons = [
  GroupIconOption(groupIconLetterKey, Icons.sort_by_alpha, 'wizard_icon_initials'),
  GroupIconOption('trip', Icons.flight, 'wizard_icon_trip'),
  GroupIconOption('home', Icons.home_outlined, 'wizard_icon_home'),
  GroupIconOption('food', Icons.restaurant_outlined, 'wizard_icon_food'),
  GroupIconOption('shopping', Icons.shopping_cart_outlined, 'wizard_icon_shopping'),
  GroupIconOption('event', Icons.celebration_outlined, 'wizard_icon_event'),
  GroupIconOption('camping', Icons.terrain_outlined, 'wizard_icon_camping'),
  GroupIconOption('work', Icons.work_outline, 'wizard_icon_work'),
  GroupIconOption('sports', Icons.sports_soccer_outlined, 'wizard_icon_sports'),
  GroupIconOption('car', Icons.directions_car_outlined, 'wizard_icon_car'),
  GroupIconOption('heart', Icons.favorite_outline, 'wizard_icon_heart'),
  GroupIconOption('school', Icons.school_outlined, 'wizard_icon_school'),
];

const groupColors = [
  Color(0xFFC62828), // red
  Color(0xFFAD1457), // pink
  Color(0xFF6A1B9A), // purple
  Color(0xFF283593), // indigo
  Color(0xFF1565C0), // blue
  Color(0xFF0097A7), // cyan
  Color(0xFF00838F), // teal
  Color(0xFF2E7D32), // green
  Color(0xFFF57F17), // amber
  Color(0xFFEF6C00), // orange
  Color(0xFF5D4037), // brown
  Color(0xFF37474F), // blue-grey
];

/// Returns the [IconData] for a group icon key, or `null` if the key is
/// unknown, null, or [groupIconLetterKey] (which means "show first letter").
IconData? groupIconFromKey(String? key) {
  if (key == null || key == groupIconLetterKey) return null;
  for (final opt in groupIcons) {
    if (opt.key == key) return opt.icon;
  }
  return null;
}
