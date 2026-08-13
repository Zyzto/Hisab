import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:marionette_flutter/marionette_flutter.dart';

import '../widgets/app_fab.dart';
import '../widgets/user_text.dart';
import 'is_flutter_test.dart';

/// Initializes [MarionetteBinding] in debug (non-test), else the stock binding.
///
/// Must be the only [WidgetsBinding] init in the process — see Marionette
/// "single-binding rule". Skipped under `FLUTTER_TEST` so widget/integration
/// harnesses keep their own binding.
void ensureHisabWidgetsBinding() {
  if (kDebugMode && !isFlutterTest) {
    final logCollector = PrintLogCollector();
    MarionetteBinding.ensureInitialized(
      MarionetteConfiguration(
        isInteractiveWidget: (type) => type == AppFab,
        extractText: (element) {
          final widget = element.widget;
          if (widget is UserText) return widget.data;
          if (widget is AppFab) {
            return widget.tooltip ?? widget.semanticsLabel ?? widget.label;
          }
          return null;
        },
        logCollector: logCollector,
      ),
    );
    final defaultDebugPrint = debugPrint;
    debugPrint = (message, {wrapWidth}) {
      if (message != null) logCollector.addLog(message);
      defaultDebugPrint(message, wrapWidth: wrapWidth);
    };
  } else {
    WidgetsFlutterBinding.ensureInitialized();
  }
}
