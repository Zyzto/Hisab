import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_logging_service/flutter_logging_service.dart';

QueryExecutor openConnection() {
  Log.info('Opening database connection with drift_flutter');
  return driftDatabase(
    name: 'hisab',
    web: kIsWeb
        ? DriftWebOptions(
            // Required files in web/: sqlite3.wasm, drift_worker.dart.js (see web/README_DRIFT_WEB.md)
            sqlite3Wasm: Uri.parse('sqlite3.wasm'),
            driftWorker: Uri.parse('drift_worker.dart.js'),
          )
        : null,
  );
}
