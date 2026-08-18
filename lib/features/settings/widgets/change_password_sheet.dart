import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_logging_service/flutter_logging_service.dart';
import 'package:hisab_backend/hisab_backend.dart';

import '../../../core/auth/auth_providers.dart';
import '../../../core/layout/layout_breakpoints.dart';
import '../../../core/layout/responsive_sheet.dart';
import '../../../core/utils/form_validators.dart';
import '../../../core/widgets/inline_banner.dart';
import '../../../core/widgets/obscure_text_toggle.dart';
import '../../../core/widgets/toast.dart';

/// Minimum length for a new password (Supabase default).
const int _kMinPasswordLength = FormValidators.passwordMin;

/// Why the sheet is open, which decides whether identity still has to be proven.
enum ChangePasswordMode {
  /// A signed-in user changing a password they already know.
  normal,

  /// Arrived from a recovery link. Following that link is the proof of
  /// identity, and the whole point is that the old password is unknown, so
  /// there is nothing to re-authenticate against.
  recovery,
}

/// Bottom sheet to change password for email/password users.
///
/// In [ChangePasswordMode.normal] the current password is verified by signing
/// in with it before the update.
Future<void> showChangePasswordSheet(
  BuildContext context,
  WidgetRef ref, {
  ChangePasswordMode mode = ChangePasswordMode.normal,
}) async {
  final isRecovery = mode == ChangePasswordMode.recovery;
  await showResponsiveSheet<void>(
    context: context,
    title: isRecovery
        ? 'change_password_recovery_title'.tr()
        : 'change_password_title'.tr(),
    isScrollControlled: true,
    useSafeArea: true,
    centerInFullViewport: false,
    child: _ChangePasswordSheet(ref: ref, mode: mode),
  );
}

class _ChangePasswordSheet extends ConsumerStatefulWidget {
  const _ChangePasswordSheet({required this.ref, required this.mode});
  final WidgetRef ref;
  final ChangePasswordMode mode;

  @override
  ConsumerState<_ChangePasswordSheet> createState() =>
      _ChangePasswordSheetState();
}

class _ChangePasswordSheetState extends ConsumerState<_ChangePasswordSheet> {
  final _currentController = TextEditingController();
  final _newController = TextEditingController();
  final _confirmController = TextEditingController();
  final _focusCurrent = FocusNode();
  final _focusNew = FocusNode();
  final _focusConfirm = FocusNode();
  bool _saving = false;
  String? _error;
  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;

  @override
  void initState() {
    super.initState();
    _addFocusRestore(_focusCurrent);
    _addFocusRestore(_focusNew);
    _addFocusRestore(_focusConfirm);
  }

  /// Re-request focus when it was stolen by dialog/route (not by another password field).
  void _addFocusRestore(FocusNode node) {
    node.addListener(() {
      if (node.hasFocus) return;
      final primary = FocusManager.instance.primaryFocus;
      if (primary == _focusCurrent ||
          primary == _focusNew ||
          primary == _focusConfirm) {
        return;
      }
      final widgetType = primary?.context?.widget.runtimeType.toString() ?? '';
      if (widgetType.contains('EditableText')) return;
      Future.delayed(const Duration(milliseconds: 100), () {
        if (!mounted || node.hasFocus) return;
        final now = FocusManager.instance.primaryFocus;
        if (now == _focusCurrent || now == _focusNew || now == _focusConfirm) {
          return;
        }
        node.requestFocus();
      });
    });
  }

