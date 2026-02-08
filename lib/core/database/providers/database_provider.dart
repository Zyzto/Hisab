import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../app_database.dart' as db;

part 'database_provider.g.dart';

db.AppDatabase? _databaseInstance;

db.AppDatabase getDatabase() {
  _databaseInstance ??= db.AppDatabase();
  return _databaseInstance!;
}

@riverpod
db.AppDatabase database(Ref ref) {
  return getDatabase();
}
