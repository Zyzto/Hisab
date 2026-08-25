import 'package:flutter/material.dart';
import 'package:safaeh/safaeh.dart';

import '../../../core/navigation/nav_back.dart';
import '../../../core/navigation/route_paths.dart';
import 'invite_scanner_view.dart';

/// Route entry for `/scan-invite` — same 65%↔full sheet chrome as the FAB flow.
class InviteScanPage extends StatefulWidget {
  const InviteScanPage({super.key});

  @override
  State<InviteScanPage> createState() => _InviteScanPageState();
}

class _InviteScanPageState extends State<InviteScanPage> {
  void _close() => popOrGo(context, RoutePaths.home);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      seedParentHistoryForBrowserBack(
        context: context,
        parentPath: RoutePaths.home,
        currentPath: RoutePaths.scanInvite,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final canPop = routerCanPop(context);
    return PopScope(
      canPop: canPop,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _close();
      },
      child: Scaffold(
        backgroundColor: Colors.black54,
        body: SafaehCameraSheetHost(
          scrimColor: Colors.transparent,
          onDismiss: () async => _close(),
          builder: (context, sheet) => InviteScannerView(
            expanded: sheet.expanded,
            onToggleExpanded: sheet.toggleExpanded,
            onClose: sheet.dismiss,
          ),
        ),
      ),
    );
  }
}
