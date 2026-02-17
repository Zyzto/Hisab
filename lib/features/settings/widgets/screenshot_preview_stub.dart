import 'package:flutter/material.dart';

/// Stub: no screenshot preview on web (no dart:io).

bool screenshotFileExists(String path) => false;

Widget buildScreenshotThumbnail(String path) => const SizedBox.shrink();
