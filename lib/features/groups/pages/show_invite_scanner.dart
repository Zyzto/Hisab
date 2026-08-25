import 'package:flutter/material.dart';
import 'package:safaeh/safaeh.dart';

import 'invite_scanner_view.dart';

/// Opens the invite QR scanner as a bottom sheet that can expand to full.
///
/// Rolls up from the bottom edge. [origin] kept for call-site compatibility.
Future<void> showInviteScanner(BuildContext context, {Rect? origin}) {
  return showSafaehCameraSheet<void>(
    context: context,
    builder: (context, sheet) => InviteScannerView(
      expanded: sheet.expanded,
      onToggleExpanded: sheet.toggleExpanded,
      onClose: sheet.dismiss,
    ),
  );
}
