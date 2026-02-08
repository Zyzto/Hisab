import 'dart:io';

import 'package:flutter/material.dart';

/// Shows the receipt image from a local file path. Use when dart:io is available.
Widget buildReceiptImageView(String? imagePath, {double? maxHeight, BoxFit fit = BoxFit.cover}) {
  if (imagePath == null || imagePath.isEmpty) return const SizedBox.shrink();
  final file = File(imagePath);
  if (!file.existsSync()) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Material(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(12),
        child: const Padding(
          padding: EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(Icons.broken_image_outlined, size: 40, color: Colors.grey),
              SizedBox(width: 12),
              Text('Receipt image unavailable'),
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
              child: const Padding(
                padding: EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(Icons.broken_image_outlined, size: 40, color: Colors.grey),
                    SizedBox(width: 12),
                    Text('Could not load image'),
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
