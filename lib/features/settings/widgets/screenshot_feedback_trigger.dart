import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:screen_capture_event/screen_capture_event.dart';

import '../providers/settings_framework_providers.dart';
import 'feedback_sheet.dart';

/// Listens for screenshot events and, when the setting is enabled, shows the
/// feedback sheet. No-op on web. Mount once (e.g. in [MainScaffold]) so it
/// has a valid [BuildContext] for showing the sheet.
class ScreenshotFeedbackTrigger extends ConsumerStatefulWidget {
  const ScreenshotFeedbackTrigger({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<ScreenshotFeedbackTrigger> createState() =>
      _ScreenshotFeedbackTriggerState();
}

class _ScreenshotFeedbackTriggerState
    extends ConsumerState<ScreenshotFeedbackTrigger> {
  ScreenCaptureEvent? _detector;
  bool _listenerAdded = false;

  void _onScreenshot(String filePath) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (ref.read(promptFeedbackOnScreenshotProvider)) {
        FeedbackSheet.show(context, fromScreenshot: true);
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (kIsWeb || _listenerAdded) return;
    _listenerAdded = true;
    try {
      _detector = ScreenCaptureEvent();
      _detector!.addScreenShotListener(_onScreenshot);
      _detector!.watch();
    } catch (_) {
      // Plugin may throw on unsupported platforms.
    }
  }

  @override
  void dispose() {
    _detector?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
