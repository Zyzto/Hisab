import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';

/// Show/hide affordance for a password field, meant for [InputDecoration.suffixIcon].
///
/// Built on [InkWell] with `canRequestFocus: false` on purpose: a focusable
/// button here is picked up by the focus manager and pulls focus out of the
/// password field while the user is still typing.
class ObscureTextToggle extends StatelessWidget {
  const ObscureTextToggle({
    super.key,
    required this.obscure,
    required this.onTap,
  });

  /// Whether the field is currently hiding its text.
  final bool obscure;

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: obscure ? 'auth_show_password'.tr() : 'auth_hide_password'.tr(),
      child: Material(
        type: MaterialType.button,
        color: Colors.transparent,
        child: InkWell(
          canRequestFocus: false,
          onTap: onTap,
          borderRadius: BorderRadius.circular(48),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Icon(
              obscure ? Icons.visibility_off : Icons.visibility,
              size: 24,
            ),
          ),
        ),
      ),
    );
  }
}
