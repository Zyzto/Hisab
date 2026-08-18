import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../layout/layout_breakpoints.dart';
import '../layout/responsive_sheet.dart';
import '../platform/ui_perf.dart';
import '../utils/form_validators.dart';
import '../widgets/inline_banner.dart';
import '../widgets/sheet_helpers.dart';
import 'auth_flow_policy.dart';
import 'auth_providers.dart';
import 'sign_in/auth_error_messages.dart';
import 'sign_in/sign_in_controller.dart';
import 'sign_in/sign_in_state.dart';
import 'sign_in/widgets/auth_brand_panel.dart';
import 'sign_in/widgets/auth_buttons.dart';
import 'sign_in/widgets/auth_hero.dart';
import 'sign_in/widgets/credentials_form.dart';
import 'sign_in/widgets/oauth_button_row.dart';
import 'sign_in/widgets/pending_email_panel.dart';
import 'sign_in/widgets/profile_step.dart';
import 'sign_in_result.dart';

export 'sign_in_result.dart' show SignInResult;

/// Dialog cap when there is room for the form and the brand panel side by side.
const double _kBrandDialogMaxWidth = 880;

/// Width reserved for [AuthBrandPanel].
const double _kBrandPanelWidth = 320;

/// Below this the panel would squeeze the form, so only the form is shown.
const double _kBrandPanelMinSheetWidth = 700;

/// The adaptive sign-in modal: email/password, magic link, Google and GitHub.
///
/// Sign-up runs in two steps (credentials, then name and avatar) so neither
/// half has to compete for room on a phone.
///
/// ```dart
/// final result = await showSignInSheet(context, ref);
/// ```
///
/// Dismissing the sheet by barrier or back returns
/// [SignInResult.pendingEmailLink] rather than [SignInResult.cancelled] once an
/// email has gone out, because callers use `cancelled` to tear down pending
/// invite and online-mode state that is still needed.
Future<SignInResult> showSignInSheet(
  BuildContext context,
  WidgetRef ref,
) async {
  final controller = SignInController(
    authService: ref.read(authServiceProvider),
  );
  // Desktop earns a second column for the brand panel. Narrower viewports keep
  // the standard cap, where a form that wide would just be a long line length.
  final wideEnoughForBrand =
      MediaQuery.sizeOf(context).width >= LayoutBreakpoints.breakpointDesktop;
  final result = await showResponsiveSheet<SignInResult>(
    context: context,
    title: 'sign_in'.tr(),
    isScrollControlled: true,
    useSafeArea: true,
    centerInFullViewport: true,
    maxWidth: wideEnoughForBrand ? _kBrandDialogMaxWidth : null,
    child: _SignInSheet(controller: controller),
  );
  final resolved =
      result ??
      resolveSignInSheetDismiss(
        emailLinkPending: controller.state.emailLinkPending,
      );
  // The sheet is still on screen during its exit animation, so give the route
  // time to leave the tree before tearing the controller down.
  Future<void>.delayed(
    const Duration(milliseconds: 300),
    controller.dispose,
  );
  return resolved;
}

class _SignInSheet extends StatefulWidget {
  const _SignInSheet({required this.controller});

  final SignInController controller;

  @override
  State<_SignInSheet> createState() => _SignInSheetState();
}

class _SignInSheetState extends State<_SignInSheet> {
  final _formKey = GlobalKey<FormState>();
  final _emailFieldKey = GlobalKey<FormFieldState<String>>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();

  bool _popped = false;

