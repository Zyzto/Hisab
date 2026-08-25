/// A launchable Android app returned by the native scanner bridge.
class InstalledApp {
  final String packageName;
  final String label;

  const InstalledApp({required this.packageName, required this.label});
}