  @override
  void dispose() {
    _focusCurrent.dispose();
    _focusNew.dispose();
    _focusConfirm.dispose();
    _currentController.dispose();
    _newController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  bool get _isRecovery => widget.mode == ChangePasswordMode.recovery;

  Future<void> _submit() async {
    final current = _currentController.text;
    final newPassword = _newController.text;
    final confirm = _confirmController.text;

    if (!_isRecovery && current.isEmpty) {
      setState(() => _error = 'change_password_enter_current'.tr());
      return;
    }
    if (newPassword.length < _kMinPasswordLength) {
      setState(
        () => _error = 'change_password_too_short'.tr(
          namedArgs: {'min': _kMinPasswordLength.toString()},
        ),
      );
      return;
    }
    if (newPassword != confirm) {
      setState(() => _error = 'change_password_mismatch'.tr());
      return;
    }

    final user = ref.read(currentUserProvider);
    final email = user?.email;
    if (!_isRecovery && (email == null || email.isEmpty)) {
      setState(() => _error = 'change_password_no_email'.tr());
      return;
    }

    setState(() {
      _error = null;
      _saving = true;
    });

    try {
      final authService = ref.read(authServiceProvider);
      // The recovery link already established the session, which is the proof
      // of identity a re-auth would otherwise provide.
      if (!_isRecovery) {
        await authService.signInWithEmail(email!, current);
      }
      await authService.updatePassword(newPassword);
      if (!mounted) return;
      context.showSuccess('password_changed_success'.tr());
      Navigator.of(context).pop();
    } catch (e) {
      Log.warning('Change password failed', error: e);
      if (mounted) {
        setState(() {
          _saving = false;
          _error = _parseChangePasswordError(e);
        });
      }
    }
  }

  String _parseChangePasswordError(Object e) {
    if (e is CloudException) {
      if (e.message.toLowerCase().contains('reauthenticate') ||
          e.message.toLowerCase().contains('reauthentication')) {
        return 'change_password_reauth_required'.tr();
      }
      if (e.code == 'over_email_send_rate_limit' ||
          e.message.toLowerCase().contains('rate limit')) {
        return 'auth_rate_limit'.tr();
      }
      if (e.message.toLowerCase().contains('invalid') ||
          e.message.toLowerCase().contains('credentials')) {
        return 'change_password_wrong_current'.tr();
      }
      if (e.message.toLowerCase().contains('at least') ||
          e.message.toLowerCase().contains('6 characters')) {
        return 'change_password_too_short'.tr(
          namedArgs: {'min': _kMinPasswordLength.toString()},
        );
      }
      return e.message;
    }
    final msg = e.toString();
    if (msg.contains('Invalid login credentials') ||
        msg.contains('invalid_credentials')) {
      return 'change_password_wrong_current'.tr();
    }
    if (msg.contains('reauthenticate') || msg.contains('reauthentication')) {
      return 'change_password_reauth_required'.tr();
    }
    if (msg.contains('rate limit') || msg.contains('rate_limit')) {
      return 'auth_rate_limit'.tr();
    }
    return 'auth_generic_error'.tr();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.only(left: 24, right: 24, top: 16, bottom: 24),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!LayoutBreakpoints.isTabletOrWider(context)) ...[
              Text(
                _isRecovery
                    ? 'change_password_recovery_title'.tr()
                    : 'change_password_title'.tr(),
                style: textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
            ],
            if (_isRecovery) ...[
              InlineBanner(
                message: 'change_password_recovery_subtitle'.tr(),
                tone: InlineBannerTone.info,
                icon: Icons.lock_reset_outlined,
              ),
              const SizedBox(height: 16),
            ],
            if (_error != null) ...[
              InlineBanner(message: _error!),
              const SizedBox(height: 16),
            ],
            if (!_isRecovery) ...[
              TextField(
                controller: _currentController,
                focusNode: _focusCurrent,
                decoration: InputDecoration(
                  labelText: 'change_password_current'.tr(),
                  prefixIcon: const Icon(Icons.lock_outline),
                  border: const OutlineInputBorder(),
                  suffixIcon: ObscureTextToggle(
                    obscure: _obscureCurrent,
                    onTap: () =>
                        setState(() => _obscureCurrent = !_obscureCurrent),
                  ),
                ),
                obscureText: _obscureCurrent,
                textInputAction: TextInputAction.next,
                enabled: !_saving,
              ),
              const SizedBox(height: 12),
            ],
            TextField(
              controller: _newController,
              focusNode: _focusNew,
              decoration: InputDecoration(
                labelText: 'change_password_new'.tr(),
                prefixIcon: const Icon(Icons.lock_outline),
                border: const OutlineInputBorder(),
                suffixIcon: ObscureTextToggle(
                  obscure: _obscureNew,
                  onTap: () => setState(() => _obscureNew = !_obscureNew),
                ),
              ),
              obscureText: _obscureNew,
              textInputAction: TextInputAction.next,
              enabled: !_saving,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _confirmController,
              focusNode: _focusConfirm,
              decoration: InputDecoration(
                labelText: 'change_password_confirm'.tr(),
                prefixIcon: const Icon(Icons.lock_outline),
                border: const OutlineInputBorder(),
                suffixIcon: ObscureTextToggle(
                  obscure: _obscureConfirm,
                  onTap: () =>
                      setState(() => _obscureConfirm = !_obscureConfirm),
                ),
              ),
              obscureText: _obscureConfirm,
              textInputAction: TextInputAction.done,
              enabled: !_saving,
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 24),
            // Use non-focusable control so the focus manager does not steal focus from the password fields (FilledButton is focusable and was receiving focus during applyFocusChangesIfNeeded).
            _SubmitButton(saving: _saving, onPressed: _saving ? null : _submit),
          ],
        ),
      ),
    );
  }
}

/// Submit button that is not focusable (InkWell-based) so the focus manager
/// does not steal focus from the password TextFields.
class _SubmitButton extends StatelessWidget {
  const _SubmitButton({required this.saving, required this.onPressed});
  final bool saving;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      color: onPressed == null
          ? colorScheme.onSurface.withValues(alpha: 0.12)
          : colorScheme.primary,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        canRequestFocus: false,
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Center(
            child: saving
                ? SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: colorScheme.onPrimary,
                    ),
                  )
                : Text(
                    'change_password'.tr(),
                    style: TextStyle(
                      color: colorScheme.onPrimary,
                      fontSize: 16,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
