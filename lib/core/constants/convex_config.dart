// Convex deployment URL for cloud sync. When empty, Local Only mode is required.
// Debug builds use dev; release builds use prod.
import 'package:flutter/foundation.dart';

import 'app_secrets.dart';

String get convexDeploymentUrl =>
    kDebugMode ? convexDeploymentUrlDev : convexDeploymentUrlProd;
