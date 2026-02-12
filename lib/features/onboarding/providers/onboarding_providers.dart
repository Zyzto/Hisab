import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:flutter_logging_service/flutter_logging_service.dart';
import '../../../core/constants/auth_config.dart';
import '../../../core/constants/convex_config.dart';
part 'onboarding_providers.g.dart';

/// When true, online mode is available (Auth0 and Convex both configured).
@riverpod
bool auth0ConfigAvailable(Ref ref) {
  final hasAuth0 =
      auth0Domain.isNotEmpty && auth0ClientId.isNotEmpty;
  final hasConvex = convexDeploymentUrl.isNotEmpty;
  final available = hasAuth0 && hasConvex;
  if (!available) {
    Log.debug('Auth0 config not available, online mode disabled');
  }
  return available;
}
