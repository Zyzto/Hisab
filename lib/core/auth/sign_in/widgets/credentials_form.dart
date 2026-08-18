import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../utils/form_validators.dart';
import '../../../widgets/obscure_text_toggle.dart';
import 'auth_buttons.dart';

/// Email and password inputs, validated inline as the user types.
///
/// The [Form] itself is owned by the sheet so it can validate the pair before
/// submitting; [emailFieldKey] additionally lets the sheet validate the address
/// on its own for the magic-link and password-reset actions, which do not care
/// about the password.
class CredentialsForm extends StatelessWidget {
  const CredentialsForm({
    super.key,
    required this.formKey,
    required this.emailFieldKey,
    required this.emailController,
    required this.passwordController,
    required this.obscurePassword,
    required this.onToggleObscure,
    required this.isSignUp,
    required this.enabled,
    required this.onSubmit,
    this.onForgotPassword,
  });

  final GlobalKey<FormState> formKey;
  final GlobalKey<FormFieldState<String>> emailFieldKey;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final bool obscurePassword;
  final VoidCallback onToggleObscure;

  /// Drives the password field's autofill hint and helper text: a password
  /// manager should offer to *generate* here, not to fill.
  final bool isSignUp;

  final bool enabled;
  final VoidCallback onSubmit;

  /// Null in sign-up mode, where there is no password to recover yet.
  final VoidCallback? onForgotPassword;

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            key: emailFieldKey,
            controller: emailController,
            validator: FormValidators.email,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            decoration: InputDecoration(
              labelText: 'auth_email'.tr(),
              border: const OutlineInputBorder(),
            ),
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.email],
            // Keyboards that autocorrect or capitalise turn a typed address
            // into one that fails validation for no visible reason.
            autocorrect: false,
            enableSuggestions: false,
            textCapitalization: TextCapitalization.none,
            enabled: enabled,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: passwordController,
            validator: FormValidators.password,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            decoration: InputDecoration(
              labelText: 'auth_password'.tr(),
              border: const OutlineInputBorder(),
              // State the rule up front when creating a password, rather than
              // failing the user for not guessing it.
              helperText: isSignUp
                  ? 'auth_password_hint'.tr(
                      namedArgs: {'min': '${FormValidators.passwordMin}'},
                    )
                  : null,
              suffixIcon: ObscureTextToggle(
                obscure: obscurePassword,
                onTap: onToggleObscure,
              ),
            ),
            obscureText: obscurePassword,
            textInputAction: TextInputAction.done,
            autofillHints: [
              isSignUp ? AutofillHints.newPassword : AutofillHints.password,
            ],
            enabled: enabled,
            onFieldSubmitted: (_) => onSubmit(),
          ),
          if (onForgotPassword != null)
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: NonFocusable(
                child: TextButton(
                  onPressed: enabled ? onForgotPassword : null,
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                  ),
                  child: Text('auth_forgot_password'.tr()),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
