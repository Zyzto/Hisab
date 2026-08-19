import 'package:flutter/material.dart';

/// Same corner ribbon as Flutter's debug banner, labelled TEST.
///
/// Shown on staging web and the staging APK so a tester never confuses the
/// host with production. [debugShowCheckedModeBanner] stays off so local
/// debug builds keep the DEBUG icon without a second ribbon.
Widget wrapWithStagingBanner({
  required Widget child,
  required bool enabled,
}) {
  if (!enabled) return child;
  return Banner(
    message: 'TEST',
    textDirection: TextDirection.ltr,
    location: BannerLocation.topEnd,
    child: child,
  );
}
