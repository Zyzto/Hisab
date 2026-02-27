import 'dart:async';

import 'package:flutter_logging_service/flutter_logging_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../constants/supabase_config.dart';
import 'auth_service.dart';

part 'auth_providers.g.dart';

@Riverpod(keepAlive: true)
AuthService authService(Ref ref) => AuthService();

/// Emits a new value whenever auth state changes. We use [int] (not [AuthState])
/// so Riverpod never stores Supabase's JS-backed types, avoiding web-only
/// dart_rti / NoSuchMethodError when the stream updates.
@riverpod
Stream<int> authStateChanges(Ref ref) {
  if (!supabaseConfigAvailable) return const Stream.empty();
  return ref
      .watch(authServiceProvider)
      .onAuthStateChange
      .map((_) => 0)
      .handleError((Object e, StackTrace st) {
        Log.warning('authStateChanges stream error', error: e, stackTrace: st);
      });
}

@riverpod
bool isAuthenticated(Ref ref) {
  if (!supabaseConfigAvailable) return false;
  ref.watch(authStateChangesProvider);
  return ref.watch(authServiceProvider).isAuthenticated;
}

@riverpod
User? currentUser(Ref ref) {
  if (!supabaseConfigAvailable) return null;
  ref.watch(authStateChangesProvider);
  return ref.watch(authServiceProvider).currentUser;
}
