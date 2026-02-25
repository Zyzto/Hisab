import 'dart:ui' as ui;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/widgets/toast.dart';

/// Captures the [RepaintBoundary]'s content to PNG bytes.
/// Returns null if capture or encode fails.
Future<Uint8List?> captureRepaintBoundaryToPngBytes(
  RenderRepaintBoundary boundary, {
  double pixelRatio = 2.0,
}) async {
  try {
    final image = await boundary.toImage(pixelRatio: pixelRatio);
    try {
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      return byteData?.buffer.asUint8List();
    } finally {
      image.dispose();
    }
  } catch (_) {
    return null;
  }
}

/// Shares the invite [url] and optionally the QR code image.
/// Provide [imageBytes] (e.g. from [captureRepaintBoundaryToPngBytes] before
/// closing a sheet) or [boundary] to include the QR image; otherwise shares text only.
/// [shareMessage] is optional prefix text (e.g. localized "Join our group").
Future<void> shareInviteLink({
  required String url,
  String? shareMessage,
  RenderRepaintBoundary? boundary,
  Uint8List? imageBytes,
}) async {
  final text = shareMessage != null && shareMessage.isNotEmpty
      ? '$shareMessage $url'
      : url;

  Uint8List? pngBytes = imageBytes;
  if (pngBytes == null && boundary != null) {
    pngBytes = await captureRepaintBoundaryToPngBytes(boundary);
  }
  if (pngBytes != null && pngBytes.isNotEmpty) {
    try {
      final xFile = XFile.fromData(
        pngBytes,
        mimeType: 'image/png',
        name: 'hisab_invite_qr.png',
      );
      await Share.shareXFiles(
        [xFile],
        text: text,
      );
      return;
    } catch (_) {
      // Fall through to text-only share
    }
  }

  await Share.share(text);
}

/// Shares the invite [url] (and optionally QR from [boundary]); on failure
/// copies [url] to clipboard and shows toasts. Call from invite management
/// and create-invite sheet.
Future<void> shareInviteLinkWithFallback(
  BuildContext context, {
  required String url,
  String? shareMessage,
  RenderRepaintBoundary? boundary,
}) async {
  try {
    await shareInviteLink(
      url: url,
      shareMessage: shareMessage ?? 'share_invite_message'.tr(),
      boundary: boundary,
    );
    if (!context.mounted) return;
    context.showSuccess('invite_shared'.tr());
  } catch (_) {
    await Clipboard.setData(ClipboardData(text: url));
    if (!context.mounted) return;
    context.showSuccess('invite_link_copied'.tr());
  }
}
