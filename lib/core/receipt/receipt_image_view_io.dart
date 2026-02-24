import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import 'receipt_utils.dart';

/// Shows the receipt image full-screen (dialog). Tap or back to close.
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

/// Shows the receipt image from a URL or local file path. Use when dart:io is available.
Widget buildReceiptImageView(
  String? imagePath, {
  double? maxHeight,
  BoxFit fit = BoxFit.cover,
}) {
  if (imagePath == null || imagePath.isEmpty) return const SizedBox.shrink();
  final effectiveMaxHeight = maxHeight ?? 200;

  if (isReceiptImageUrl(imagePath)) {
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
            errorBuilder: (context, _, _) => _buildUnavailablePlaceholder(),
          ),
        ),
      ),
    );
  }

  final file = File(imagePath);
  if (!file.existsSync()) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: _buildUnavailablePlaceholder(),
    );
  }
  return Padding(
    padding: const EdgeInsets.only(top: 8),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        height: effectiveMaxHeight,
        child: Image.file(
          file,
          fit: fit,
          errorBuilder: (context, error, stackTrace) => _buildUnavailablePlaceholder(),
        ),
      ),
    ),
  );
}

Widget _buildUnavailablePlaceholder() {
  return Material(
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
  );
}
