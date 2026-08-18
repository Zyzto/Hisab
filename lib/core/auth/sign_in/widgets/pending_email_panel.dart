// intl (via easy_localization) exports its own TextDirection, which shadows
// the dart:ui one the address below needs.
import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';

import '../../../theme/accent_style.dart';
import '../sign_in_state.dart';
import 'auth_buttons.dart';

/// Replaces the form once an email is on its way: magic link, confirmation or
/// password reset.
///
/// This is the one screen the user is asked to leave the app from, so it is
/// built as a destination rather than an error strip: an icon well, the
/// instruction, and the address it actually went to. Echoing the address is
/// what makes a typo visible — otherwise a mistyped domain looks exactly like
/// a slow inbox.
///
/// Closing from here resolves to `pendingEmailLink`, never `cancelled` — the
/// user has a live link in their inbox, so the flow is in progress rather than
/// abandoned.
class PendingEmailPanel extends StatelessWidget {
  const PendingEmailPanel({
    super.key,
    required this.panel,
    required this.email,
    required this.confirmationResent,
    required this.busy,
    required this.onResend,
    required this.onDone,
  });

  final SignInPanel panel;

  /// Address the mail went to. Empty only if the flow got here without one.
  final String email;

  /// True once the confirmation email has been sent again, which replaces the
  /// resend button with an acknowledgement.
  final bool confirmationResent;

  final bool busy;
  final VoidCallback onResend;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final awaitingConfirmation = panel == SignInPanel.awaitingConfirmation;
    final canResend = awaitingConfirmation && !confirmationResent;

    // Unconfirmed is the one state that is a blocker rather than progress, so
    // it gets the tertiary "needs you" colour instead of the primary accent.
    final needsAction = awaitingConfirmation && !confirmationResent;
    final accent = needsAction ? cs.tertiary : cs.primary;
    final accentContainer = needsAction
        ? cs.tertiaryContainer
        : cs.primaryContainer;

    final (String message, IconData icon) = switch (panel) {
      SignInPanel.magicLinkSent => (
        'auth_magic_link_sent'.tr(),
        Icons.mark_email_read_outlined,
      ),
      SignInPanel.resetSent => (
        'auth_reset_sent'.tr(),
        Icons.lock_reset_outlined,
      ),
      SignInPanel.awaitingConfirmation when confirmationResent => (
        'auth_confirmation_resent'.tr(),
        Icons.mark_email_read_outlined,
      ),
      SignInPanel.awaitingConfirmation => (
        'auth_email_not_confirmed'.tr(),
        Icons.mark_email_unread_outlined,
      ),
      SignInPanel.none => ('auth_generic_error'.tr(), Icons.error_outline),
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: accentContainer.withValues(alpha: 0.55),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 30, color: accent),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          message,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(height: 1.4),
        ),
        if (email.isNotEmpty) ...[
          const SizedBox(height: 14),
          DecoratedBox(
            decoration: AccentSurfaces.flatPanel(cs, radius: 12),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Column(
                children: [
                  Text(
                    'auth_sent_to'.tr(),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    email,
                    textAlign: TextAlign.center,
                    // An address is not prose: keep it LTR so an Arabic UI
                    // does not reorder it around the @.
                    textDirection: TextDirection.ltr,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
        if (canResend) ...[
          const SizedBox(height: 16),
          NonFocusable(
            child: OutlinedButton.icon(
              onPressed: busy ? null : onResend,
              icon: const Icon(Icons.send, size: 18),
              label: Text('auth_resend_confirmation'.tr()),
            ),
          ),
        ],
        const SizedBox(height: 20),
        AuthPrimaryButton(label: 'done'.tr(), onPressed: onDone),
      ],
    );
  }
}
