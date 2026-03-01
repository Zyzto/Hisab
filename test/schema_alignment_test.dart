import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Validates that synced table columns are aligned between:
/// - [lib/core/database/powersync_schema.dart] (local schema; PowerSync adds `id` automatically)
/// - [lib/core/database/sync_engine.dart] (INSERT column lists; include `id` from Supabase)
///
/// Run as part of `flutter test`. Fails the build when schema and sync_engine drift.
/// See docs/CODEBASE.md "Schema alignment".
void main() {
  const syncedTables = [
    'groups',
    'group_members',
    'participants',
    'expenses',
    'expense_tags',
    'group_invites',
    'invite_usages',
  ];

  test('powersync_schema and sync_engine INSERT columns match for all synced tables', () {
    final schemaPath = _resolvePath('lib/core/database/powersync_schema.dart');
    final enginePath = _resolvePath('lib/core/database/sync_engine.dart');
    expect(File(schemaPath).existsSync(), isTrue, reason: 'schema file');
    expect(File(enginePath).existsSync(), isTrue, reason: 'sync_engine file');

    final schemaContent = File(schemaPath).readAsStringSync();
    final engineContent = File(enginePath).readAsStringSync();

    final schemaColumns = _parseSchemaColumns(schemaContent);
    final engineColumns = _parseInsertColumns(engineContent);

    final mismatches = <String>[];
    for (final table in syncedTables) {
      final schemaCols = schemaColumns[table];
      final insertCols = engineColumns[table];
      if (schemaCols == null) {
        mismatches.add('$table: missing in powersync_schema.dart');
        continue;
      }
      if (insertCols == null) {
        mismatches.add('$table: missing INSERT in sync_engine.dart');
        continue;
      }
      // Sync engine INSERT includes `id` (from Supabase); PowerSync adds id to table, schema omits it.
      final insertColsWithoutId = insertCols.first == 'id'
          ? insertCols.sublist(1)
          : insertCols;
      if (schemaCols.length != insertColsWithoutId.length ||
          !_listEquals(schemaCols, insertColsWithoutId)) {
        mismatches.add(
          '$table: schema [${schemaCols.join(', ')}] vs INSERT (minus id) [${insertColsWithoutId.join(', ')}]',
        );
      }
    }
    expect(
      mismatches,
      isEmpty,
      reason: 'Schema alignment failed. Keep powersync_schema.dart and sync_engine.dart INSERT lists in sync.\n${mismatches.join('\n')}',
    );
  });
}

String _resolvePath(String relative) {
  // Flutter test runs with cwd = project root.
  final cwd = Directory.current.path;
  return '$cwd/$relative';
}

/// Returns map of table name -> column names (order preserved). Only synced tables.
Map<String, List<String>> _parseSchemaColumns(String content) {
  final result = <String, List<String>>{};
  final tableRegex = RegExp(r"Table\('(\w+)',\s*\[");
  final columnRegex = RegExp(r"Column\.\w+\('(\w+)'\)");
  for (final tableMatch in tableRegex.allMatches(content)) {
    final tableName = tableMatch.group(1)!;
    final bracketStart = tableMatch.end - 1; // position of '['
    int depth = 1;
    int i = bracketStart + 1;
    while (depth > 0 && i < content.length) {
      final ch = content[i];
      if (ch == '[') depth++;
      if (ch == ']') depth--;
      i++;
    }
    final tableBlock = content.substring(bracketStart, i - 1);
    final columns = columnRegex
        .allMatches(tableBlock)
        .map((m) => m.group(1)!)
        .toList();
    if (tableName != 'local_archived_groups' && tableName != 'pending_writes') {
      result[tableName] = columns;
    }
  }
  return result;
}

/// Returns map of table name -> INSERT column list (order preserved).
Map<String, List<String>> _parseInsertColumns(String content) {
  final result = <String, List<String>>{};
  // INSERT INTO table (col1, col2, ...) VALUES - column list can span lines
  final insertRegex = RegExp(
    r"INSERT\s+INTO\s+(\w+)\s*\(\s*([^)]+)\s*\)\s+VALUES",
    caseSensitive: false,
    multiLine: true,
    dotAll: true,
  );
  for (final match in insertRegex.allMatches(content)) {
    final tableName = match.group(1)!;
    final colList = match.group(2)!
        .replaceAll(RegExp(r'\s+'), ' ')
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    result[tableName] = colList;
  }
  return result;
}

bool _listEquals<T>(List<T> a, List<T> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
