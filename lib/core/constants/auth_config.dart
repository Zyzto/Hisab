// Auth0 domain and client ID for online sync. When empty, Auth0 is not configured.
// Debug builds use dev values; release builds use prod values.
import 'package:flutter/foundation.dart';

import 'app_secrets.dart';
export 'app_secrets.dart' show auth0Scheme;

String get auth0Domain => kDebugMode ? auth0DomainDev : auth0DomainProd;
String get auth0ClientId => kDebugMode ? auth0ClientIdDev : auth0ClientIdProd;
