// Report issue URL and telemetry endpoint. Empty = disabled.
// Telemetry uses Supabase Edge Function when configured.
import 'supabase_config.dart';

/// GitHub username of the app developer (used for About me and donate link).
const String githubDeveloperUsername = 'Zyzto';

/// Public URL for reporting issues. Empty = feature disabled.
const String reportIssueUrl = 'https://github.com/Zyzto/Hisab/issues/new';

/// Donate / developer profile URL (GitHub).
String get githubDeveloperProfileUrl =>
    'https://github.com/$githubDeveloperUsername';

/// GitHub Sponsors / donate page for the developer.
String get githubDonateUrl =>
    'https://github.com/sponsors/$githubDeveloperUsername';

/// Telemetry endpoint URL. Uses Supabase Edge Function when configured,
/// otherwise empty (telemetry disabled).
String get telemetryEndpointUrl =>
    supabaseConfigAvailable ? '$supabaseUrl/functions/v1/telemetry' : '';
