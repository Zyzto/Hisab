import 'package:flutter/material.dart';

import '../../../core/utils/run_guarded_async.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pretty_qr_code/pretty_qr_code.dart';
import '../../../core/constants/supabase_config.dart';
import '../../../core/layout/layout_breakpoints.dart';
import '../../../core/layout/responsive_sheet.dart';
import '../../../core/repository/repository_providers.dart';
import '../../../core/telemetry/telemetry_service.dart';
import '../../../core/theme/theme_config.dart';
import '../../../core/widgets/toast.dart';
import '../../settings/providers/settings_framework_providers.dart';
import '../utils/invite_share_helper.dart';

/// Expiry option for invite creation.
class _ExpiryOption {
  final String labelKey;
  final Duration? duration; // null = never
  const _ExpiryOption(this.labelKey, this.duration);
}

const _expiryOptions = [
  _ExpiryOption('invite_expiry_1h', Duration(hours: 1)),
  _ExpiryOption('invite_expiry_1d', Duration(days: 1)),
  _ExpiryOption('invite_expiry_7d', Duration(days: 7)),
  _ExpiryOption('invite_expiry_30d', Duration(days: 30)),
  _ExpiryOption('invite_expiry_never', null),
];

/// Max uses option for invite creation.
class _MaxUsesOption {
  final String label;
  final int? value; // null = unlimited
  const _MaxUsesOption(this.label, this.value);
}

const _maxUsesOptions = [
  _MaxUsesOption('1', 1),
  _MaxUsesOption('5', 5),
  _MaxUsesOption('10', 10),
  _MaxUsesOption('25', 25),
  _MaxUsesOption('50', 50),
  _MaxUsesOption('∞', null),
];

/// Shows a bottom sheet to create an invite with advanced options.
/// Returns the created token if successful, or null.
Future<String?> showCreateInviteSheet(
  BuildContext context,
  WidgetRef ref,
  String groupId,
) async {
  return showResponsiveSheet<String>(
    context: context,
    title: 'create_invite'.tr(),
    isScrollControlled: true,
    useSafeArea: true,
    centerInFullViewport: true,
    child: _CreateInviteSheet(groupId: groupId),
  );
}

class _CreateInviteSheet extends ConsumerStatefulWidget {
  final String groupId;
  const _CreateInviteSheet({required this.groupId});

  @override
  ConsumerState<_CreateInviteSheet> createState() => _CreateInviteSheetState();
}

class _CreateInviteSheetState extends ConsumerState<_CreateInviteSheet> {
  final _labelController = TextEditingController();
  String _role = 'member';
  int _expiryIndex = 2; // default: 7 days
  int _maxUsesIndex = 5; // default: unlimited
  bool _creating = false;
  String? _createdToken;

