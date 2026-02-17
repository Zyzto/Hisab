import 'dart:io' show File;

import 'package:flutter/material.dart';

import '../../../core/theme/theme_config.dart';

bool screenshotFileExists(String path) {
  try {
    return File(path).existsSync();
  } catch (_) {
    return false;
  }
}

Widget buildScreenshotThumbnail(String path) {
  return ClipRRect(
    borderRadius: BorderRadius.circular(ThemeConfig.radiusM),
    child: Image.file(
      File(path),
      height: 120,
      width: double.infinity,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => const SizedBox.shrink(),
    ),
  );
}
