import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../core/layout/content_aligned_app_bar.dart';
import '../../../core/layout/constrained_content.dart';
import '../../../core/navigation/invite_link_handler.dart';
import '../../../core/navigation/route_paths.dart';
import '../../../core/services/permission_service.dart';

/// Full-screen QR scanner to join a group via an invite QR code.
/// Requests camera permission, then shows [MobileScanner]. On a valid
/// invite URL/token, stops the camera, then pops and navigates to the invite accept page.
class InviteScanPage extends StatefulWidget {
  const InviteScanPage({super.key});

  @override
  State<InviteScanPage> createState() => _InviteScanPageState();
}

class _InviteScanPageState extends State<InviteScanPage> {
  bool _permissionGranted = false;
  bool _permissionChecked = false;
  bool _handled = false;
  final MobileScannerController _controller = MobileScannerController();

  @override
  void initState() {
    super.initState();
    _requestPermission();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _requestPermission() async {
    if (kIsWeb) {
      setState(() {
        _permissionChecked = true;
        _permissionGranted = true;
      });
      return;
    }
    final granted = await PermissionService.requestCameraPermission(context);
    if (mounted) {
      setState(() {
        _permissionChecked = true;
        _permissionGranted = granted;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_permissionChecked) {
      return LayoutBuilder(
        builder: (context, layoutConstraints) {
          return Scaffold(
            appBar: ContentAlignedAppBar(
              contentAreaWidth: layoutConstraints.maxWidth,
              title: Text('scan_invite_title'.tr()),
            ),
            body: const Center(child: CircularProgressIndicator()),
          );
        },
      );
    }

    if (!_permissionGranted) {
      return LayoutBuilder(
        builder: (context, layoutConstraints) {
          return Scaffold(
            appBar: ContentAlignedAppBar(
              contentAreaWidth: layoutConstraints.maxWidth,
              title: Text('scan_invite_title'.tr()),
              leading: IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
            body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'permission_camera_message'.tr(),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ),
        ),
          );
        },
      );
    }

    return LayoutBuilder(
      builder: (context, layoutConstraints) {
        return Scaffold(
          appBar: ContentAlignedAppBar(
            contentAreaWidth: layoutConstraints.maxWidth,
            title: Text('scan_invite_title'.tr()),
            leading: IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
          body: ConstrainedContent(
        child: Stack(
          fit: StackFit.expand,
          children: [
            MobileScanner(
              controller: _controller,
              onDetect: (capture) async {
                if (_handled) return;
                final barcodes = capture.barcodes;
                for (final barcode in barcodes) {
                  final raw = barcode.rawValue;
                  if (raw == null || raw.isEmpty) continue;
                  final uri = Uri.tryParse(raw);
                  final token = extractInviteTokenFromUri(uri);
                  if (token != null && mounted) {
                    _handled = true;
                    await _controller.stop();
                    if (!context.mounted) return;
                    Navigator.of(context).pop();
                    context.go(RoutePaths.inviteAccept(token));
                    return;
                  }
                }
              },
              errorBuilder: (context, error, child) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 64,
                      color: Theme.of(context).colorScheme.error,
                    ),
                    const SizedBox(height: 16),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Text(
                        error.errorDetails?.message ?? '${error.errorCode}',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              left: 24,
              right: 24,
              bottom: 32,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.surface.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'scan_invite_hint'.tr(),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ),
          ],
        ),
      ),
        );
      },
    );
  }
}
