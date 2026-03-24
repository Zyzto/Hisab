import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../layout/responsive_sheet.dart';
import 'receipt_image_cache.dart';
import 'receipt_utils.dart';

/// Shows an attached image full-screen (dialog). Tap or back to close.
void showExpenseImageFullScreen(BuildContext context, String imagePath) {
  if (isImageUrl(imagePath)) {
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
              child: _ReceiptCachedOrNetworkImage(
                imageUrl: imagePath,
                fit: BoxFit.contain,
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

/// Shows an attached image from a URL or local file path. Use when dart:io is available.
Widget buildExpenseImageView(
  BuildContext context,
  String? imagePath, {
  double? maxHeight,
  BoxFit fit = BoxFit.cover,
}) {
  if (imagePath == null || imagePath.isEmpty) return const SizedBox.shrink();
  final effectiveMaxHeight = maxHeight ?? 200;
  final unavailablePlaceholder = _buildUnavailablePlaceholder(context);

  if (isImageUrl(imagePath)) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          height: effectiveMaxHeight,
          child: _ReceiptCachedOrNetworkImage(
            imageUrl: imagePath,
            fit: fit,
            unavailablePlaceholder: unavailablePlaceholder,
          ),
        ),
      ),
    );
  }

  final file = File(imagePath);
  if (!file.existsSync()) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: _buildUnavailablePlaceholder(context),
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
          errorBuilder: (_, _, _) => unavailablePlaceholder,
        ),
      ),
    ),
  );
}

class _ReceiptCachedOrNetworkImage extends StatefulWidget {
  final String imageUrl;
  final BoxFit fit;
  final Widget? unavailablePlaceholder;

  const _ReceiptCachedOrNetworkImage({
    required this.imageUrl,
    required this.fit,
    this.unavailablePlaceholder,
  });

  @override
  State<_ReceiptCachedOrNetworkImage> createState() =>
      _ReceiptCachedOrNetworkImageState();
}

class _ReceiptCachedOrNetworkImageState extends State<_ReceiptCachedOrNetworkImage> {
  late Future<String?> _cachedPathFuture;

  @override
  void initState() {
    super.initState();
    _cachedPathFuture = getOrFetchCachedReceiptPathForUrl(widget.imageUrl);
  }

  @override
  void didUpdateWidget(covariant _ReceiptCachedOrNetworkImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl) {
      _cachedPathFuture = getOrFetchCachedReceiptPathForUrl(widget.imageUrl);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String?>(
      future: _cachedPathFuture,
      builder: (context, snapshot) {
        final cachedPath = snapshot.data;
        if (cachedPath != null && cachedPath.isNotEmpty) {
          final file = File(cachedPath);
          if (file.existsSync()) {
            return Image.file(
              file,
              fit: widget.fit,
              errorBuilder: (_, _, _) => _fallbackNetworkImage(),
            );
          }
        }
        return _fallbackNetworkImage();
      },
    );
  }

  Widget _fallbackNetworkImage() {
    return Image.network(
      widget.imageUrl,
      fit: widget.fit,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return _buildImageLoadingSkeleton(context);
      },
      errorBuilder: (_, _, _) =>
          widget.unavailablePlaceholder ?? const SizedBox.shrink(),
    );
  }
}

Widget _buildUnavailablePlaceholder(BuildContext context) {
  final theme = Theme.of(context);
  final colorScheme = theme.colorScheme;
  return Material(
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
          Expanded(
            child: Text(
              'image_unavailable'.tr(),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

@Deprecated('Use showExpenseImageFullScreen instead.')
void showReceiptImageFullScreen(BuildContext context, String imagePath) =>
    showExpenseImageFullScreen(context, imagePath);

@Deprecated('Use buildExpenseImageView instead.')
Widget buildReceiptImageView(
  BuildContext context,
  String? imagePath, {
  double? maxHeight,
  BoxFit fit = BoxFit.cover,
}) => buildExpenseImageView(
  context,
  imagePath,
  maxHeight: maxHeight,
  fit: fit,
);

Widget _buildImageLoadingSkeleton(BuildContext context) {
  final colorScheme = Theme.of(context).colorScheme;
  return DecoratedBox(
    decoration: BoxDecoration(
      color: colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Center(
      child: Icon(
        Icons.image_outlined,
        size: 30,
        color: colorScheme.onSurfaceVariant,
      ),
    ),
  );
}
