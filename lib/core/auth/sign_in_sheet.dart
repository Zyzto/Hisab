import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_logging_service/flutter_logging_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth_providers.dart';
import 'predefined_avatars.dart';

/// Result from the sign-in sheet.
enum SignInResult {
  /// Authentication completed successfully.
  success,

  /// OAuth redirect was launched on web — the page will reload.
  /// Caller should set a "pending" flag so main.dart can finish the flow.
  pendingRedirect,

  /// User cancelled.
  cancelled,
}

/// A reusable bottom sheet for Supabase authentication.
/// Supports email sign-in, sign-up, magic link, Google OAuth, and GitHub OAuth.
///
/// Usage:
/// ```dart
/// final result = await showSignInSheet(context, ref);
/// ```
Future<SignInResult> showSignInSheet(
  BuildContext context,
  WidgetRef ref,
) async {
  final result = await showModalBottomSheet<SignInResult>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => _SignInSheet(ref: ref),
  );
  return result ?? SignInResult.cancelled;
}

class _SignInSheet extends StatefulWidget {
  const _SignInSheet({required this.ref});
  final WidgetRef ref;

  @override
  State<_SignInSheet> createState() => _SignInSheetState();
}

class _SignInSheetState extends State<_SignInSheet> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  bool _isSignUp = false;
  bool _loading = false;
  String? _error;
  bool _magicLinkSent = false;
  bool _emailNotConfirmed = false;
  bool _confirmationResent = false;
  String _selectedAvatarId = defaultAvatarId;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _signInWithEmail() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    if (email.isEmpty || password.isEmpty) {
      setState(() => _error = 'auth_fill_fields'.tr());
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final authService = widget.ref.read(authServiceProvider);
      if (_isSignUp) {
        final name = _nameController.text.trim();
        final response = await authService.signUpWithEmail(
          email,
          password,
          name: name.isEmpty ? null : name,
          avatarId: _selectedAvatarId,
        );
        // If email confirmation is required, the user won't have a session yet.
        if (response.session == null) {
          Log.info('Sign-up succeeded — email confirmation required');
          if (mounted) {
            setState(() {
              _loading = false;
              _emailNotConfirmed = true;
              _confirmationResent = false;
              _error = null;
            });
          }
          return;
        }
        Log.info('User signed up with email');
      } else {
        await authService.signInWithEmail(email, password);
        Log.info('User signed in with email');
      }
      if (mounted) Navigator.pop(context, SignInResult.success);
    } catch (e) {
      Log.warning('Email auth failed', error: e);
      if (mounted) {
        final isNotConfirmed = _isEmailNotConfirmedError(e);
        setState(() {
          _loading = false;
          _emailNotConfirmed = isNotConfirmed;
          _confirmationResent = false;
          _error = isNotConfirmed
              ? 'auth_email_not_confirmed'.tr()
              : _parseAuthError(e);
        });
      }
    }
  }

  Future<void> _sendMagicLink() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      setState(() => _error = 'auth_enter_email'.tr());
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final authService = widget.ref.read(authServiceProvider);
      await authService.signInWithMagicLink(email);
      if (mounted) {
        setState(() {
          _loading = false;
          _magicLinkSent = true;
        });
      }
    } catch (e) {
      Log.warning('Magic link failed', error: e);
      if (mounted) {
        setState(() {
          _loading = false;
          _error = _parseAuthError(e);
        });
      }
    }
  }

  Future<void> _signInWithOAuth(OAuthProvider provider) async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final authService = widget.ref.read(authServiceProvider);
      final providerName = provider == OAuthProvider.google
          ? 'Google'
          : 'GitHub';

      bool launched;
      if (provider == OAuthProvider.google) {
        launched = await authService.signInWithGoogle();
      } else {
        launched = await authService.signInWithGithub();
      }

      if (!launched) {
        if (mounted) {
          setState(() {
            _loading = false;
            _error = 'auth_oauth_failed'.tr();
          });
        }
        return;
      }

      if (kIsWeb) {
        // On web, OAuth causes a full page redirect. The session will be
        // available when the app reloads. Tell the caller to set a pending flag.
        Log.info('$providerName OAuth redirect started (web)');
        if (mounted) Navigator.pop(context, SignInResult.pendingRedirect);
        return;
      }

      // On native, wait for the auth state change after the browser callback.
      Log.debug('Waiting for $providerName OAuth callback (native)');
      final completer = Completer<bool>();
      final sub = authService.onAuthStateChange.listen((state) {
        if (state.event == AuthChangeEvent.signedIn && !completer.isCompleted) {
          completer.complete(true);
        }
      });

      try {
        final ok = await completer.future.timeout(
          const Duration(minutes: 3),
          onTimeout: () => false,
        );
        sub.cancel();

        if (ok) {
          Log.info('$providerName OAuth sign-in completed (native)');
          if (mounted) Navigator.pop(context, SignInResult.success);
        } else {
          Log.warning('$providerName OAuth timed out');
          if (mounted) {
            setState(() {
              _loading = false;
              _error = 'auth_oauth_timeout'.tr();
            });
          }
        }
      } catch (e) {
        sub.cancel();
        rethrow;
      }
    } catch (e) {
      Log.warning('OAuth sign-in failed', error: e);
      if (mounted) {
        setState(() {
          _loading = false;
          _error = _parseAuthError(e);
        });
      }
    }
  }

  bool _isEmailNotConfirmedError(Object e) {
    if (e is AuthException) {
      return e.message.toLowerCase().contains('email not confirmed') ||
          (e.code == 'email_not_confirmed');
    }
    return e.toString().contains('email_not_confirmed') ||
        e.toString().contains('Email not confirmed');
  }

  Future<void> _resendConfirmation() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final authService = widget.ref.read(authServiceProvider);
      await authService.resendConfirmation(email);
      if (mounted) {
        setState(() {
          _loading = false;
          _confirmationResent = true;
          _error = null;
        });
      }
    } catch (e) {
      Log.warning('Resend confirmation failed', error: e);
      if (mounted) {
        final isRateLimit = e is AuthException &&
            (e.code == 'over_email_send_rate_limit' ||
                e.message.toLowerCase().contains('rate limit'));
        setState(() {
          _loading = false;
          // On rate limit, keep the confirmation banner and show a
          // friendly message — the original email was already sent.
          if (isRateLimit) {
            _confirmationResent = true; // treat as "already sent"
            _error = null;
          } else {
            _error = _parseAuthError(e);
          }
        });
      }
    }
  }

  String _parseAuthError(Object e) {
    if (e is AuthException) {
      if (e.message.toLowerCase().contains('email not confirmed')) {
        return 'auth_email_not_confirmed'.tr();
      }
      if (e.code == 'over_email_send_rate_limit' ||
          e.message.toLowerCase().contains('rate limit')) {
        return 'auth_rate_limit'.tr();
      }
      return e.message;
    }
    final msg = e.toString();
    if (msg.contains('Invalid login credentials')) {
      return 'auth_invalid_credentials'.tr();
    }
    if (msg.contains('User already registered')) {
      return 'auth_already_registered'.tr();
    }
    if (msg.contains('email_not_confirmed') ||
        msg.contains('Email not confirmed')) {
      return 'auth_email_not_confirmed'.tr();
    }
    if (msg.contains('rate limit') || msg.contains('rate_limit')) {
      return 'auth_rate_limit'.tr();
    }
    return 'auth_generic_error'.tr();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: colorScheme.outline.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Title
            Text(
              _isSignUp ? 'auth_sign_up'.tr() : 'sign_in'.tr(),
              style: textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              _isSignUp
                  ? 'auth_sign_up_subtitle'.tr()
                  : 'auth_sign_in_subtitle'.tr(),
              style: textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),

            // Sign-up only: name and avatar
            if (_isSignUp) ...[
              TextField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'auth_name'.tr(),
                  hintText: 'auth_name_hint'.tr(),
                  prefixIcon: const Icon(Icons.badge_outlined),
                  border: const OutlineInputBorder(),
                ),
                textInputAction: TextInputAction.next,
                enabled: !_loading,
              ),
              const SizedBox(height: 12),
              Text(
                'auth_avatar'.tr(),
                style: textTheme.labelLarge?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: predefinedAvatars.map((e) {
                  final selected = _selectedAvatarId == e.key;
                  return GestureDetector(
                    onTap: _loading
                        ? null
                        : () => setState(() => _selectedAvatarId = e.key),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: selected
                            ? colorScheme.primaryContainer
                            : colorScheme.surfaceContainerHighest,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: selected
                              ? colorScheme.primary
                              : colorScheme.outline.withValues(alpha: 0.3),
                          width: selected ? 2.5 : 1,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        e.value,
                        style: const TextStyle(fontSize: 22),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),
            ],

            // Magic link sent confirmation
            if (_magicLinkSent) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.mark_email_read, color: colorScheme.primary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'auth_magic_link_sent'.tr(),
                        style: textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onPrimaryContainer,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Email confirmation banner (after sign-up or when sign-in blocked)
            if (_emailNotConfirmed) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _confirmationResent
                      ? colorScheme.primaryContainer.withValues(alpha: 0.3)
                      : colorScheme.tertiaryContainer.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          _confirmationResent
                              ? Icons.mark_email_read
                              : Icons.mark_email_unread,
                          color: _confirmationResent
                              ? colorScheme.primary
                              : colorScheme.tertiary,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _confirmationResent
                                ? 'auth_confirmation_resent'.tr()
                                : 'auth_email_not_confirmed'.tr(),
                            style: textTheme.bodyMedium?.copyWith(
                              color: _confirmationResent
                                  ? colorScheme.onPrimaryContainer
                                  : colorScheme.onTertiaryContainer,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (!_confirmationResent) ...[
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _loading ? null : _resendConfirmation,
                          icon: const Icon(Icons.send, size: 18),
                          label: Text('auth_resend_confirmation'.tr()),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Error message
            if (_error != null && !_emailNotConfirmed) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 20,
                      color: colorScheme.error,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _error!,
                        style: textTheme.bodySmall?.copyWith(
                          color: colorScheme.onErrorContainer,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // OAuth buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _loading
                        ? null
                        : () => _signInWithOAuth(OAuthProvider.google),
                    icon: const Icon(Icons.g_mobiledata, size: 22),
                    label: const Text('Google'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _loading
                        ? null
                        : () => _signInWithOAuth(OAuthProvider.github),
                    icon: const Icon(Icons.code, size: 20),
                    label: const Text('GitHub'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Divider
            Row(
              children: [
                Expanded(
                  child: Divider(
                    color: colorScheme.outline.withValues(alpha: 0.3),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    'auth_or'.tr(),
                    style: textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                Expanded(
                  child: Divider(
                    color: colorScheme.outline.withValues(alpha: 0.3),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Email field
            TextField(
              controller: _emailController,
              decoration: InputDecoration(
                labelText: 'auth_email'.tr(),
                prefixIcon: const Icon(Icons.email_outlined),
                border: const OutlineInputBorder(),
              ),
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              enabled: !_loading,
            ),
            const SizedBox(height: 12),

            // Password field
            TextField(
              controller: _passwordController,
              decoration: InputDecoration(
                labelText: 'auth_password'.tr(),
                prefixIcon: const Icon(Icons.lock_outline),
                border: const OutlineInputBorder(),
              ),
              obscureText: true,
              textInputAction: TextInputAction.done,
              enabled: !_loading,
              onSubmitted: (_) => _signInWithEmail(),
            ),
            const SizedBox(height: 16),

            // Sign in / Sign up button
            FilledButton(
              onPressed: _loading ? null : _signInWithEmail,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: _loading
                  ? SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: colorScheme.onPrimary,
                      ),
                    )
                  : Text(
                      _isSignUp ? 'auth_sign_up'.tr() : 'sign_in'.tr(),
                      style: const TextStyle(fontSize: 16),
                    ),
            ),
            const SizedBox(height: 8),

            // Magic link button
            TextButton(
              onPressed: _loading ? null : _sendMagicLink,
              child: Text('auth_magic_link'.tr()),
            ),

            // Toggle sign-in / sign-up
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  _isSignUp ? 'auth_have_account'.tr() : 'auth_no_account'.tr(),
                  style: textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                TextButton(
                  onPressed: _loading
                      ? null
                      : () => setState(() {
                          _isSignUp = !_isSignUp;
                          _error = null;
                          if (_isSignUp) {
                            _selectedAvatarId = defaultAvatarId;
                          }
                        }),
                  child: Text(_isSignUp ? 'sign_in'.tr() : 'auth_sign_up'.tr()),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
