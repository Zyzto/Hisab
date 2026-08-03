/// Result from the sign-in sheet.
enum SignInResult {
  /// Authentication completed successfully.
  success,

  /// OAuth redirect was launched on web — the page will reload.
  /// Caller should set a "pending" flag so main.dart can finish the flow.
  pendingRedirect,

  /// Magic link (or similar email link) was sent. Caller should persist
  /// pending intent; dismiss must not be treated as cancel.
  pendingEmailLink,

  /// User cancelled.
  cancelled,
}
