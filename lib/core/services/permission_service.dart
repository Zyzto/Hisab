import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

/// Permissions used by local-only features.
///
/// The public build requests only camera/photos access for local receipt
/// capture. It has no network permission flow.
class PermissionService {
  PermissionService._();

  static Future<bool> requestCameraPermission(BuildContext context) {
    return _request(context, Permission.camera);
  }

  static Future<bool> requestPhotosPermission(BuildContext context) {
    return _request(context, Permission.photos);
  }

  static Future<bool> isCameraPermissionGranted() async {
    if (kIsWeb) return true;
    final status = await Permission.camera.status;
    return status.isGranted || status.isLimited;
  }

  static Future<bool> _request(
    BuildContext context,
    Permission permission,
  ) async {
    if (kIsWeb) return true;
    var status = await permission.status;
    if (status.isGranted || status.isLimited) return true;
    if (status.isDenied) {
      status = await permission.request();
      if (status.isGranted || status.isLimited) return true;
    }
    if (status.isPermanentlyDenied && context.mounted) {
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Permission needed'),
          content: const Text(
            'Allow camera or photo access in system settings to use local receipt capture.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await openAppSettings();
              },
              child: const Text('Open settings'),
            ),
          ],
        ),
      );
    }
    return false;
  }
}
