import 'package:flutter/material.dart';

import '../../../core/layout/sheet_handle_drag.dart';
import '../../../core/motion/app_motion.dart';
import '../../../core/navigation/nav_back.dart';
import '../../../core/navigation/route_paths.dart';
import 'invite_scanner_view.dart';
import 'show_invite_scanner.dart';

/// Route entry for `/scan-invite` — same 65%↔full sheet chrome as the FAB flow.
class InviteScanPage extends StatefulWidget {
  const InviteScanPage({super.key});

  @override
  State<InviteScanPage> createState() => _InviteScanPageState();
}

class _InviteScanPageState extends State<InviteScanPage> {
  bool _expanded = false;
  final _drag = SheetHandleDrag();

  void _close() => popOrGo(context, RoutePaths.home);

  void _onHandleDragEnd(DragEndDetails details) {
    final action = _drag.end(
      expanded: _expanded,
      velocity: details.primaryVelocity ?? 0,
    );
    setState(() {
      switch (action) {
        case SheetHandleDragAction.expand:
          _expanded = true;
        case SheetHandleDragAction.collapse:
          _expanded = false;
        case SheetHandleDragAction.dismiss:
          _close();
        case SheetHandleDragAction.none:
          break;
      }
      _drag.reset();
    });
  }

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
    final h = MediaQuery.sizeOf(context).height;
    final compactH = h * kInviteScannerCompactHeightFraction;
    final panelH = _drag.panelHeight(
      expanded: _expanded,
      compactH: compactH,
      fullH: h,
    );
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : AppMotion.modal;

    return PopScope(
      canPop: canPop,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _close();
      },
      child: Scaffold(
        backgroundColor: Colors.black54,
        body: Stack(
          fit: StackFit.expand,
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _close,
                child: const ColoredBox(color: Colors.transparent),
              ),
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: Transform.translate(
                offset: Offset(0, _drag.translateY(expanded: _expanded)),
                child: AnimatedContainer(
                  duration: _drag.offset == 0 ? duration : Duration.zero,
                  curve: AppMotion.enterCurve,
                  height: panelH,
                  width: double.infinity,
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: _expanded && _drag.offset <= 0
                        ? BorderRadius.zero
                        : const BorderRadius.vertical(top: Radius.circular(16)),
                  ),
                  child: Column(
                    children: [
                      SheetHandleBar(
                        expanded: _expanded,
                        duration: duration,
                        onVerticalDragUpdate: (details) {
                          setState(
                            () => _drag.update(
                              details.delta.dy,
                              expanded: _expanded,
                            ),
                          );
                        },
                        onVerticalDragEnd: _onHandleDragEnd,
                        onVerticalDragCancel: () => setState(_drag.reset),
                      ),
                      Expanded(
                        child: InviteScannerView(
                          expanded: _expanded,
                          onToggleExpanded: () => setState(() {
                            _expanded = !_expanded;
                            _drag.reset();
                          }),
                          onClose: _close,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
