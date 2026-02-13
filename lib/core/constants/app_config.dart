// Report issue URL and telemetry endpoint. Empty = disabled.
// Telemetry uses Supabase Edge Function when configured.
import 'supabase_config.dart';

export 'app_secrets.dart' show reportIssueUrl;

/// Telemetry endpoint URL. Uses Supabase Edge Function when configured,
/// otherwise empty (telemetry disabled).
String get telemetryEndpointUrl =>
    supabaseConfigAvailable ? '$supabaseUrl/functions/v1/telemetry' : '';
