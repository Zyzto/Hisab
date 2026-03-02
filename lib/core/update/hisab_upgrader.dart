import 'package:upgrader/upgrader.dart';
import 'package:version/version.dart';

/// Upgrader that clears [versionInfo] when store version is same or older than
/// installed (e.g. Play internal/closed/open testing). Prevents the automatic
/// upgrade dialog from showing in that case.
class HisabUpgrader extends Upgrader {
  /// True when [updateVersionInfo] last cleared [versionInfo] because store
  /// version was same or older. Used by manual check to show "no update" toast.
  bool get lastCheckStoreNotNewer => _lastCheckStoreNotNewer;
  bool _lastCheckStoreNotNewer = false;

  HisabUpgrader({
    super.durationUntilAlertAgain,
    super.debugLogging,
    super.messages,
    super.willDisplayUpgrade,
    super.client,
    super.clientHeaders,
    super.countryCode,
    super.debugDisplayAlways,
    super.debugDisplayOnce,
    super.languageCode,
    super.minAppVersion,
    super.storeController,
    super.upgraderOS,
  });

  @override
  Future<UpgraderVersionInfo?> updateVersionInfo() async {
    _lastCheckStoreNotNewer = false;
    final versionInfo = await super.updateVersionInfo();
    final vi = state.versionInfo;
    final pkg = state.packageInfo;
    if (vi == null ||
        vi.appStoreVersion == null ||
        pkg == null ||
        pkg.version.isEmpty) {
      return versionInfo;
    }
    try {
      final installed = Version.parse(pkg.version);
      if (vi.appStoreVersion! <= installed) {
        _lastCheckStoreNotNewer = true;
        updateState(state.copyWithNull(versionInfo: true));
        return null;
      }
    } catch (_) {
      // Keep versionInfo on parse error; let package logic decide.
    }
    return versionInfo;
  }
}
