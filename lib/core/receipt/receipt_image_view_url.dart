import 'package:flutter/material.dart';

import '../layout/responsive_sheet.dart';

/// Shows a full-screen dialog with [Image.network] for a receipt image URL.
/// Shared by [receipt_image_view_io.dart] and [receipt_image_view_stub.dart].
void showReceiptImageDialogForUrl(BuildContext context, String url) {
  showAppDialog<void>(
    context: context,
    barrierColor: Theme.of(context).colorScheme.scrim,
    barrierDismissible: true,
    centerInFullViewport: true,
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
              url,
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
}
