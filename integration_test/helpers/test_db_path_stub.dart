/// Web implementation: PowerSync on web uses an in-browser name, no file path.
Future<String> integrationTestDbPathImpl() async {
  return 'hisab_integration_${DateTime.now().millisecondsSinceEpoch}.db';
}
