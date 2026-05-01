import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flutter_logging_service/flutter_logging_service.dart';

import '../../../core/layout/constrained_content.dart';
import '../../settings/providers/settings_framework_providers.dart';
import '../../settings/settings_definitions.dart';
import '../services/notification_bridge.dart';
import 'sender_rules_page.dart';

/// Onboarding wizard for enabling the transaction scanner.
///
/// Steps:
/// 1. Explanation + privacy assurance
/// 2. Notification listener permission
/// 3. Done → link to sender management
class ScannerSetupPage extends ConsumerStatefulWidget {
  const ScannerSetupPage({super.key});

  @override
  ConsumerState<ScannerSetupPage> createState() => _ScannerSetupPageState();
}

class _ScannerSetupPageState extends ConsumerState<ScannerSetupPage> {
  int _step = 0;
  bool _listenerEnabled = false;
  bool _checking = false;

  @override
  void initState() {
    super.initState();
    _checkListener();
  }

  Future<void> _checkListener() async {
    setState(() => _checking = true);
    _listenerEnabled = await NotificationBridge.isListenerEnabled();
    if (mounted) setState(() => _checking = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: Text('scanner_setup_title'.tr())),
      body: ConstrainedContent(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Step indicator
              Row(
                children: List.generate(3, (i) {
                  final active = i <= _step;
                  return Expanded(
                    child: Container(
                      height: 4,
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      decoration: BoxDecoration(
                        color: active
                            ? colorScheme.primary
                            : colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 32),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: _buildStep(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStep(BuildContext context) {
    switch (_step) {
      case 0:
        return _StepExplain(onNext: () => setState(() => _step = 1));
      case 1:
        return _StepPermission(
          listenerEnabled: _listenerEnabled,
          checking: _checking,
          onRequestPermission: () async {
            await NotificationBridge.openListenerSettings();
          },
          onCheckAgain: _checkListener,
          onNext: () async {
            await _checkListener();
            if (_listenerEnabled) {
              await NotificationBridge.setEnabled(true);
              final settings = ref.read(hisabSettingsProvidersProvider);
              if (settings != null) {
                ref
                    .read(
                      settings.provider(scannerEnabledSettingDef).notifier,
                    )
                    .set(true);
                Log.info(
                  'Setting changed: ${scannerEnabledSettingDef.key}=true',
                );
              }
              if (mounted) setState(() => _step = 2);
            }
          },
        );
      case 2:
      default:
        return _StepDone(
          onManageSenders: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const SenderRulesPage(),
              ),
            );
          },
          onFinish: () => Navigator.pop(context, true),
        );
    }
  }
}

class _StepExplain extends StatelessWidget {
  final VoidCallback onNext;

  const _StepExplain({required this.onNext});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      key: const ValueKey('explain'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          Icons.document_scanner_outlined,
          size: 48,
          color: theme.colorScheme.primary,
        ),
        const SizedBox(height: 16),
        Text(
          'scanner_setup_explain_title'.tr(),
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'scanner_setup_explain_body'.tr(),
          style: theme.textTheme.bodyLarge,
        ),
        const SizedBox(height: 24),
        _bulletPoint(context, Icons.lock_outline, 'scanner_setup_privacy'.tr()),
        _bulletPoint(context, Icons.filter_alt_outlined, 'scanner_setup_filter'.tr()),
        _bulletPoint(context, Icons.visibility_outlined, 'scanner_setup_review'.tr()),
        const Spacer(),
        FilledButton(
          onPressed: onNext,
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(48),
          ),
          child: Text('scanner_setup_continue'.tr()),
        ),
      ],
    );
  }

  Widget _bulletPoint(BuildContext context, IconData icon, String text) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: theme.colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(text, style: theme.textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}

class _StepPermission extends StatelessWidget {
  final bool listenerEnabled;
  final bool checking;
  final VoidCallback onRequestPermission;
  final VoidCallback onCheckAgain;
  final VoidCallback onNext;

  const _StepPermission({
    required this.listenerEnabled,
    required this.checking,
    required this.onRequestPermission,
    required this.onCheckAgain,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      key: const ValueKey('permission'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          listenerEnabled ? Icons.check_circle : Icons.notifications_outlined,
          size: 48,
          color:
              listenerEnabled ? Colors.green : theme.colorScheme.primary,
        ),
        const SizedBox(height: 16),
        Text(
          'scanner_setup_permission_title'.tr(),
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'scanner_setup_permission_body'.tr(),
          style: theme.textTheme.bodyLarge,
        ),
        const SizedBox(height: 24),
        if (listenerEnabled)
          Card(
            color: Colors.green.withValues(alpha: 0.1),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.green),
                  const SizedBox(width: 12),
                  Text(
                    'scanner_permission_granted'.tr(),
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: Colors.green.shade800,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          OutlinedButton.icon(
            onPressed: onRequestPermission,
            icon: const Icon(Icons.settings),
            label: Text('scanner_open_settings'.tr()),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
            ),
          ),
        const SizedBox(height: 12),
        if (!listenerEnabled)
          Center(
            child: checking
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : TextButton(
                    onPressed: onCheckAgain,
                    child: Text('scanner_check_again'.tr()),
                  ),
          ),
        const Spacer(),
        FilledButton(
          onPressed: listenerEnabled ? onNext : null,
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(48),
          ),
          child: Text('scanner_setup_continue'.tr()),
        ),
      ],
    );
  }
}

class _StepDone extends StatelessWidget {
  final VoidCallback onManageSenders;
  final VoidCallback onFinish;

  const _StepDone({
    required this.onManageSenders,
    required this.onFinish,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      key: const ValueKey('done'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.check_circle, size: 48, color: Colors.green),
        const SizedBox(height: 16),
        Text(
          'scanner_setup_done_title'.tr(),
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'scanner_setup_done_body'.tr(),
          style: theme.textTheme.bodyLarge,
        ),
        const SizedBox(height: 24),
        OutlinedButton.icon(
          onPressed: onManageSenders,
          icon: const Icon(Icons.filter_list),
          label: Text('scanner_manage_senders'.tr()),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(48),
          ),
        ),
        const Spacer(),
        FilledButton(
          onPressed: onFinish,
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(48),
          ),
          child: Text('scanner_setup_finish'.tr()),
        ),
      ],
    );
  }
}
