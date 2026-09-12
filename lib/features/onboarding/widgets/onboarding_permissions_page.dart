import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';

import 'onboarding_shared.dart';

/// Final onboarding step for the local-only application.
///
class OnboardingPermissionsPage extends StatelessWidget {
  const OnboardingPermissionsPage({
    super.key,
    required this.cameraGranted,
    required this.permissionStatusFuture,
    required this.onRequestCamera,
  });

  final bool? cameraGranted;
  final Future<bool>? permissionStatusFuture;
  final Future<void> Function() onRequestCamera;

  @override
  Widget build(BuildContext context) {
    return onboardingPageBodyWithFixedTitle(
      context,
      contentAlignment: Alignment.topCenter,
      title: OnboardingStepEnter(
        slidePx: 12,
        child: OnboardingTitleBlock(
          title: 'onboarding_permissions_title'.tr(),
          subtitle: Text('onboarding_permissions_desc'.tr()),
        ),
      ),
      content: OnboardingStepEnter(
        child: FutureBuilder<bool>(
          future: permissionStatusFuture,
          builder: (context, snapshot) {
            final granted =
                cameraGranted ?? snapshot.data ?? (kIsWeb ? true : false);
            if (kIsWeb) return const SizedBox.shrink();
            return _PermissionRow(granted: granted, onAllow: onRequestCamera);
          },
        ),
      ),
    );
  }
}

class _PermissionRow extends StatelessWidget {
  const _PermissionRow({required this.granted, required this.onAllow});

  final bool granted;
  final Future<void> Function() onAllow;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return OnboardingListCard(
      leading: const OnboardingListCardIcon(icon: Icons.camera_alt_outlined),
      title: 'onboarding_permission_camera'.tr(),
      subtitle: Text(
        'onboarding_permission_camera_desc'.tr(),
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: colors.onSurfaceVariant,
          height: 1.3,
        ),
      ),
      trailing: granted
          ? FilledButton.tonalIcon(
              onPressed: null,
              icon: const Icon(Icons.check_circle, size: 18),
              label: Text('onboarding_permission_allowed'.tr()),
            )
          : FilledButton.tonal(
              onPressed: onAllow,
              child: Text('onboarding_permission_allow'.tr()),
            ),
    );
  }
}
