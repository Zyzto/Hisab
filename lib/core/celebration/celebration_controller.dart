import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../settings/providers/settings_framework_providers.dart';
import '../debug/integration_test_mode.dart';
import '../platform/ui_perf.dart';
import 'celebration_dedupe.dart';
import 'celebration_kind.dart';

/// Queues one-shot celebration requests for [CelebrationHost].
class CelebrationController extends ChangeNotifier {
  CelebrationRequest? _active;
  final List<CelebrationRequest> _queue = [];

  CelebrationRequest? get active => _active;

  void request(CelebrationKind kind, {String? dedupeKey}) {
    final next = CelebrationRequest(kind, dedupeKey: dedupeKey);
    if (_active == null) {
      _active = next;
      notifyListeners();
      return;
    }
    _queue.removeWhere((e) => e.kind == kind);
    if (_queue.length >= 2) _queue.removeAt(0);
    _queue.add(next);
  }

  void complete(CelebrationRequest request) {
    if (_active == null) return;
    if (_active!.kind != request.kind || _active!.at != request.at) return;
    if (_queue.isNotEmpty) {
      _active = _queue.removeAt(0);
    } else {
      _active = null;
    }
    notifyListeners();
  }
}

final celebrationControllerProvider = Provider<CelebrationController>((ref) {
  final controller = CelebrationController();
  ref.onDispose(controller.dispose);
  return controller;
});

/// Gate + optional dedupe, then enqueue a celebration.
Future<void> fireCelebration(
  WidgetRef ref,
  CelebrationKind kind, {
  String? dedupeKey,
}) async {
  // Flame game ticks forever; skip in integration tests so pumpAndSettle works.
  if (isIntegrationTestMode) return;
  if (UiPerf.preferReducedChromeMotion) return;
  if (!ref.read(extraAnimationsEnabledProvider)) return;
  if (dedupeKey != null) {
    final claimed = await CelebrationDedupe.instance.tryClaim(dedupeKey);
    if (!claimed) return;
  }
  ref.read(celebrationControllerProvider).request(kind, dedupeKey: dedupeKey);
}
