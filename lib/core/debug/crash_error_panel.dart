import 'package:flutter/material.dart';

/// Fallback painted when a widget `build` throws.
///
/// [ErrorWidget.builder] can replace a subtree that has no [Directionality]
/// (or even no [MediaQuery]). [Icon] and [SafeArea] both require those
/// ancestors, so this panel always provides them when missing.
class CrashErrorPanel extends StatelessWidget {
  const CrashErrorPanel({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    Widget child = Material(
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                message,
                style: const TextStyle(fontSize: 14),
                textAlign: TextAlign.center,
                maxLines: 8,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
    if (MediaQuery.maybeOf(context) == null) {
      child = MediaQuery(data: const MediaQueryData(), child: child);
    }
    if (Directionality.maybeOf(context) == null) {
      child = Directionality(textDirection: TextDirection.ltr, child: child);
    }
    return child;
  }
}
