// Report issue URL and telemetry endpoint. Empty = disabled.
// Telemetry uses Supabase Edge Function when configured.
import 'supabase_config.dart';

/// Public URL for reporting issues. Empty = feature disabled.
const String reportIssueUrl = 'https://github.com/Zyzto/Hisab/issues/new';

/// Telemetry endpoint URL. Uses Supabase Edge Function when configured,
/// otherwise empty (telemetry disabled).
String get telemetryEndpointUrl =>
    supabaseConfigAvailable ? '$supabaseUrl/functions/v1/telemetry' : '';
