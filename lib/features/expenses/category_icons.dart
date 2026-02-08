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
