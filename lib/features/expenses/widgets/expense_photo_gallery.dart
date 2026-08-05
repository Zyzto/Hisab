import 'dart:typed_data';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../../core/layout/responsive_sheet.dart';
import '../../../core/platform/network_image_decode.dart';
import '../../../core/receipt/receipt_image_cache.dart';
import '../../../core/receipt/receipt_image_compress.dart';

/// One expense photo: pending bytes and/or stored URL.
typedef ExpensePhotoItem = ({Uint8List? bytes, String? url});

/// Full-screen gallery: swipe photos, filmstrip, rotate / delete tools.
///
/// Returns the (possibly edited) list when closed. Empty list if all removed.
Future<List<ExpensePhotoItem>?> showExpensePhotoGallery(
  BuildContext context, {
  required List<ExpensePhotoItem> images,
  required int initialIndex,
  bool scanEnabled = false,
  Future<void> Function(Uint8List bytes)? onScan,
}) {
  if (images.isEmpty) return Future.value(null);
  final index = initialIndex.clamp(0, images.length - 1);
  return showAppDialog<List<ExpensePhotoItem>>(
    context: context,
    barrierColor: Colors.black,
    barrierDismissible: false,
    centerInFullViewport: true,
    fadeScale: false,
    builder: (ctx) => _ExpensePhotoGalleryDialog(
      images: List<ExpensePhotoItem>.of(images),
      initialIndex: index,
      scanEnabled: scanEnabled,
      onScan: onScan,
    ),
  );
}

class _ExpensePhotoGalleryDialog extends StatefulWidget {
  const _ExpensePhotoGalleryDialog({
    required this.images,
    required this.initialIndex,
    required this.scanEnabled,
    this.onScan,
  });

  final List<ExpensePhotoItem> images;
  final int initialIndex;
  final bool scanEnabled;
  final Future<void> Function(Uint8List bytes)? onScan;

  @override
  State<_ExpensePhotoGalleryDialog> createState() =>
      _ExpensePhotoGalleryDialogState();
}

class _ExpensePhotoGalleryDialogState extends State<_ExpensePhotoGalleryDialog> {
  late List<ExpensePhotoItem> _images;
  late PageController _pageController;
  late int _index;
  bool _busy = false;
  final Map<int, GlobalKey> _thumbKeys = {};