  @override
  void dispose() {
    _labelController.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    setState(() => _creating = true);
    final expiry = _expiryOptions[_expiryIndex];
    final maxUses = _maxUsesOptions[_maxUsesIndex];
    final result = await runGuardedAsync<({String id, String token})>(
      ref.read(groupInviteRepositoryProvider).createInvite(
            widget.groupId,
            role: _role,
            label: _labelController.text.trim().isEmpty
                ? null
                : _labelController.text.trim(),
            maxUses: maxUses.value,
            expiresIn: expiry.duration,
          ),
      'Create invite failed',
      context: context,
      errorToastMessage: 'generic_error'.tr(),
    );
    if (result == null) {
      setState(() => _creating = false);
      return;
    }
    TelemetryService.sendEvent(
      'invite_created',
      {'groupId': widget.groupId},
      enabled: ref.read(telemetryEnabledProvider),
    );
    setState(() {
      _createdToken = result.token;
      _creating = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_createdToken != null) {
      return _InviteResultView(token: _createdToken!);
    }

    return Padding(
      padding: EdgeInsets.only(
        left: ThemeConfig.spacingL,
        right: ThemeConfig.spacingL,
        top: ThemeConfig.spacingL,
        bottom: MediaQuery.of(context).padding.bottom +
            MediaQuery.of(context).viewInsets.bottom +
            ThemeConfig.spacingL,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
          if (!LayoutBreakpoints.isTabletOrWider(context)) ...[
            Text(
              'create_invite'.tr(),
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: ThemeConfig.spacingM),
          ],

          // Label
          TextField(
            controller: _labelController,
            decoration: InputDecoration(
              labelText: 'invite_label'.tr(),
              hintText: 'invite_label_hint'.tr(),
              prefixIcon: const Icon(Icons.label_outline),
              border: const OutlineInputBorder(),
            ),
            textCapitalization: TextCapitalization.sentences,
          ),
          const SizedBox(height: ThemeConfig.spacingM),

          // Role
          Text('invite_role'.tr(), style: theme.textTheme.titleSmall),
          const SizedBox(height: ThemeConfig.spacingS),
          SegmentedButton<String>(
            segments: [
              ButtonSegment(
                value: 'member',
                label: Text('group_member'.tr()),
                icon: const Icon(Icons.person_outline, size: 18),
              ),
              ButtonSegment(
                value: 'admin',
                label: Text('group_admin'.tr()),
                icon: const Icon(Icons.admin_panel_settings_outlined, size: 18),
              ),
            ],
            selected: {_role},
            onSelectionChanged: (v) => setState(() => _role = v.first),
          ),
          const SizedBox(height: ThemeConfig.spacingM),

          // Expiry
          Text('invite_expiry'.tr(), style: theme.textTheme.titleSmall),
          const SizedBox(height: ThemeConfig.spacingS),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: List.generate(_expiryOptions.length, (i) {
              final opt = _expiryOptions[i];
              return ChoiceChip(
                label: Text(opt.labelKey.tr()),
                selected: _expiryIndex == i,
                onSelected: (_) => setState(() => _expiryIndex = i),
              );
            }),
          ),
          const SizedBox(height: ThemeConfig.spacingM),

          // Max uses
          Text('invite_max_uses'.tr(), style: theme.textTheme.titleSmall),
          const SizedBox(height: ThemeConfig.spacingS),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: List.generate(_maxUsesOptions.length, (i) {
              final opt = _maxUsesOptions[i];
              return ChoiceChip(
                label: Text(opt.value?.toString() ?? 'invite_unlimited'.tr()),
                selected: _maxUsesIndex == i,
                onSelected: (_) => setState(() => _maxUsesIndex = i),
              );
            }),
          ),
          const SizedBox(height: ThemeConfig.spacingL),

          // Create button
          FilledButton.icon(
            onPressed: _creating ? null : _create,
            icon: _creating
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.add_link),
            label: Text('create_invite'.tr()),
          ),
          const SizedBox(height: ThemeConfig.spacingS),
        ],
        ),
      ),
    );
  }
}

/// Shows the QR code and copy link after successful creation.
class _InviteResultView extends StatefulWidget {
  final String token;
  const _InviteResultView({required this.token});

  @override
  State<_InviteResultView> createState() => _InviteResultViewState();
}

class _InviteResultViewState extends State<_InviteResultView> {
  final GlobalKey _qrKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final base = inviteLinkBaseUrl.endsWith('/')
        ? inviteLinkBaseUrl.substring(0, inviteLinkBaseUrl.length - 1)
        : inviteLinkBaseUrl;
    final url = supabaseConfigAvailable
        ? '$base/functions/v1/invite-redirect?token=${widget.token}'
        : '';

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
            style: theme.textTheme.bodyLarge,
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

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
          Icon(
            Icons.check_circle_outline,
            color: theme.colorScheme.primary,
            size: 48,
          ),
          const SizedBox(height: 8),
          Text(
            'invite_created_success'.tr(),
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 20),
          LayoutBuilder(
            builder: (context, constraints) {
              final colorScheme = Theme.of(context).colorScheme;
              final qrSize = (constraints.maxWidth - 64).clamp(0.0, 250.0);
              return RepaintBoundary(
                key: _qrKey,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: colorScheme.surface,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: SizedBox(
                    width: qrSize,
                    height: qrSize,
                    child: PrettyQrView.data(
                      data: url,
                      errorCorrectLevel: QrErrorCorrectLevel.M,
                      decoration: PrettyQrDecoration(
                        shape: PrettyQrSmoothSymbol(color: colorScheme.onSurface),
                        background: colorScheme.surface,
                        quietZone: PrettyQrQuietZone.zero,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          Text(
            url,
            style: theme.textTheme.bodySmall,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 12,
            runSpacing: 8,
            children: [
              FilledButton.tonalIcon(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: url));
                  context.showSuccess('invite_link_copied'.tr());
                },
                icon: const Icon(Icons.copy),
                label: Text('copy_link'.tr()),
              ),
              FilledButton.tonalIcon(
                onPressed: () => _share(context, url),
                icon: const Icon(Icons.share),
                label: Text('share'.tr()),
              ),
              OutlinedButton(
                onPressed: () => Navigator.of(context).pop(widget.token),
                child: Text('done'.tr()),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _share(BuildContext context, String url) async {
    final boundary =
        _qrKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    await shareInviteLinkWithFallback(
      context,
      url: url,
      shareMessage: 'share_invite_message'.tr(),
      boundary: boundary,
    );
  }
}
