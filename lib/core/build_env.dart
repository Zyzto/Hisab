/// Build-time environment, supplied through `--dart-define=HISAB_ENV=...`.
///
/// Staging CI sets `staging`. Production and the public offline build leave it
/// empty. The value is used for environment-specific branding and to keep the
/// test host out of search indexes.
library;

const String hisabEnv = String.fromEnvironment('HISAB_ENV', defaultValue: '');
const bool isStagingBuild = hisabEnv == 'staging';

/// Translation key for the user-facing application name.
///
/// The test name is deliberately selected at compile time so a production
/// build cannot accidentally inherit staging branding at runtime.
const String appNameTranslationKey = isStagingBuild
    ? 'test_app_name'
    : 'app_name';
