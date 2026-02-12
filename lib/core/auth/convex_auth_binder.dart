import 'dart:async';

import 'package:convex_flutter/convex_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_logging_service/flutter_logging_service.dart';

import '../constants/convex_config.dart';
import 'auth_service.dart' as auth;
import '../../features/onboarding/providers/onboarding_providers.dart';
import '../../features/settings/providers/settings_framework_providers.dart';

/// Binds Convex auth to Auth0 when online mode is enabled and configured.
class ConvexAuthBinder extends ConsumerStatefulWidget {
  final Widget child;

  const ConvexAuthBinder({super.key, required this.child});

  @override
  ConsumerState<ConvexAuthBinder> createState() => _ConvexAuthBinderState();
}

class _ConvexAuthBinderState extends ConsumerState<ConvexAuthBinder> {
  dynamic _authHandle;
  bool _setupPending = false;

  @override
  void dispose() {
    _disposeAuth();
    super.dispose();
  }

  void _disposeAuth() {
    if (_authHandle != null) {
      try {
        _authHandle.dispose();
        Log.debug('Convex auth cleared');
      } catch (e) {
        Log.warning('Convex auth dispose failed', error: e);
      }
      _authHandle = null;
    }
  }

  Future<void> _setupAuth() async {
    if (convexDeploymentUrl.isEmpty) return;
    if (!auth.auth0ConfigAvailable) return;
    if (_authHandle != null || _setupPending) return;

    _setupPending = true;
    try {
      _authHandle = await ConvexClient.instance.setAuthWithRefresh(
        fetchToken: () async {
          final token = await auth.auth0GetAccessToken();
          if (token == null) {
            Log.warning('Auth token fetch failed', error: 'No token');
          }
          return token;
        },
        onAuthChange: (isAuthenticated) {
          Log.debug('Convex auth change: isAuthenticated=$isAuthenticated');
        },
      );
      Log.debug('Convex auth set');
    } catch (e, st) {
      Log.warning('Convex auth setup failed', error: e, stackTrace: st);
    } finally {
      _setupPending = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final localOnly = ref.watch(localOnlyProvider);
    final onlineAvailable = ref.watch(auth0ConfigAvailableProvider);

    ref.listen<bool>(localOnlyProvider, (previous, next) {
      if (next == true) {
        _disposeAuth();
        ConvexClient.instance.clearAuth();
      } else if (next == false && onlineAvailable) {
        _setupAuth();
      }
    });

    final shouldHaveAuth = !localOnly && onlineAvailable && convexDeploymentUrl.isNotEmpty;
    if (!shouldHaveAuth && _authHandle != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _disposeAuth();
        ConvexClient.instance.clearAuth();
      });
    } else if (shouldHaveAuth && _authHandle == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _setupAuth());
    }

    return widget.child;
  }
}
