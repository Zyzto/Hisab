import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_logging_service/flutter_logging_service.dart';
import 'package:pretty_qr_code/pretty_qr_code.dart';
import '../../../core/constants/supabase_config.dart';
import '../../../core/repository/repository_providers.dart';
import '../../../core/telemetry/telemetry_service.dart';
import '../../settings/providers/settings_framework_providers.dart';

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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }
}

/// Bottom sheet content showing invite link and QR code.
class InviteLinkDisplay extends StatelessWidget {
  final String token;

  const InviteLinkDisplay({super.key, required this.token});

  @override
  Widget build(BuildContext context) {
    // Use custom domain or Supabase project URL for invite links (redirects via Edge Function)
    final base = inviteLinkBaseUrl.endsWith('/')
        ? inviteLinkBaseUrl.substring(0, inviteLinkBaseUrl.length - 1)
        : inviteLinkBaseUrl;
    final url = supabaseConfigAvailable
        ? '$base/functions/v1/invite-redirect?token=$token'
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
              padding: const EdgeInsets.all(24),
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
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
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
                const SizedBox(height: 20),
                Text(
                  url,
                  style: Theme.of(context).textTheme.bodySmall,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                FilledButton.tonalIcon(
                  onPressed: () => Clipboard.setData(ClipboardData(text: url)),
                  icon: const Icon(Icons.copy),
                  label: Text('copy_link'.tr()),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
