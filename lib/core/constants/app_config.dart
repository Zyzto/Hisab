import 'package:hisab_backend/hisab_backend.dart';

/// GitHub username of the app developer (used for About me and donate link).
const String githubDeveloperUsername = 'Zyzto';

/// Public URL for reporting issues. Empty = feature disabled.
const String reportIssueUrl = 'https://github.com/Zyzto/Hisab/issues/new';

/// Corresponding source for this app, offered to users of the hosted build as
/// AGPL-3.0 section 13 requires.
const String sourceCodeUrl = 'https://github.com/Zyzto/Hisab';

/// Donate / developer profile URL (GitHub).
String get githubDeveloperProfileUrl =>
    'https://github.com/$githubDeveloperUsername';

/// GitHub Sponsors / donate page for the developer.
String get githubDonateUrl =>
    'https://github.com/sponsors/$githubDeveloperUsername';

/// Whether diagnostics can be sent. False in an offline build and whenever the
/// backend declines telemetry.
bool get telemetryAvailable => cloudBackend?.telemetry.isEnabled ?? false;
