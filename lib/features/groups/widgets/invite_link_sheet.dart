import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_logging_service/flutter_logging_service.dart';
import 'package:pretty_qr_code/pretty_qr_code.dart';
import '../../../core/constants/supabase_config.dart';
import '../../../core/repository/repository_providers.dart';
import '../../../core/widgets/toast.dart';
import '../../../core/telemetry/telemetry_service.dart';
import '../../settings/providers/settings_framework_providers.dart';
import '../utils/invite_share_helper.dart';

/// Creates an invite and shows a bottom sheet with the share link and QR code.
/// Call from group detail or settings when user is owner/admin and online.
Future<void> createAndShowInviteSheet(
  BuildContext context,
  WidgetRef ref,
  String groupId,
) async {
  try {
    final result = await ref
        .read(groupInviteRepositoryProvider)
        .createInvite(groupId);
    TelemetryService.sendEvent('invite_created', {
      'groupId': groupId,
    }, enabled: ref.read(telemetryEnabledProvider));
    if (!context.mounted) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => InviteLinkDisplay(token: result.token),
    );
  } catch (e, st) {
    Log.warning('Create invite failed', error: e, stackTrace: st);
    if (context.mounted) {
      context.showError('$e');
    }
  }
}

/// Bottom sheet content showing invite link and QR code.
class InviteLinkDisplay extends StatefulWidget {
  final String token;

  const InviteLinkDisplay({super.key, required this.token});

  @override
  State<InviteLinkDisplay> createState() => _InviteLinkDisplayState();
}

class _InviteLinkDisplayState extends State<InviteLinkDisplay> {
  final GlobalKey _qrKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    // Use custom domain or Supabase project URL for invite links (redirects via Edge Function)
    final base = inviteLinkBaseUrl.endsWith('/')
        ? inviteLinkBaseUrl.substring(0, inviteLinkBaseUrl.length - 1)
        : inviteLinkBaseUrl;
    final url = supabaseConfigAvailable
        ? '$base/functions/v1/invite-redirect?token=${widget.token}'
        : '';
    // QR codes scan best with dark on light; use white bg + black modules
    return DraggableScrollableSheet(
      initialChildSize: 0.95,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, _) => LayoutBuilder(
        builder: (context, constraints) {
          if (url.isEmpty) {
            return Padding(
              padding: EdgeInsets.only(
                left: 24,
                right: 24,
                top: 24,
                bottom: 24 + MediaQuery.of(context).padding.bottom,
              ),
              child: Center(
                child: Text(
                  'invite_requires_online'.tr(),
                  style: Theme.of(context).textTheme.bodyLarge,
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          final availableHeight =
              constraints.maxHeight - 24 * 2 - 20 - 60 - 16 - 56;
          final availableWidth = constraints.maxWidth - 24 * 2 - 16 * 2;
          final fitQrSize =
              (availableWidth < availableHeight
                      ? availableWidth
                      : availableHeight)
                  .clamp(0.0, double.infinity);
          return Padding(
            padding: EdgeInsets.only(
              left: 24,
              right: 24,
              top: 24,
              bottom: 24 + MediaQuery.of(context).padding.bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                RepaintBoundary(
                  key: _qrKey,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: SizedBox(
                      width: fitQrSize,
                      height: fitQrSize,
                      child: PrettyQrView.data(
                        data: url,
                        errorCorrectLevel: QrErrorCorrectLevel.M,
                        decoration: const PrettyQrDecoration(
                          shape: PrettyQrSmoothSymbol(color: Colors.black),
                          background: Colors.white,
                          quietZone: PrettyQrQuietZone.zero,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  url,
                  style: Theme.of(context).textTheme.bodySmall,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    FilledButton.tonalIcon(
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: url));
                        context.showSuccess('invite_link_copied'.tr());
                      },
                      icon: const Icon(Icons.copy),
                      label: Text('copy_link'.tr()),
                    ),
                    const SizedBox(width: 12),
                    FilledButton.tonalIcon(
                      onPressed: () => _share(context, url),
                      icon: const Icon(Icons.share),
                      label: Text('share'.tr()),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _share(BuildContext context, String url) async {
    final boundary = _qrKey.currentContext?.findRenderObject()
        as RenderRepaintBoundary?;
    try {
      await shareInviteLink(
        url: url,
        shareMessage: 'share_invite_message'.tr(),
        boundary: boundary,
      );
      if (!context.mounted) return;
      context.showSuccess('invite_shared'.tr());
    } catch (_) {
      await Clipboard.setData(ClipboardData(text: url));
      if (!context.mounted) return;
      context.showSuccess('invite_link_copied'.tr());
    }
  }
}
