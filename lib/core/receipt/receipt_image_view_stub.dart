import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import 'receipt_utils.dart';

/// Full-screen view: URLs open in dialog with Image.network; local paths show message (web has no file access).
void showReceiptImageFullScreen(BuildContext context, String imagePath) {
  if (isReceiptImageUrl(imagePath)) {
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
              child: Image.network(
                imagePath,
                fit: BoxFit.contain,
                loadingBuilder: (_, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return const Center(child: CircularProgressIndicator());
                },
                errorBuilder: (_, _, _) => const SizedBox.shrink(),
              ),
            ),
          ),
        ),
      ),
    );
    return;
  }
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text('receipt'.tr()),
      content: Text('receipt_preview_web'.tr()),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: Text('ok'.tr()),
        ),
      ],
    ),
  );
}

/// When dart:io is not available (e.g. web): show Image.network for URLs, else a chip that receipt is attached.
Widget buildReceiptImageView(
  String? imagePath, {
  double? maxHeight,
  BoxFit fit = BoxFit.cover,
}) {
  if (imagePath == null || imagePath.isEmpty) return const SizedBox.shrink();
  if (isReceiptImageUrl(imagePath)) {
    final effectiveMaxHeight = maxHeight ?? 200;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          height: effectiveMaxHeight,
          child: Image.network(
            imagePath,
            fit: fit,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return Center(
                child: CircularProgressIndicator(
                  value: loadingProgress.expectedTotalBytes != null
                      ? loadingProgress.cumulativeBytesLoaded /
                          loadingProgress.expectedTotalBytes!
                      : null,
                ),
              );
            },
            errorBuilder: (_, _, _) => Material(
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
          ),
        ),
      ),
    );
  }
  return Padding(
    padding: const EdgeInsets.only(top: 8),
    child: Material(
      color: Colors.grey.shade200,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.receipt_long, size: 40, color: Colors.grey.shade600),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'receipt_attached'.tr(),
                style: TextStyle(color: Colors.grey.shade700),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