  @override
  void initState() {
    super.initState();
    _images = List<ExpensePhotoItem>.of(widget.images);
    _index = widget.initialIndex.clamp(0, _images.length - 1);
    _pageController = PageController(initialPage: _index);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _close() {
    Navigator.of(context, rootNavigator: true).pop(_images);
  }

  Future<Uint8List?> _resolveBytes(ExpensePhotoItem item) async {
    if (item.bytes != null && item.bytes!.isNotEmpty) return item.bytes;
    final url = item.url;
    if (url == null || url.isEmpty) return null;

    final cached = await loadReceiptImageBytesForUrl(url);
    if (cached != null && cached.isNotEmpty) return cached;

    try {
      final uri = Uri.tryParse(url);
      if (uri == null) return null;
      final response = await http.get(uri).timeout(const Duration(seconds: 20));
      if (response.statusCode != 200 || response.bodyBytes.isEmpty) return null;
      return response.bodyBytes;
    } catch (_) {
      return null;
    }
  }

  Future<void> _rotate(int degrees) async {
    if (_busy || _images.isEmpty) return;
    final i = _index;
    setState(() => _busy = true);
    try {
      final source = await _resolveBytes(_images[i]);
      if (source == null || !mounted) return;
      final rotated = await rotateReceiptImage(source, degrees);
      if (rotated == null || !mounted) return;
      // Keep prior URL as fallback so offline / failed upload cannot drop the
      // photo; save prefers [bytes] when uploading.
      setState(() {
        _images[i] = (bytes: rotated, url: _images[i].url);
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _deleteCurrent() {
    if (_busy || _images.isEmpty) return;
    final removing = _index;
    setState(() {
      _images.removeAt(removing);
      _thumbKeys.clear();
      if (_images.isEmpty) {
        _index = 0;
      } else if (_index >= _images.length) {
        _index = _images.length - 1;
      }
    });
    if (_images.isEmpty) {
      _close();
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_pageController.hasClients) return;
      _pageController.jumpToPage(_index);
      _scrollThumbIntoView(_index);
    });
  }

  Future<void> _scanCurrent() async {
    final onScan = widget.onScan;
    if (!widget.scanEnabled || onScan == null || _busy || _images.isEmpty) {
      return;
    }
    setState(() => _busy = true);
    try {
      final bytes = await _resolveBytes(_images[_index]);
      if (bytes == null || !mounted) return;
      await onScan(bytes);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _goTo(int i) {
    if (i < 0 || i >= _images.length || i == _index) return;
    setState(() => _index = i);
    _pageController.animateToPage(
      i,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
    );
    _scrollThumbIntoView(i);
  }

  void _scrollThumbIntoView(int i) {
    final key = _thumbKeys[i];
    final ctx = key?.currentContext;
    if (ctx == null) return;
    Scrollable.ensureVisible(
      ctx,
      alignment: 0.5,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final count = _images.length;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop || _busy) return;
        _close();
      },
      child: Dialog(
        backgroundColor: Colors.black,
        insetPadding: EdgeInsets.zero,
        constraints: const BoxConstraints.expand(),
        child: Material(
          color: Colors.black,
          child: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: _busy ? null : _close,
                        tooltip: MaterialLocalizations.of(
                          context,
                        ).closeButtonTooltip,
                        icon: const Icon(Icons.close, color: Colors.white),
                      ),
                      Expanded(
                        child: Text(
                          count == 0 ? '' : '${_index + 1} / $count',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 48),
                    ],
                  ),
                ),
                Expanded(
                  child: count == 0
                      ? const SizedBox.shrink()
                      : PageView.builder(
                          controller: _pageController,
                          itemCount: count,
                          onPageChanged: (i) {
                            setState(() => _index = i);
                            _scrollThumbIntoView(i);
                          },
                          itemBuilder: (context, i) {
                            // No InteractiveViewer here — it steals PageView swipes.
                            return KeyedSubtree(
                              key: ValueKey(_photoIdentity(_images[i], i)),
                              child: _PhotoPage(item: _images[i]),
                            );
                          },
                        ),
                ),
                if (_busy)
                  const LinearProgressIndicator(minHeight: 2)
                else
                  const SizedBox(height: 2),
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 8, 4, 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: _ToolButton(
                          icon: Icons.rotate_90_degrees_ccw,
                          label: 'photo_rotate_left'.tr(),
                          onPressed: _busy ? null : () => _rotate(270),
                        ),
                      ),
                      Expanded(
                        child: _ToolButton(
                          icon: Icons.rotate_90_degrees_cw,
                          label: 'photo_rotate_right'.tr(),
                          onPressed: _busy ? null : () => _rotate(90),
                        ),
                      ),
                      if (widget.scanEnabled && widget.onScan != null)
                        Expanded(
                          child: _ToolButton(
                            icon: Icons.document_scanner_outlined,
                            label: 'receipt_camera_scan_this'.tr(),
                            onPressed: _busy ? null : _scanCurrent,
                          ),
                        ),
                      Expanded(
                        child: _ToolButton(
                          icon: Icons.delete_outline,
                          label: 'receipt_camera_remove'.tr(),
                          onPressed: _busy ? null : _deleteCurrent,
                          danger: true,
                        ),
                      ),
                    ],
                  ),
                ),
                if (count > 1)
                  SizedBox(
                    height: 72,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                      itemCount: count,
                      separatorBuilder: (_, _) => const SizedBox(width: 8),
                      itemBuilder: (context, i) {
                        final selected = i == _index;
                        _thumbKeys.putIfAbsent(i, GlobalKey.new);
                        return KeyedSubtree(
                          key: _thumbKeys[i],
                          child: GestureDetector(
                            onTap: () => _goTo(i),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 160),
                              width: 56,
                              height: 56,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: selected
                                      ? scheme.primary
                                      : Colors.white24,
                                  width: selected ? 2.5 : 1,
                                ),
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: _PhotoThumb(item: _images[i]),
                            ),
                          ),
                        );
                      },
                    ),
                  )
                else
                  const SizedBox(height: 12),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String _photoIdentity(ExpensePhotoItem item, int index) {
  if (item.bytes != null) {
    return 'b:${item.bytes.hashCode}:$index';
  }
  return 'u:${item.url ?? ''}:$index';
}

