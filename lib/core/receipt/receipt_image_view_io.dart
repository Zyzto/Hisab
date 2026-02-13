import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

/// Shows the receipt image full-screen (dialog). Tap or back to close.
void showReceiptImageFullScreen(BuildContext context, String imagePath) {
  final file = File(imagePath);
  if (!file.existsSync()) return;
  showDialog(
    context: context,
    barrierColor: Colors.black87,
    barrierDismissible: true,
    builder: (ctx) => Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.zero,
      child: InteractiveViewer(
        minScale: 0.5,
        maxScale: 4,
        child: GestureDetector(
          onTap: () => Navigator.of(ctx).pop(),
          child: Center(
            child: Image.file(
              file,
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) => const SizedBox.shrink(),
            ),
          ),
        ),
      ),
    ),
  );
}

/// Shows the receipt image from a local file path. Use when dart:io is available.
Widget buildReceiptImageView(
  String? imagePath, {
  double? maxHeight,
  BoxFit fit = BoxFit.cover,
}) {
  if (imagePath == null || imagePath.isEmpty) return const SizedBox.shrink();
  final file = File(imagePath);
  if (!file.existsSync()) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Material(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Icon(Icons.broken_image_outlined, size: 40, color: Colors.grey),
              const SizedBox(width: 12),
              Text('receipt_image_unavailable'.tr()),
            ],
          ),
        ),
      ),
    );
  }
  final effectiveMaxHeight = maxHeight ?? 200;
  return Padding(
    padding: const EdgeInsets.only(top: 8),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        height: effectiveMaxHeight,
        child: Image.file(
          file,
          fit: fit,
          errorBuilder: (context, error, stackTrace) {
            return Material(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Icon(
                      Icons.broken_image_outlined,
                      size: 40,
                      color: Colors.grey,
                    ),
                    const SizedBox(width: 12),
                    Text('could_not_load_image'.tr()),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    ),
  );
}
