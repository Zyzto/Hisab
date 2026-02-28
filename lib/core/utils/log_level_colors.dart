import 'package:flutter/material.dart';

/// Log-level colors for terminal-style log viewers (e.g. logs viewer dialog).
/// Uses brightness to pick dark/light variants so they work with app theme.
class LogLevelColors {
  LogLevelColors._();

  /// Background color for the log content area.
  static Color containerBackground(ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
    return isDark
        ? const Color(0xFF0D1117)
        : const Color(0xFFF6F8FA);
  }

  /// Returns the color for a log line based on level markers, or null for default text color.
  static Color? levelColorForLine(String line, Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    if (line.contains('[DEBUG]')) {
      return isDark ? const Color(0xFF8B949E) : const Color(0xFF57606A);
    }
    if (line.contains('[INFO]')) {
      return isDark ? const Color(0xFF58A6FF) : const Color(0xFF0969DA);
    }
    if (line.contains('[WARNING]') || line.contains('[WARN]')) {
      return isDark ? const Color(0xFFD29922) : const Color(0xFF9A6700);
    }
    if (line.contains('[ERROR]') || line.contains('[SEVERE]')) {
      return isDark ? const Color(0xFFF85149) : const Color(0xFFCF222E);
    }
    if (line.contains('=== MAIN LOG ===') ||
        line.contains('=== CRASH LOG ===') ||
        line.contains('... (showing last ')) {
      return isDark ? const Color(0xFF7EE787) : const Color(0xFF1A7F37);
    }
    return null;
  }
}