class _ToolButton extends StatelessWidget {
  const _ToolButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.danger = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final color = !enabled
        ? Colors.white38
        : danger
        ? const Color(0xFFFF8A80)
        : Colors.white;
    return Tooltip(
      message: label,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 26),
              const SizedBox(height: 4),
              Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PhotoPage extends StatelessWidget {
  const _PhotoPage({required this.item});

  final ExpensePhotoItem item;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final decode = NetworkImageDecode.cacheSizePreserveAspect(
      context,
      logicalMaxEdge: size.longestSide,
    );
    // Bound to the page so BoxFit.contain applies (unbounded Center lets the
    // image take its intrinsic size and overflow / look wrong).
    if (item.bytes != null && item.bytes!.isNotEmpty) {
      return SizedBox.expand(
        child: Image.memory(
          item.bytes!,
          fit: BoxFit.contain,
          cacheWidth: decode.width,
          gaplessPlayback: true,
          errorBuilder: (_, _, _) => const _BrokenPhoto(),
        ),
      );
    }
    final url = item.url;
    if (url != null && url.isNotEmpty) {
      return SizedBox.expand(
        child: Image.network(
          url,
          fit: BoxFit.contain,
          cacheWidth: decode.width,
          gaplessPlayback: true,
          loadingBuilder: (_, child, progress) {
            if (progress == null) return child;
            return const Center(child: CircularProgressIndicator());
          },
          errorBuilder: (_, _, _) => const _BrokenPhoto(),
        ),
      );
    }
    return const SizedBox.expand(child: _BrokenPhoto());
  }
}

class _PhotoThumb extends StatelessWidget {
  const _PhotoThumb({required this.item});

  final ExpensePhotoItem item;

  @override
  Widget build(BuildContext context) {
    final decode = NetworkImageDecode.cacheSizePreserveAspect(
      context,
      logicalMaxEdge: 56,
    );
    if (item.bytes != null && item.bytes!.isNotEmpty) {
      return Image.memory(
        item.bytes!,
        fit: BoxFit.cover,
        width: 56,
        height: 56,
        cacheWidth: decode.width,
        gaplessPlayback: true,
        errorBuilder: (_, _, _) => const ColoredBox(
          color: Colors.white12,
          child: Icon(Icons.broken_image_outlined, color: Colors.white54),
        ),
      );
    }
    final url = item.url;
    if (url != null && url.isNotEmpty) {
      return Image.network(
        url,
        fit: BoxFit.cover,
        width: 56,
        height: 56,
        cacheWidth: decode.width,
        gaplessPlayback: true,
        errorBuilder: (_, _, _) => const ColoredBox(
          color: Colors.white12,
          child: Icon(Icons.broken_image_outlined, color: Colors.white54),
        ),
      );
    }
    return const ColoredBox(color: Colors.white12);
  }
}

class _BrokenPhoto extends StatelessWidget {
  const _BrokenPhoto();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.broken_image_outlined, color: Colors.white54, size: 48),
        const SizedBox(height: 8),
        Text(
          'image_unavailable'.tr(),
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Colors.white70,
          ),
        ),
      ],
    );
  }
}
