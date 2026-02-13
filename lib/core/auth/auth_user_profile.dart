/// User profile from Supabase Auth. Used in settings to display account info.
class AuthUserProfile {
  const AuthUserProfile({
    required this.name,
    required this.email,
    required this.sub,
  });
  final String? name;
  final String? email;
  final String sub;
}
