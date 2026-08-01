import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:feedback/feedback.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/settings/feedback_handler.dart';
import '../../features/settings/providers/settings_framework_providers.dart';
import '../navigation/app_router.dart';
import '../platform/screenshot_report_support.dart';
import '../widgets/toast.dart';
import 'screenshot_detector.dart';
import 'screenshot_report_prompt_logic.dart';

/// Listens for OS screenshots when the privacy toggle is on and prompts
/// the user to open BetterFeedback → shared bug report.
class ScreenshotReportPromptHost extends ConsumerStatefulWidget {
  const ScreenshotReportPromptHost({
    super.key,
    required this.child,
    ScreenshotDetector? detector,
    ScreenshotReportPromptLogic? logic,
  }) : _detector = detector,
       _logic = logic;

  final Widget child;
  final ScreenshotDetector? _detector;
  final ScreenshotReportPromptLogic? _logic;

  @override
  ConsumerState<ScreenshotReportPromptHost> createState() =>
      _ScreenshotReportPromptHostState();
}

class _ScreenshotReportPromptHostState
    extends ConsumerState<ScreenshotReportPromptHost>
    with WidgetsBindingObserver {
  late final ScreenshotDetector _detector;
  late final ScreenshotReportPromptLogic _logic;
  StreamSubscription<void>? _subscription;
  var _lifecycle = AppLifecycleState.resumed;
  var _listening = false;
  bool? _desiredListening;
  Future<void>? _syncInFlight;
  var _pendingPrompt = false;

  bool get _appInForeground =>
      _lifecycle == AppLifecycleState.resumed ||
      _lifecycle == AppLifecycleState.inactive;

  @override
  void initState() {
    super.initState();
    _detector = widget._detector ?? createScreenshotDetector();
    _logic = widget._logic ?? ScreenshotReportPromptLogic();
    WidgetsBinding.instance.addObserver(this);
    if (supportsScreenshotReportPrompt) {
      _subscription = _detector.events.listen((_) => _onScreenshot());
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        unawaited(
          _syncListening(ref.read(screenshotReportPromptEnabledProvider)),
        );
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _subscription?.cancel();
    _desiredListening = false;
    _pendingPrompt = false;
    unawaited(_detector.setEnabled(false));
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _lifecycle = state;
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached ||
        state == AppLifecycleState.hidden) {
      _pendingPrompt = false;
      return;
    }
    if (state == AppLifecycleState.resumed && _pendingPrompt) {
      _pendingPrompt = false;
      _showPrompt();
    }
  }

  Future<void> _syncListening(bool enabled) async {
    if (!supportsScreenshotReportPrompt) return;
    _desiredListening = enabled;
    if (_syncInFlight != null) return;
    _syncInFlight = _drainListeningSync();
    try {
      await _syncInFlight;
    } finally {
      _syncInFlight = null;
      final desired = _desiredListening;
      if (mounted && desired != null && desired != _listening) {
        unawaited(_syncListening(desired));
      }
    }
  }

  Future<void> _drainListeningSync() async {
    while (mounted &&
        _desiredListening != null &&
        _desiredListening != _listening) {
      final next = _desiredListening!;
      await _detector.setEnabled(next);
      if (!mounted) return;
      _listening = next;
    }
  }

  void _onScreenshot() {
    if (!mounted) return;
    final enabled = ref.read(screenshotReportPromptEnabledProvider);
    final navContext =
        ref.read(routerProvider).routerDelegate.navigatorKey.currentContext;
    var feedbackOpen = false;
    if (navContext != null && navContext.mounted) {
      try {
        feedbackOpen = BetterFeedback.of(navContext).isVisible;
      } catch (_) {
        feedbackOpen = false;
      }
    }
    if (!_logic.shouldPrompt(
      enabled: enabled,
      appInForeground: _appInForeground,
      feedbackOpen: feedbackOpen,
    )) {
      return;
    }

    // iOS often delivers the screenshot notification while [inactive]; show
    // the toast once we are fully [resumed] again.
    if (_lifecycle != AppLifecycleState.resumed) {
      _pendingPrompt = true;
      return;
    }
    _showPrompt();
  }

  void _showPrompt() {
    if (!mounted) return;
    final navContext =
        ref.read(routerProvider).routerDelegate.navigatorKey.currentContext;
    if (navContext == null || !navContext.mounted) return;

    var feedbackOpen = false;
    try {
      feedbackOpen = BetterFeedback.of(navContext).isVisible;
    } catch (_) {
      feedbackOpen = false;
    }
    if (feedbackOpen) return;
    if (!ref.read(screenshotReportPromptEnabledProvider)) return;

    navContext.showPromptWithAction(
      'screenshot_report_prompt_message'.tr(),
      actionLabel: 'report_issue'.tr(),
      onAction: () {
        if (!navContext.mounted) return;
        try {
          BetterFeedback.of(navContext).hide();
          BetterFeedback.of(navContext).show(
            (feedback) => handleFeedback(navContext, feedback: feedback),
          );
        } catch (_) {}
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<bool>(screenshotReportPromptEnabledProvider, (prev, next) {
      unawaited(_syncListening(next));
    });
    return widget.child;
  }
}
