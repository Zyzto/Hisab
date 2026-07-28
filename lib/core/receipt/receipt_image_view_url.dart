import 'package:flutter/material.dart';

import '../layout/responsive_sheet.dart';

/// Shows a full-screen dialog with [Image.network] for an image URL.
/// Shared by [receipt_image_view_io.dart] and [receipt_image_view_stub.dart].
///
/// Tap the dimmed area outside the image to close; the image itself stays
/// interactive for pinch-zoom.
void showImageDialogForUrl(BuildContext context, String url) {
  showAppDialog<void>(
    context: context,
    barrierColor: Theme.of(context).colorScheme.scrim,
    barrierDismissible: true,
    centerInFullViewport: true,
    builder: (ctx) => _FullscreenImageDialog(
      image: Image.network(
        url,
        fit: BoxFit.contain,
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

/// Full-screen transparent dialog: tap outside the image to dismiss.
class FullscreenImageDialog extends StatelessWidget {
  final Widget image;

  const FullscreenImageDialog({super.key, required this.image});

  @override
  Widget build(BuildContext context) => _FullscreenImageDialog(image: image);
}

class _FullscreenImageDialog extends StatelessWidget {
  final Widget image;

  const _FullscreenImageDialog({required this.image});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.zero,
      child: SizedBox.expand(
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Backdrop: tap anywhere not on the image to close.
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                final nav = Navigator.of(context);
                if (nav.canPop()) nav.pop();
              },
              child: const ColoredBox(color: Colors.transparent),
            ),
            // Image keeps its intrinsic size so letterboxed areas hit the
            // backdrop. [constrained: false] sizes the viewer to the child.
            Center(
              child: GestureDetector(
                // Stop backdrop taps when pressing on the image itself.
                onTap: () {},
                child: InteractiveViewer(
                  constrained: false,
                  minScale: 0.5,
                  maxScale: 4,
                  child: image,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

@Deprecated('Use showImageDialogForUrl instead.')
void showReceiptImageDialogForUrl(BuildContext context, String url) =>
    showImageDialogForUrl(context, url);
