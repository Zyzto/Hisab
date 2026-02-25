import 'package:back_button_interceptor/back_button_interceptor.dart';
import 'package:flutter/material.dart';

/// Wraps [child] and registers a [BackButtonInterceptor] that dismisses the
/// keyboard on back when it is visible, so the first back press does not
/// navigate. Registering in a post-frame callback ensures this runs before
/// route-specific interceptors (e.g. MainScaffold double-back-to-exit).
class BackButtonKeyboardDismiss extends StatefulWidget {
  const BackButtonKeyboardDismiss({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  State<BackButtonKeyboardDismiss> createState() =>
      _BackButtonKeyboardDismissState();
}

class _BackButtonKeyboardDismissState extends State<BackButtonKeyboardDismiss> {
  bool _registered = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // Do not pass context: our widget may be above the Navigator in the tree
      // (e.g. in the router builder), and the package would call Navigator.of(context)
      // and throw. The callback only needs to dismiss keyboard; route info is unused.
      BackButtonInterceptor.add(_onBack);
      _registered = true;
    });
  }

  @override
  void dispose() {
    if (_registered) {
      BackButtonInterceptor.remove(_onBack);
    }
    super.dispose();
  }

  bool _onBack(bool stopDefaultButtonEvent, RouteInfo info) {
    if (!context.mounted) return false;
    if (MediaQuery.viewInsetsOf(context).bottom > 0) {
      FocusManager.instance.primaryFocus?.unfocus();
      return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
