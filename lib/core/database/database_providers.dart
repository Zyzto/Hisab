import 'package:powersync/powersync.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'database_providers.g.dart';

/// The local SQLite database. It is initialized in main.dart and overridden
/// in the root ProviderScope.
@Riverpod(keepAlive: true)
PowerSyncDatabase powerSyncDatabase(Ref ref) {
  throw UnimplementedError(
    'Override powerSyncDatabaseProvider in ProviderScope',
  );
}
