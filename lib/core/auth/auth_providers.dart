import 'dart:async';

import 'package:flutter_logging_service/flutter_logging_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:hisab_backend/hisab_backend.dart';

import 'auth_service.dart';

part 'auth_providers.g.dart';

@Riverpod(keepAlive: true)
AuthService authService(Ref ref) => AuthService();

/// Emits a new value whenever auth state changes. We use [int] (not
/// [CloudAuthState]) so Riverpod never stores a backend's platform-backed
/// types, avoiding web-only dart_rti / NoSuchMethodError when the stream
/// updates.
///
/// Values must be unique per event: Riverpod skips rebuilds when
/// `AsyncData(n) == AsyncData(n)`, so a constant `0` would hide profile updates.
@riverpod
Stream<int> authStateChanges(Ref ref) {
  if (!cloudAvailable) return const Stream.empty();
  var tick = 0;
  return ref
      .watch(authServiceProvider)
      .onAuthStateChange
      .map((_) => ++tick)
      .handleError((Object e, StackTrace st) {
        Log.warning('authStateChanges stream error', error: e, stackTrace: st);
      });
}

@riverpod
bool isAuthenticated(Ref ref) {
  if (!cloudAvailable) return false;
  ref.watch(authStateChangesProvider);
  return ref.watch(authServiceProvider).isAuthenticated;
}

@riverpod
CloudUser? currentUser(Ref ref) {
  if (!cloudAvailable) return null;
  ref.watch(authStateChangesProvider);
  return ref.watch(authServiceProvider).currentUser;
}
