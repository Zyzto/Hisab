import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Holds the optional callback to trigger a manual "check for updates". Set by
/// [App] when the Upgrader is ready; invoked from settings About section.
/// The callback receives [BuildContext] so it can show snackbars (e.g. "No update
/// available" or "Could not check for updates") after the async check completes.
class _UpdateCheckTriggerHolder {
  void Function(BuildContext context)? callback;
}

final updateCheckTriggerProvider =
    Provider<_UpdateCheckTriggerHolder>((ref) => _UpdateCheckTriggerHolder());
