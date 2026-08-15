// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'auth_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(authService)
final authServiceProvider = AuthServiceProvider._();

final class AuthServiceProvider
    extends $FunctionalProvider<AuthService, AuthService, AuthService>
    with $Provider<AuthService> {
  AuthServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'authServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$authServiceHash();

  @$internal
  @override
  $ProviderElement<AuthService> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  AuthService create(Ref ref) {
    return authService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AuthService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AuthService>(value),
    );
  }
}

String _$authServiceHash() => r'21d842d4dceafa3d239c0196a0f2b890d37c0b71';

/// Emits a new value whenever auth state changes. We use [int] (not
/// [CloudAuthState]) so Riverpod never stores a backend's platform-backed
/// types, avoiding web-only dart_rti / NoSuchMethodError when the stream
/// updates.
///
/// Values must be unique per event: Riverpod skips rebuilds when
/// `AsyncData(n) == AsyncData(n)`, so a constant `0` would hide profile updates.

@ProviderFor(authStateChanges)
final authStateChangesProvider = AuthStateChangesProvider._();

/// Emits a new value whenever auth state changes. We use [int] (not
/// [CloudAuthState]) so Riverpod never stores a backend's platform-backed
/// types, avoiding web-only dart_rti / NoSuchMethodError when the stream
/// updates.
///
/// Values must be unique per event: Riverpod skips rebuilds when
/// `AsyncData(n) == AsyncData(n)`, so a constant `0` would hide profile updates.

final class AuthStateChangesProvider
    extends $FunctionalProvider<AsyncValue<int>, int, Stream<int>>
    with $FutureModifier<int>, $StreamProvider<int> {
  /// Emits a new value whenever auth state changes. We use [int] (not
  /// [CloudAuthState]) so Riverpod never stores a backend's platform-backed
  /// types, avoiding web-only dart_rti / NoSuchMethodError when the stream
  /// updates.
  ///
  /// Values must be unique per event: Riverpod skips rebuilds when
  /// `AsyncData(n) == AsyncData(n)`, so a constant `0` would hide profile updates.
  AuthStateChangesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'authStateChangesProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$authStateChangesHash();

  @$internal
  @override
  $StreamProviderElement<int> $createElement($ProviderPointer pointer) =>
      $StreamProviderElement(pointer);

  @override
  Stream<int> create(Ref ref) {
    return authStateChanges(ref);
  }
}

String _$authStateChangesHash() => r'727361f7e0ebb4194e2ae30f48202ccb02e53ec9';

@ProviderFor(isAuthenticated)
final isAuthenticatedProvider = IsAuthenticatedProvider._();

final class IsAuthenticatedProvider
    extends $FunctionalProvider<bool, bool, bool>
    with $Provider<bool> {
  IsAuthenticatedProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'isAuthenticatedProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$isAuthenticatedHash();

  @$internal
  @override
  $ProviderElement<bool> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  bool create(Ref ref) {
    return isAuthenticated(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }
}

String _$isAuthenticatedHash() => r'80b4be833bd4eb80266dc39ba5469c2184c989c7';

@ProviderFor(currentUser)
final currentUserProvider = CurrentUserProvider._();

final class CurrentUserProvider
    extends $FunctionalProvider<CloudUser?, CloudUser?, CloudUser?>
    with $Provider<CloudUser?> {
  CurrentUserProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'currentUserProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$currentUserHash();

  @$internal
  @override
  $ProviderElement<CloudUser?> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  CloudUser? create(Ref ref) {
    return currentUser(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(CloudUser? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<CloudUser?>(value),
    );
  }
}

String _$currentUserHash() => r'35e5c0e22d7922bff63de45caa56a46abd4c3231';
