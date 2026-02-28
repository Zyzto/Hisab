import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../layout/layout_breakpoints.dart';
import '../layout/responsive_sheet.dart';
import '../widgets/sheet_helpers.dart';
import 'receipt_image_view_url.dart';
import 'receipt_utils.dart';

/// Full-screen view: URLs open in dialog with Image.network; local paths show message (web has no file access).
void showReceiptImageFullScreen(BuildContext context, String imagePath) {
  if (isReceiptImageUrl(imagePath)) {
    showReceiptImageDialogForUrl(context, imagePath);
    return;
  }
  showResponsiveSheet<void>(
    context: context,
    title: 'receipt'.tr(),
    maxHeight: MediaQuery.of(context).size.height * 0.35,
    isScrollControlled: true,
    centerInFullViewport: true,
    child: Builder(
      builder: (ctx) => buildSheetShell(
        ctx,
        title: 'receipt'.tr(),
        showTitleInBody: !LayoutBreakpoints.isTabletOrWider(context),
        body: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text('receipt_preview_web'.tr()),
        ),
        actions: LayoutBreakpoints.isTabletOrWider(context)
            ? []
            : [
                FilledButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: Text('ok'.tr()),
                ),
              ],
      ),
    ),
  );
}

/// When dart:io is not available (e.g. web): show Image.network for URLs, else a chip that receipt is attached.
Widget buildReceiptImageView(
  BuildContext context,
  String? imagePath, {
  double? maxHeight,
  BoxFit fit = BoxFit.cover,
}) {
  if (imagePath == null || imagePath.isEmpty) return const SizedBox.shrink();
  final theme = Theme.of(context);
  final colorScheme = theme.colorScheme;
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
              color: colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(
                      Icons.broken_image_outlined,
                      size: 40,
                      color: colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'receipt_image_unavailable'.tr(),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
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
      color: colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(
              Icons.receipt_long,
              size: 40,
              color: colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'receipt_attached'.tr(),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
