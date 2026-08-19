import 'package:flutter/material.dart';

/// Severity of an [InlineBanner], which picks its colours and default icon.
enum InlineBannerTone {
  /// A failure the user has to act on.
  error,

  /// Neutral progress or confirmation, e.g. "check your email".
  info,

  /// Something succeeded.
  success,

  /// Not an error, but the flow cannot finish until the user does something
  /// outside the app.
  warning,
}

/// Inline message block used inside sheets, above or below a form.
///
/// Replaces the hand-rolled `Container` + `Row` callouts that were copied
/// between the auth sheets, so tone and spacing stay consistent.
class InlineBanner extends StatelessWidget {
  const InlineBanner({
    super.key,
    required this.message,
    this.detail,
    this.tone = InlineBannerTone.error,
    this.icon,
    this.actions = const <Widget>[],
  });

  final String message;

  /// Secondary line under [message], for the "here is what to try instead"
  /// half of a failure. Rendered smaller and dimmer so the message still leads.
  final String? detail;

  final InlineBannerTone tone;

  /// Overrides the tone's default icon.
  final IconData? icon;

  /// Full-width buttons stacked under the message.
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final (
      Color background,
      Color foreground,
      Color iconColor,
    ) = switch (tone) {
      InlineBannerTone.error => (
        cs.errorContainer,
        cs.onErrorContainer,
        cs.error,
      ),
      InlineBannerTone.info => (
        cs.primaryContainer.withValues(alpha: 0.3),
        cs.onPrimaryContainer,
        cs.primary,
      ),
      InlineBannerTone.success => (
        cs.primaryContainer.withValues(alpha: 0.3),
        cs.onPrimaryContainer,
        cs.primary,
      ),
      InlineBannerTone.warning => (
        cs.tertiaryContainer.withValues(alpha: 0.3),
        cs.onTertiaryContainer,
        cs.tertiary,
      ),
    };

    final resolvedIcon =
        icon ??
        switch (tone) {
          InlineBannerTone.error => Icons.error_outline,
          InlineBannerTone.info => Icons.info_outline,
          InlineBannerTone.success => Icons.check_circle_outline,
          InlineBannerTone.warning => Icons.mark_email_unread_outlined,
        };

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(resolvedIcon, size: 20, color: iconColor),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      message,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: foreground,
                      ),
                    ),
                    if (detail != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        detail!,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: foreground.withValues(alpha: 0.75),
                          height: 1.35,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          for (final action in actions) ...[const SizedBox(height: 12), action],
        ],
      ),
    );
  }
}
