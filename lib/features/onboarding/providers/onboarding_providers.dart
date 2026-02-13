import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../core/constants/supabase_config.dart';
part 'onboarding_providers.g.dart';

/// Whether online mode is available (Supabase configured via --dart-define).
@riverpod
bool supabaseConfigAvailableOnboarding(Ref ref) {
  return supabaseConfigAvailable;
}
