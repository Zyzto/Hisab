import 'package:flutter/material.dart';

/// Full-screen view not available on web (no file access). Shows a message.
void showReceiptImageFullScreen(BuildContext context, String imagePath) {
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Receipt'),
      content: const Text(
        'Receipt image attached. Full preview is available in the mobile app.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('OK'),
        ),
      ],
    ),
  );
}

/// Placeholder when dart:io is not available (e.g. web). Shows a chip that receipt is attached.
Widget buildReceiptImageView(
  String? imagePath, {
  double? maxHeight,
  BoxFit fit = BoxFit.cover,
}) {
  if (imagePath == null || imagePath.isEmpty) return const SizedBox.shrink();
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
                'Receipt image attached',
                style: TextStyle(color: Colors.grey.shade700),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
