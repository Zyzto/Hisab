import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../category_icons.dart';

/// Restricts input to digits and at most one decimal point (e.g. 12.34).
class DecimalOnlyFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final t = newValue.text;
    if (t.isEmpty) return newValue;
    if (RegExp(r'^\d*\.?\d*$').hasMatch(t)) return newValue;
    return oldValue;
  }
}

final decimalOnlyFormatter = DecimalOnlyFormatter();

/// Preset expense categories — canonical list lives in [presetCategoryTags].
const List<({String id, String label, IconData icon})> presetExpenseTags =
    presetCategoryTags;

/// Icon names for custom tag icon picker — canonical map in [selectableCategoryIcons].
const Map<String, IconData> selectableExpenseIcons = selectableCategoryIcons;

/// Max number of photos per expense (form + gallery).
const int kMaxExpenseImages = 5;
