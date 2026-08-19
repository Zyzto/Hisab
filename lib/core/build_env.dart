/// Build-time environment, supplied through `--dart-define=HISAB_ENV=...`.
///
/// Staging CI sets `staging`. Production and the public offline build leave it
/// empty. Used to mark the test site as non-indexable and to show the TEST
/// corner banner.
library;

const String hisabEnv = String.fromEnvironment('HISAB_ENV', defaultValue: '');

bool get isStagingBuild => hisabEnv.toLowerCase() == 'staging';
