import 'package:flutter/material.dart';
import 'package:toastification/toastification.dart';

/// Unified toast API over [toastification]. Use these extensions instead of
/// [ScaffoldMessenger.showSnackBar] for consistent styling and behavior.
extension ToastContext on BuildContext {
  /// Shows a toast with optional [duration] and [type]. Default: 4s, info.
  void showToast(
    String message, {
    Duration? duration,
    ToastificationType? type,
  }) {
    if (!mounted) return;
    toastification.show(
      context: this,
      title: Text(message),
      type: type ?? ToastificationType.info,
      style: ToastificationStyle.flat,
      autoCloseDuration: duration ?? const Duration(seconds: 4),
    );
  }

  /// Shows a success toast (e.g. "Copied", "Saved").
  void showSuccess(String message, {Duration? duration}) {
    showToast(message, duration: duration, type: ToastificationType.success);
  }

  /// Shows an error toast.
  void showError(String message, {Duration? duration}) {
    showToast(message, duration: duration, type: ToastificationType.error);
  }

  /// Dismisses all visible toasts. Use before showing a replacement (e.g. sync status).
  void dismissAllToasts() {
    if (!mounted) return;
    toastification.dismissAll(delayForAnimation: true);
  }
}
