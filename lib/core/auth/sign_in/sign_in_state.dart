import 'package:flutter/foundation.dart';

import '../predefined_avatars.dart';
import '../sign_in_result.dart';

/// Whether the form is signing an existing user in or creating an account.
enum SignInMode { signIn, signUp }

/// Sign-up is split so the account fields and the profile fields never compete
/// for the same screen on a phone.
enum SignUpStep {
  /// Email and password.
  credentials,

  /// Display name and avatar.
  profile,
}

/// Which panel the sheet shows in place of the form.
///
/// Deliberately separate from [SignInFormState.busy]: after a magic link is
/// sent on a native build the sheet shows the "check your email" panel *and*
/// keeps waiting for the deep link to come back.
enum SignInPanel {
  /// Editable form.
  none,

  /// Magic link sent; waiting for the user to open it.
  magicLinkSent,

  /// Account created, or sign-in blocked, pending email confirmation.
  awaitingConfirmation,

  /// Password reset email sent.
  resetSent,
}

/// Immutable snapshot of the sign-in sheet.
@immutable
class SignInFormState {
  const SignInFormState({
    this.mode = SignInMode.signIn,
    this.signUpStep = SignUpStep.credentials,
    this.panel = SignInPanel.none,
    this.busy = false,
    this.errorKey,
    this.obscurePassword = true,
    this.selectedAvatarId = defaultAvatarId,
    this.confirmationResent = false,
    this.emailLinkPending = false,
    this.outcome,
  });

  final SignInMode mode;
  final SignUpStep signUpStep;
  final SignInPanel panel;

  /// A request is in flight, or we are waiting on a deep link.
  final bool busy;

  /// Translation key of the current error, or null. See `authErrorKey`.
  final String? errorKey;

  final bool obscurePassword;
  final String selectedAvatarId;

  /// True once a confirmation email has been re-sent, so the banner stops
  /// offering the button again.
  final bool confirmationResent;

  /// True once any email has been sent (magic link, confirmation or reset).
  ///
  /// This is what makes a barrier dismiss resolve to
  /// [SignInResult.pendingEmailLink] instead of [SignInResult.cancelled] — the
  /// user has a link waiting in their inbox, so closing the sheet is not a
  /// cancellation.
  final bool emailLinkPending;

  /// Set when the flow is finished and the sheet should pop with this result.
  final SignInResult? outcome;

  bool get isSignUp => mode == SignInMode.signUp;

  bool get isProfileStep =>
      mode == SignInMode.signUp && signUpStep == SignUpStep.profile;

  /// True when a panel has replaced the form, so the sheet hides the inputs.
  bool get showsPanel => panel != SignInPanel.none;

  /// Gesture dismissal is blocked mid-request, but never while the user is
  /// simply waiting on an email — that would trap them in the sheet.
  bool get canPop => !busy || showsPanel;

  SignInFormState copyWith({
    SignInMode? mode,
    SignUpStep? signUpStep,
    SignInPanel? panel,
    bool? busy,
    String? errorKey,
    bool clearError = false,
    bool? obscurePassword,
    String? selectedAvatarId,
    bool? confirmationResent,
    bool? emailLinkPending,
    SignInResult? outcome,
  }) {
    return SignInFormState(
      mode: mode ?? this.mode,
      signUpStep: signUpStep ?? this.signUpStep,
      panel: panel ?? this.panel,
      busy: busy ?? this.busy,
      errorKey: clearError ? null : (errorKey ?? this.errorKey),
      obscurePassword: obscurePassword ?? this.obscurePassword,
      selectedAvatarId: selectedAvatarId ?? this.selectedAvatarId,
      confirmationResent: confirmationResent ?? this.confirmationResent,
      emailLinkPending: emailLinkPending ?? this.emailLinkPending,
      outcome: outcome ?? this.outcome,
    );
  }
}
