import 'package:flutter/material.dart';

import '../layout/responsive_sheet.dart';
import '../platform/network_image_decode.dart';

/// Shows a full-screen dialog with [Image.network] for an image URL.
/// Shared by [receipt_image_view_io.dart] and [receipt_image_view_stub.dart].
///
/// Tap the dimmed area or the close button to dismiss; pinch to zoom.
void showImageDialogForUrl(BuildContext context, String url) {
  final size = MediaQuery.sizeOf(context);
  final decode = NetworkImageDecode.cacheSize(
    context,
    logicalWidth: size.width,
    logicalHeight: size.height,
  );
  showAppDialog<void>(
    context: context,
    barrierColor: Theme.of(context).colorScheme.scrim,
    barrierDismissible: true,
    centerInFullViewport: true,
    fadeScale: false,
    builder: (ctx) => _FullscreenImageDialog(
      image: Image.network(
        url,
        fit: BoxFit.contain,
        cacheWidth: decode.width,
        cacheHeight: decode.height,
        loadingBuilder: (_, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return const SizedBox(
            width: 72,
            height: 72,
            child: Center(child: CircularProgressIndicator()),
          );
        },
        errorBuilder: (_, _, _) => const SizedBox.shrink(),
      ),
    ),
  );
}

/// Full-screen transparent dialog: tap outside / close to dismiss, pinch to zoom.
class FullscreenImageDialog extends StatelessWidget {
  final Widget image;

  const FullscreenImageDialog({super.key, required this.image});

  @override
  Widget build(BuildContext context) => _FullscreenImageDialog(image: image);
}

class _FullscreenImageDialog extends StatelessWidget {
  final Widget image;

  const _FullscreenImageDialog({required this.image});

  void _dismiss(BuildContext context) {
    final nav = Navigator.of(context, rootNavigator: true);
    if (nav.canPop()) nav.pop();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.zero,
      // Bypass Material's default maxWidth: 560 so the viewer fills the screen.
      constraints: const BoxConstraints.expand(),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Full-screen dismiss target behind the viewer.
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => _dismiss(context),
            child: const ColoredBox(color: Colors.transparent),
          ),
          // Default constrained:true sizes the child to the viewport so the
          // image is centered; extreme scale range for free pinch zoom.
          InteractiveViewer(
            minScale: 0.05,
            maxScale: 100,
            boundaryMargin: const EdgeInsets.all(double.infinity),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _dismiss(context),
              child: Center(child: image),
            ),
          ),
          SafeArea(
            child: Align(
              alignment: AlignmentDirectional.topEnd,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: IconButton.filledTonal(
                  onPressed: () => _dismiss(context),
                  icon: const Icon(Icons.close),
                  tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
