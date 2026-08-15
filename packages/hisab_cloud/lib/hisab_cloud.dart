/// Offline stub backend.
///
/// This is the `hisab_cloud` the public repo builds against. It registers
/// nothing, so `cloudAvailable` stays false and Hisab runs entirely on the
/// local database with every online affordance hidden.
///
/// A real backend is a different package that happens to share this name. Point
/// `dependency_overrides` at yours to replace this one — see
/// `docs/SELF_HOSTING.md`.
library;

/// Entry point called once from `main()`, before `runApp`.
///
/// The offline stub deliberately does nothing. A real implementation
/// constructs its backend and hands it to `registerCloudBackend`.
Future<void> registerHisabCloud() async {}
