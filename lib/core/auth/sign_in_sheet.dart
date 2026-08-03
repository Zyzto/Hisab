import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_logging_service/flutter_logging_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth_flow_policy.dart';
import 'auth_providers.dart';
import '../layout/layout_breakpoints.dart';
import '../layout/responsive_sheet.dart';
import 'predefined_avatars.dart';
import 'sign_in_result.dart';

export 'sign_in_result.dart' show SignInResult;

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
  var emailLinkPending = false;
  final result = await showResponsiveSheet<SignInResult>(
    context: context,
    title: 'sign_in'.tr(),
    isScrollControlled: true,
    useSafeArea: true,
    centerInFullViewport: true,
    child: _SignInSheet(
      ref: ref,
      onEmailLinkPending: () => emailLinkPending = true,
    ),
  );
  if (result != null) return result;
  // Barrier/back dismiss after magic link / confirm email must keep pending intent.
  return resolveSignInSheetDismiss(emailLinkPending: emailLinkPending);
}

class _SignInSheet extends StatefulWidget {
  const _SignInSheet({required this.ref, required this.onEmailLinkPending});
  final WidgetRef ref;
  final VoidCallback onEmailLinkPending;

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
          widget.onEmailLinkPending();
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
        if (isNotConfirmed) widget.onEmailLinkPending();
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

    final authService = widget.ref.read(authServiceProvider);
    Completer<bool>? completer;
    StreamSubscription<AuthState>? sub;
    try {
      // Subscribe before send on native so a fast callback cannot be missed.
      if (!kIsWeb) {
        if (authService.isAuthenticated) {
          widget.onEmailLinkPending();
          if (mounted) Navigator.pop(context, SignInResult.success);
          return;
        }
        completer = Completer<bool>();
        sub = authService.onAuthStateChange.listen((state) {
          if (state.event == AuthChangeEvent.signedIn &&
              completer != null &&
              !completer.isCompleted) {
            completer.complete(true);
          }
        });
      }

      await authService.signInWithMagicLink(email);
      widget.onEmailLinkPending();
      if (!mounted) return;

      setState(() {
        _magicLinkSent = true;
        // Web: idle with Done. Native: keep waiting for deep-link signedIn.
        _loading = !kIsWeb;
      });

      if (kIsWeb) return;

      Log.debug('Waiting for magic-link callback (native)');
      final ok = await completer!.future.timeout(
        const Duration(minutes: 3),
        onTimeout: () => false,
      );
      if (ok) {
        Log.info('Magic-link sign-in completed (native)');
        if (mounted) Navigator.pop(context, SignInResult.success);
      } else {
        Log.warning('Magic-link auth timed out');
        if (mounted) {
          setState(() {
            _loading = false;
            _error = 'auth_oauth_timeout'.tr();
          });
        }
      }
    } catch (e) {
      Log.warning('Magic link failed', error: e);
      if (mounted) {
        setState(() {
          _loading = false;
          _error = _parseAuthError(e);
        });
      }
    } finally {
      await sub?.cancel();
    }
  }

  Future<void> _signInWithOAuth(OAuthProvider provider) async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final authService = widget.ref.read(authServiceProvider);
    final providerName = provider == OAuthProvider.google ? 'Google' : 'GitHub';
    Completer<bool>? completer;
    StreamSubscription<AuthState>? sub;
    try {
      // Subscribe before launch on native so a fast callback cannot be missed.
      if (!kIsWeb) {
        completer = Completer<bool>();
        sub = authService.onAuthStateChange.listen((state) {
          if (state.event == AuthChangeEvent.signedIn &&
              completer != null &&
              !completer.isCompleted) {
            completer.complete(true);
          }
        });
      }

      final launched = provider == OAuthProvider.google
          ? await authService.signInWithGoogle()
          : await authService.signInWithGithub();

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

      Log.debug('Waiting for $providerName OAuth callback (native)');
      final ok = await completer!.future.timeout(
        const Duration(minutes: 3),
        onTimeout: () => false,
      );

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
      Log.warning('OAuth sign-in failed', error: e);
      if (mounted) {
        setState(() {
          _loading = false;
          _error = _parseAuthError(e);
        });
      }
    } finally {
      await sub?.cancel();
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
        final isRateLimit =
            e is AuthException &&
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
      return 'auth_generic_error'.tr();
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

  Widget _nonFocusableAction(Widget child) {
    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      descendantsAreFocusable: false,
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return PopScope(
      // Allow dismiss after magic/confirm email link (returns pendingEmailLink).
      canPop: !_loading || _magicLinkSent || _emailNotConfirmed,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          24,
          16,
          24,
          MediaQuery.of(context).padding.bottom + 24,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Title (omit on tablet+ when top bar shows it).
              // Drag handle comes from showResponsiveSheet — do not duplicate.
              if (!LayoutBreakpoints.isTabletOrWider(context)) ...[
                Text(
                  _isSignUp ? 'auth_sign_up'.tr() : 'sign_in'.tr(),
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
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
                const SizedBox(height: 20),
              ],

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
                const SizedBox(height: 12),
                _nonFocusableAction(
                  FilledButton(
                    onPressed: () => Navigator.pop(
                      context,
                      SignInResult.pendingEmailLink,
                    ),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: Text('done'.tr()),
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
                          child: _nonFocusableAction(
                            OutlinedButton.icon(
                              onPressed: _loading ? null : _resendConfirmation,
                              icon: const Icon(Icons.send, size: 18),
                              label: Text('auth_resend_confirmation'.tr()),
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: _nonFocusableAction(
                          FilledButton(
                            onPressed: () => Navigator.pop(
                              context,
                              SignInResult.pendingEmailLink,
                            ),
                            style: FilledButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            child: Text('done'.tr()),
                          ),
                        ),
                      ),
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
                    child: _nonFocusableAction(
                      OutlinedButton.icon(
                        onPressed: _loading
                            ? null
                            : () => _signInWithOAuth(OAuthProvider.google),
                        icon: const Icon(Icons.g_mobiledata, size: 22),
                        label: Text('auth_provider_google'.tr()),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _nonFocusableAction(
                      OutlinedButton.icon(
                        onPressed: _loading
                            ? null
                            : () => _signInWithOAuth(OAuthProvider.github),
                        icon: const Icon(Icons.code, size: 20),
                        label: Text('auth_provider_github'.tr()),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
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
              _nonFocusableAction(
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
              ),
              const SizedBox(height: 8),

              // Magic link button
              _nonFocusableAction(
                TextButton(
                  onPressed: _loading ? null : _sendMagicLink,
                  child: Text('auth_magic_link'.tr()),
                ),
              ),

              // Toggle sign-in / sign-up
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _isSignUp
                        ? 'auth_have_account'.tr()
                        : 'auth_no_account'.tr(),
                    style: textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  _nonFocusableAction(
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
                      child: Text(
                        _isSignUp ? 'sign_in'.tr() : 'auth_sign_up'.tr(),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
