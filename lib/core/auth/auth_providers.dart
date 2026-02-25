import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../constants/supabase_config.dart';
import 'auth_service.dart';

part 'auth_providers.g.dart';

@Riverpod(keepAlive: true)
AuthService authService(Ref ref) => AuthService();

@riverpod
Stream<AuthState> authStateChanges(Ref ref) {
  if (!supabaseConfigAvailable) return const Stream.empty();
  return ref.watch(authServiceProvider).onAuthStateChange;
}

@riverpod
bool isAuthenticated(Ref ref) {
  if (!supabaseConfigAvailable) return false;
  final asyncAuth = ref.watch(authStateChangesProvider);
  return asyncAuth.whenOrNull(data: (state) => state.session != null) ?? false;
}

@riverpod
User? currentUser(Ref ref) {
  if (!supabaseConfigAvailable) return null;
  // Re-evaluate when auth state changes
  ref.watch(authStateChangesProvider);
  return ref.watch(authServiceProvider).currentUser;
}