  SignInController get _controller => widget.controller;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_closeWhenFinished);
  }

  @override
  void dispose() {
    _controller.removeListener(_closeWhenFinished);
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  /// Pops with whatever result the controller settled on. Guarded because a
  /// late auth-state event can fire after the sheet has already closed.
  void _closeWhenFinished() {
    final outcome = _controller.state.outcome;
    if (outcome == null || _popped || !mounted) return;
    _popped = true;
    if (outcome == SignInResult.success) _commitAutofill();
    final navigator = Navigator.of(context);
    if (navigator.canPop()) navigator.pop(outcome);
  }

  /// Tells the platform the credentials worked, which is what prompts a
  /// password manager to offer to save them.
  ///
  /// Skipped when the fields are empty, i.e. the user signed in through a
  /// provider and there is nothing to save.
  void _commitAutofill() {
    if (_email.isEmpty || _passwordController.text.isEmpty) return;
    TextInput.finishAutofillContext();
  }

  String get _email => _emailController.text.trim();

  bool _validateAll() => _formKey.currentState?.validate() ?? false;

  /// Only the address matters for magic link, which has no password to check.
  bool _validateEmailOnly() => _emailFieldKey.currentState?.validate() ?? false;

  void _onPrimaryPressed() {
    final state = _controller.state;
    if (state.isProfileStep) {
      _controller.submit(
        email: _email,
        password: _passwordController.text,
        name: _nameController.text,
      );
      return;
    }
    if (!_validateAll()) return;
    if (state.isSignUp) {
      _controller.goToProfileStep();
      return;
    }
    _controller.submit(email: _email, password: _passwordController.text);
  }

  void _onMagicLinkPressed() {
    if (!_validateEmailOnly()) return;
    _controller.sendMagicLink(_email);
  }

  void _onForgotPasswordPressed() {
    if (!_validateEmailOnly()) return;
    _controller.sendPasswordReset(_email);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        final state = _controller.state;
        return PopScope(
          canPop: state.canPop,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final showBrand =
                  constraints.maxWidth >= _kBrandPanelMinSheetWidth;
              final shell = buildSheetShell(
                context,
                title: state.isSignUp ? 'auth_sign_up'.tr() : 'sign_in'.tr(),
                // The hero is the title here. Letting the shell draw one too
                // would stack two headings, and they would disagree the moment
                // the user switched to sign-up.
                showTitleInBody: false,
                body: _body(context, state, showBrand: showBrand),
                actions: const [],
              );
              if (!showBrand) return shell;
              // The form sizes the stack and the panel stretches to match.
              // A Row with stretch would instead take the dialog's full height
              // cap, and IntrinsicHeight cannot measure the shell's scroll view.
              return Stack(
                children: [
                  const PositionedDirectional(
                    top: 0,
                    bottom: 0,
                    end: 0,
                    width: _kBrandPanelWidth,
                    child: AuthBrandPanel(width: _kBrandPanelWidth),
                  ),
                  Padding(
                    padding: const EdgeInsetsDirectional.only(
                      end: _kBrandPanelWidth,
                    ),
                    child: shell,
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  Widget _body(
    BuildContext context,
    SignInFormState state, {
    required bool showBrand,
  }) {
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AuthHero(
          headline: _headlineFor(state),
          subtitle: _subtitleFor(state),
          showMark: !showBrand,
        ),
        // Sign-up spans two screens, so say so before the button that reads
        // "Continue" makes the user wonder whether the account now exists.
        if (state.isSignUp && !state.showsPanel) ...[
          const SizedBox(height: 16),
          _StepIndicator(
            current: state.signUpStep == SignUpStep.credentials ? 1 : 2,
            total: 2,
          ),
        ],
        const SizedBox(height: 20),
        if (state.showsPanel)
          PendingEmailPanel(
            panel: state.panel,
            email: _email,
            confirmationResent: state.confirmationResent,
            busy: state.busy,
            onResend: () => _controller.resendConfirmation(_email),
            onDone: _controller.acknowledgePendingEmail,
          )
        else ...[
          if (state.isProfileStep)
            ProfileStep(
              nameController: _nameController,
              selectedAvatarId: state.selectedAvatarId,
              onAvatarSelected: _controller.selectAvatar,
              enabled: !state.busy,
              onSubmit: _onPrimaryPressed,
            )
          else ...[
            OAuthButtonRow(
              enabled: !state.busy,
              onProviderSelected: _controller.signInWithProvider,
            ),
            const SizedBox(height: 20),
            const _OrDivider(),
            const SizedBox(height: 20),
            CredentialsForm(
              formKey: _formKey,
              emailFieldKey: _emailFieldKey,
              emailController: _emailController,
              passwordController: _passwordController,
              obscurePassword: state.obscurePassword,
              onToggleObscure: _controller.toggleObscurePassword,
              isSignUp: state.isSignUp,
              enabled: !state.busy,
              onSubmit: _onPrimaryPressed,
              // No password to recover before the account exists.
              onForgotPassword: state.isSignUp
                  ? null
                  : _onForgotPasswordPressed,
            ),
          ],
          if (state.errorKey != null) ...[
            const SizedBox(height: 16),
            InlineBanner(
              message: state.errorKey!.tr(
                namedArgs: {'min': '${FormValidators.passwordMin}'},
              ),
              // The backend cannot tell "wrong password" apart from "this
              // account only has a Google identity" without leaking whether
              // the address is registered, so point at the buttons above
              // instead of guessing which one it was.
              detail: state.errorKey == AuthErrorKeys.invalidCredentials
                  ? 'auth_provider_hint'.tr()
                  : null,
            ),
          ],
          const SizedBox(height: 16),
          _actions(state),
        ],
      ],
    );

    // One autofill context across both steps, so a password manager sees the
    // address, the password and the name as one credential.
    //
    // Cancel on dispose because the default commits: closing the sheet after a
    // typo or a change of mind would otherwise offer to save a credential that
    // was never accepted. `_commitAutofill` is the only path that saves.
    final group = AutofillGroup(
      onDisposeAction: AutofillContextAction.cancel,
      child: content,
    );

    // Every transition here changes the body's height — toggling mode, moving
    // to the profile step, an error appearing. Without this the sheet snaps to
    // the new height and the content under the user's thumb jumps.
    if (UiPerf.preferReducedChromeMotion) return group;
    return AnimatedSize(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      alignment: Alignment.topCenter,
      child: group,
    );
  }

  Widget _actions(SignInFormState state) {
    if (state.isProfileStep) {
      return Row(
        children: [
          NonFocusable(
            child: TextButton(
              onPressed: state.busy ? null : _controller.backToCredentials,
              child: Text('auth_back'.tr()),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: AuthPrimaryButton(
              label: 'auth_create_account'.tr(),
              busy: state.busy,
              onPressed: _onPrimaryPressed,
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AuthPrimaryButton(
          label: state.isSignUp ? 'auth_continue'.tr() : 'sign_in'.tr(),
          busy: state.busy,
          onPressed: _onPrimaryPressed,
        ),
        // Magic link is a sign-in shortcut; during sign-up it would silently
        // skip the profile step the user is halfway through.
        if (!state.isSignUp)
          NonFocusable(
            child: TextButton(
              onPressed: state.busy ? null : _onMagicLinkPressed,
              // Three stacked text buttons at default density read as a wall
              // of links and push the sheet taller than it needs to be.
              style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
              child: Text('auth_magic_link'.tr()),
            ),
          ),
        _ModeToggle(state: state, onToggle: _controller.toggleMode),
      ],
    );
  }

  /// Headline in the hero. Gives each state a voice instead of repeating the
  /// sheet's own title back at the user.
  String _headlineFor(SignInFormState state) {
    if (state.showsPanel) return 'auth_check_email'.tr();
    if (state.isProfileStep) return 'auth_almost_there'.tr();
    return state.isSignUp
        ? 'auth_create_account_title'.tr()
        : 'auth_welcome_back'.tr();
  }

  String _subtitleFor(SignInFormState state) {
    if (state.showsPanel) return 'auth_check_email_subtitle'.tr();
    if (state.isProfileStep) return 'auth_profile_subtitle'.tr();
    return state.isSignUp
        ? 'auth_sign_up_subtitle'.tr()
        : 'auth_sign_in_subtitle'.tr();
  }
}

class _OrDivider extends StatelessWidget {
  const _OrDivider();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final line = Divider(
      color: theme.colorScheme.outline.withValues(alpha: 0.3),
    );
    return Row(
      children: [
        Expanded(child: line),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            // Naming the alternative is the difference between a separator and
            // a signpost: the providers are the fast path, this is the other.
            'auth_or_email'.tr(),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        Expanded(child: line),
      ],
    );
  }
}

/// Progress through the two-step sign-up: filled bars plus a spoken label.
class _StepIndicator extends StatelessWidget {
  const _StepIndicator({required this.current, required this.total});

  final int current;
  final int total;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final label = 'auth_step_of'.tr(
      namedArgs: {'current': '$current', 'total': '$total'},
    );

    return Row(
      children: [
        // The bars restate the label, so screen readers hear it once.
        for (int step = 1; step <= total; step++) ...[
          if (step > 1) const SizedBox(width: 6),
          Expanded(
            child: ExcludeSemantics(
              child: AnimatedContainer(
                duration: UiPerf.preferReducedChromeMotion
                    ? Duration.zero
                    : const Duration(milliseconds: 180),
                height: 4,
                decoration: BoxDecoration(
                  color: step <= current ? cs.primary : cs.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),
        ],
        const SizedBox(width: 12),
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: cs.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _ModeToggle extends StatelessWidget {
  const _ModeToggle({required this.state, required this.onToggle});

  final SignInFormState state;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Wrap rather than Row: the two halves are a sentence, and in Arabic (or
    // at a large text scale) they need to break onto separate lines instead of
    // squeezing the prompt into an ellipsis.
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          state.isSignUp ? 'auth_have_account'.tr() : 'auth_no_account'.tr(),
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        NonFocusable(
          child: TextButton(
            onPressed: state.busy ? null : onToggle,
            style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
            child: Text(state.isSignUp ? 'sign_in'.tr() : 'auth_sign_up'.tr()),
          ),
        ),
      ],
    );
  }
}
