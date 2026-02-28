import 'test_db_path_stub.dart'
    if (dart.library.io) 'test_db_path_io.dart';

/// Returns a temporary DB path appropriate for the current platform.
/// On web, returns a simple name. On native, uses a temp directory.
Future<String> integrationTestDbPath() => integrationTestDbPathImpl();
