import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:hisab_backend/hisab_backend.dart';

import '../../../widgets/brand_logo.dart';
import 'auth_buttons.dart';

/// The Google and GitHub sign-in buttons, side by side above the email form.
class OAuthButtonRow extends StatelessWidget {
  const OAuthButtonRow({
    super.key,
    required this.enabled,
    required this.onProviderSelected,
  });

  final bool enabled;
  final ValueChanged<CloudOAuthProvider> onProviderSelected;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _ProviderButton(
            logo: const BrandLogo.google(),
            label: 'auth_provider_google'.tr(),
            onPressed: enabled
                ? () => onProviderSelected(CloudOAuthProvider.google)
                : null,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _ProviderButton(
            logo: const BrandLogo.github(),
            label: 'auth_provider_github'.tr(),
            onPressed: enabled
                ? () => onProviderSelected(CloudOAuthProvider.github)
                : null,
          ),
        ),
      ],
    );
  }
}

class _ProviderButton extends StatelessWidget {
  const _ProviderButton({
    required this.logo,
    required this.label,
    required this.onPressed,
  });

  final Widget logo;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return NonFocusable(
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          // Taller and rounder than stock: these are the first thing most
          // people reach for, and the app's own panels use a 14px radius.
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Dimmed rather than hidden while disabled, so the row keeps its
            // shape during an in-flight request.
            Opacity(opacity: onPressed == null ? 0.4 : 1, child: logo),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
