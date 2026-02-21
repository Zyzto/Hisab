import 'package:flutter_riverpod/legacy.dart' show StateProvider;

/// Direction for expense prev/next navigation when animating the body.
/// 1 = next (new content from right), -1 = prev (new content from left).
/// Null when not set (e.g. first load or after transition consumed it).
final expenseNavigationDirectionProvider =
    StateProvider<int?>((ref) => null);
