import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../layout/responsive_sheet.dart';
import 'receipt_utils.dart';

void showExpenseImageFullScreen(BuildContext context, String imagePath) {
  if (isImageUrl(imagePath)) {
    _showUnavailable(context);
    return;
  }
  final file = File(imagePath);
  if (!file.existsSync()) return;
  showAppDialog<void>(
    context: context,
    barrierColor: Theme.of(context).colorScheme.scrim,
    barrierDismissible: true,
    centerInFullViewport: true,
    fadeScale: false,
    builder: (_) => Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.zero,
      child: InteractiveViewer(
        child: Image.file(file, fit: BoxFit.contain),
      ),
    ),
  );
}

Widget buildExpenseImageView(
  BuildContext context,
  String? imagePath, {
  double? maxHeight,
  double? width,
  BoxFit fit = BoxFit.cover,
  EdgeInsetsGeometry padding = const EdgeInsets.only(top: 8),
  BorderRadius? borderRadius,
}) {
  if (imagePath == null || imagePath.isEmpty) return const SizedBox.shrink();
  final radius = borderRadius ?? BorderRadius.circular(12);
  final file = isImageUrl(imagePath) ? null : File(imagePath);
  final image = file != null && file.existsSync()
      ? Image.file(file, fit: fit, width: width, height: maxHeight)
      : _unavailablePlaceholder(context);
  return Padding(
    padding: padding,
    child: ClipRRect(
      borderRadius: radius,
      child: SizedBox(width: width, height: maxHeight ?? 200, child: image),
    ),
  );
}

void _showUnavailable(BuildContext context) {
  showAppDialog<void>(
    context: context,
    centerInFullViewport: true,
    builder: (context) => _unavailablePlaceholder(context),
  );
}

Widget _unavailablePlaceholder(BuildContext context) {
  final colors = Theme.of(context).colorScheme;
  return Material(
    color: colors.surfaceContainerHighest,
    borderRadius: BorderRadius.circular(12),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.broken_image_outlined, color: colors.onSurfaceVariant),
          const SizedBox(width: 12),
          Text('image_unavailable'.tr()),
        ],
      ),
    ),
  );
}
