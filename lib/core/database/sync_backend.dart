import 'package:hisab_backend/hisab_backend.dart';

/// Row transport used by [SyncEngine].
///
/// This is the backend contract's `CloudSync` under the name the sync code has
/// always used. Tests substitute their own implementation; a cloud build gets
/// the registered backend's.
typedef SyncBackend = CloudSync;
