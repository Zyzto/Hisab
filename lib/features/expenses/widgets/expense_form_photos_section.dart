import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../core/motion/app_motion.dart';
import '../../../core/platform/network_image_decode.dart';
import '../constants/expense_form_constants.dart';
import 'expense_photo_gallery.dart';

/// Photos strip on the expense form: thumbnails, add, and scan actions.
class ExpenseFormPhotosSection extends StatelessWidget {
  const ExpenseFormPhotosSection({
    super.key,
    required this.images,
    required this.scanningImageIndex,
    required this.scanEnabled,
    required this.onAddPhoto,
    required this.onScanReceipt,
    required this.onStopScan,
    required this.onOpenGallery,
    required this.onRemoveAt,
    this.maxImages = kMaxExpenseImages,
  });

  final List<ExpensePhotoItem> images;

  /// Index of the image being scanned; `-1` = busy without thumb; `null` = idle.
  final int? scanningImageIndex;
  final bool scanEnabled;
  final int maxImages;
  final VoidCallback onAddPhoto;
  final VoidCallback onScanReceipt;
  final VoidCallback onStopScan;
  final ValueChanged<int> onOpenGallery;
  final ValueChanged<int> onRemoveAt;

  bool get _scanningReceipt => scanningImageIndex != null;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final count = images.length;
    final canScan = scanEnabled && !_scanningReceipt && count < maxImages;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 12),
        Row(
          children: [
            Text(
              'photos_section'.tr(),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'photos_count'.tr(args: ['$count', '$maxImages']),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.primary,
              ),
            ),
            if (_scanningReceipt) ...[
              const SizedBox(width: 12),
              SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  'receipt_scanning'.tr(),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              TextButton(
                onPressed: onStopScan,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                ),
                child: Text('receipt_scan_stop'.tr()),
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ...images.asMap().entries.map((entry) {
              final i = entry.key;
              final item = entry.value;
              return _PhotoThumbnail(
                item: item,
                index: i,
                scanning: scanningImageIndex == i,
                onOpen: () => onOpenGallery(i),
                onRemove: () => onRemoveAt(i),
              );
            }),
            if (count < maxImages)
              _PhotoActionChip(
                icon: Icons.add_photo_alternate_outlined,
                onTap: _scanningReceipt ? null : onAddPhoto,
              ),
            if (scanEnabled)
              _PhotoActionChip(
                icon: Icons.document_scanner_outlined,
                label: 'scan_receipt'.tr(),
                emphasized: canScan,
                onTap: canScan ? onScanReceipt : null,
              ),
          ],
        ),
        const SizedBox(height: 20),
      ],
    );
  }
}

class _PhotoActionChip extends StatelessWidget {
  const _PhotoActionChip({
    required this.icon,
    this.label,
    this.emphasized = false,
    this.onTap,
  });

  final IconData icon;
  final String? label;
  final bool emphasized;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final enabled = onTap != null;
    final bg = emphasized && enabled
        ? theme.colorScheme.primaryContainer
        : theme.colorScheme.surfaceContainerHighest;
    final fg = !enabled
        ? theme.colorScheme.onSurface.withValues(alpha: 0.38)
        : emphasized
        ? theme.colorScheme.onPrimaryContainer
        : theme.colorScheme.onSurfaceVariant;
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          width: 80,
          height: 80,
          child: label == null
              ? Icon(icon, size: 32, color: fg)
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(icon, size: 28, color: fg),
                    const SizedBox(height: 4),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Text(
                        label!,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: fg,
                          height: 1.1,
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _PhotoThumbnail extends StatelessWidget {
  const _PhotoThumbnail({
    required this.item,
    required this.index,
    required this.scanning,
    required this.onOpen,
    required this.onRemove,
  });

  final ExpensePhotoItem item;
  final int index;
  final bool scanning;
  final VoidCallback onOpen;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget image;
    final thumbDecode = NetworkImageDecode.cacheSizePreserveAspect(
      context,
      logicalMaxEdge: 80,
    );
    if (item.bytes != null) {
      image = Image.memory(
        item.bytes!,
        fit: BoxFit.cover,
        width: 80,
        height: 80,
        cacheWidth: thumbDecode.width,
        gaplessPlayback: true,
      );
    } else if (item.url != null && item.url!.isNotEmpty) {
      image = Image.network(
        item.url!,
        fit: BoxFit.cover,
        width: 80,
        height: 80,
        cacheWidth: thumbDecode.width,
        gaplessPlayback: true,
        loadingBuilder: (_, child, progress) {
          if (progress == null) return child;
          return const SizedBox(
            width: 80,
            height: 80,
            child: Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        },
        errorBuilder: (_, Object o, StackTrace? s) => const SizedBox(
          width: 80,
          height: 80,
          child: Icon(Icons.broken_image_outlined),
        ),
      );
    } else {
      image = const SizedBox(width: 80, height: 80);
    }

    final motion = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : AppMotion.shellTab;

    final thumb = Stack(
      clipBehavior: Clip.none,
      children: [
        Material(
          borderRadius: BorderRadius.circular(12),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onOpen,
            child: SizedBox(width: 80, height: 80, child: image),
          ),
        ),
        Positioned(
          top: -4,
          right: -4,
          child: IconButton(
            icon: Icon(
              Icons.close,
              size: 18,
              color: theme.colorScheme.onSurface,
            ),
            style: IconButton.styleFrom(
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
              padding: const EdgeInsets.all(4),
              minimumSize: const Size(28, 28),
            ),
            onPressed: onRemove,
          ),
        ),
        if (scanning)
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.black38,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: theme.colorScheme.onPrimary,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: motion,
      curve: AppMotion.enterCurve,
      builder: (context, t, child) {
        return Opacity(
          opacity: t,
          child: Transform.scale(scale: 0.92 + (0.08 * t), child: child),
        );
      },
      child: thumb,
    );
  }
}
