/// Push token registration and delivery preferences.
///
/// Displaying a notification is entirely client-side. Only the token handshake
/// and the suppression flag cross the seam.
abstract interface class CloudNotifications {
  /// Registers or refreshes this device's push token for the signed-in user.
  ///
  /// Must be idempotent, and must transfer the token to the current user when
  /// a different account previously claimed it — otherwise a shared device
  /// keeps delivering to whoever signed in first.
  ///
  /// [platform] is one of `android`, `ios`, `web`. [locale] is a BCP-47 tag
  /// used to localize the pushed text server-side.
  Future<void> claimDeviceToken({
    required String token,
    required String platform,
    String? locale,
  });

  /// Unregisters a token, on sign-out or when the device rotates it.
  Future<void> removeDeviceToken(String token);

  /// Suppresses activity notifications for the caller while [active] is true.
  ///
  /// Set around a bulk sync so migrating a large local database does not fan
  /// out a notification per row to every other group member.
  Future<void> setNotifySuppress(bool active);

  /// The caller's notification feed, newest first. Tolerant: returns an empty
  /// list rather than throwing when unsupported.
  Future<List<Map<String, dynamic>>> fetchNotifications(String userId);
}
