// Report issue URL and telemetry endpoint. Empty = disabled.
// Debug builds use dev telemetry URL; release uses prod.
import 'package:flutter/foundation.dart';

import 'app_secrets.dart';

export 'app_secrets.dart' show reportIssueUrl;
String get telemetryEndpointUrl =>
    kDebugMode ? telemetryEndpointUrlDev : telemetryEndpointUrlProd;
