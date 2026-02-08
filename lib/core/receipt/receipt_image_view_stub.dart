import 'package:flutter/material.dart';

/// Placeholder when dart:io is not available (e.g. web). Shows a chip that receipt is attached.
Widget buildReceiptImageView(String? imagePath, {double? maxHeight, BoxFit fit = BoxFit.cover}) {
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
