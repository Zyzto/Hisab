import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:hisab_backend/hisab_backend.dart';
part 'onboarding_providers.g.dart';

/// Whether this build has a cloud backend, and so can offer online mode.
@riverpod
bool cloudAvailableOnboarding(Ref ref) {
  return cloudAvailable;
}
