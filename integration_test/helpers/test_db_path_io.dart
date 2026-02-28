import 'dart:io';
import 'package:path/path.dart' as path;

/// Native implementation: use a temp directory for the DB file.
Future<String> integrationTestDbPathImpl() async {
  return path.join(
    Directory.systemTemp.path,
    'hisab_integration_${DateTime.now().millisecondsSinceEpoch}.db',
  );
}
