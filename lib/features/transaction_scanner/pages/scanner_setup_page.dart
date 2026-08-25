import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/layout/constrained_content.dart';
import '../../../core/widgets/wizard_step_enter.dart';
import 'package:hisab/core/settings/providers/settings_framework_providers.dart';
import 'package:hisab/core/settings/settings_definitions.dart';
import '../../groups/pages/group_create_page.dart';
import '../../settings/widgets/apply_setting.dart';
import '../../groups/providers/groups_provider.dart';
import '../domain/field_span.dart';
import '../domain/installed_app.dart';
import '../domain/sender_rule.dart';
import '../providers/scanner_providers.dart';
import '../services/notification_bridge.dart';
import '../services/pattern_from_spans.dart';
import '../services/transaction_parser.dart';
import '../utils/suggested_apps.dart';
import '../widgets/notification_annotator.dart';
import '../widgets/scanner_group_picker.dart';

const _uuid = Uuid();

const _sampleEn =
    'Purchase of 42.50 SAR at Starbucks in Riyadh on 25/08/2026. Card *1234';
const _sampleAr = 'تم خصم 150.00 ر.س لدى كريم في الرياض';

/// Full setup wizard: privacy → permission → apps → teach → destination → AI.
class ScannerSetupPage extends ConsumerStatefulWidget {
  const ScannerSetupPage({super.key});

  @override
  ConsumerState<ScannerSetupPage> createState() => _ScannerSetupPageState();
}

class _ScannerSetupPageState extends ConsumerState<ScannerSetupPage> {
  int _step = 0;
  bool _listenerEnabled = false;
  bool _checking = false;
  final Set<String> _selectedPackages = {};
  final Map<String, String> _labels = {};
  List<InstalledApp> _installed = const [];
  String _appQuery = '';
  String _sampleBody = _sampleEn;
  List<FieldSpan> _spans = const [];
  String? _groupId;
  bool _categorize = true;
  String _aiMode = 'off';

  static const _stepCount = 7;

  @override
  void initState() {
    super.initState();
    _checkListener();
    _loadInstalled();
    _prefill();
  }

  void _prefill() {
    final settings = ref.read(hisabSettingsProvidersProvider);
    if (settings != null) {
      _categorize =
          settings.controller.get(scannerCategorizeEnabledSettingDef) == true;
      _aiMode =
          settings.controller.get(scannerAiModeSettingDef) as String? ?? 'off';
      final gid =
          settings.controller.get(scannerDefaultGroupIdSettingDef) as String?;
      if (gid != null && gid.isNotEmpty) _groupId = gid;
    }
    _spans = TransactionParser.parse(_sampleBody).fieldSpans;
  }

  Future<void> _loadInstalled() async {
    final apps = await NotificationBridge.listInstalledApps();
    if (!mounted) return;
    setState(() => _installed = apps);
    final existing = await ref.read(scannerRepositoryProvider).getSenderRules();
    if (!mounted) return;
    if (existing.isNotEmpty) {
      setState(() {
        for (final r in existing.where((e) => e.enabled)) {
          _selectedPackages.add(r.packageName);
          if (r.senderLabel != null) _labels[r.packageName] = r.senderLabel!;
        }
      });
    }
  }

  Future<void> _checkListener() async {
    setState(() => _checking = true);
    _listenerEnabled = await NotificationBridge.isListenerEnabled();
    if (mounted) setState(() => _checking = false);
  }

  Future<void> _finish() async {
    final settings = ref.read(hisabSettingsProvidersProvider);
    final repo = ref.read(scannerRepositoryProvider);
    final now = DateTime.now();

    final existing = await repo.getSenderRules();
    final byPkg = {for (final r in existing) r.packageName: r};
    for (final pkg in _selectedPackages) {
      final prev = byPkg[pkg];
      final label =
          _labels[pkg] ??
          prev?.senderLabel ??
          _installed.where((a) => a.packageName == pkg).firstOrNull?.label ??
          suggestedScannerApps
              .where((a) => a.packageName == pkg)
              .firstOrNull
              ?.label;
      await repo.upsertSenderRule(
        SenderRule(
          id: prev?.id ?? _uuid.v4(),
          packageName: pkg,
          senderLabel: label,
          targetGroupId: prev?.targetGroupId,
          matchCount: prev?.matchCount ?? 0,
          createdAt: prev?.createdAt ?? now,
        ),
      );
    }
    for (final prev in existing) {
      if (!_selectedPackages.contains(prev.packageName)) {
        await repo.deleteSenderRule(prev.id);
      }
    }

    final taught = patternFromSpans(
      id: 'taught_user',
      name: 'scanner_pattern_taught',
      senderMatch: _selectedPackages.length == 1
          ? _selectedPackages.first
          : '*',
      body: _sampleBody,
      spans: _spans,
      createdAt: now,
    );
    if (taught != null) {
      await repo.upsertPattern(taught);
    }

    await NotificationBridge.setEnabled(true);
    if (settings != null) {
      await applySetting(ref, settings, scannerEnabledSettingDef, true);
      await applySetting(ref, settings, scannerSetupCompletedSettingDef, true);
      await applySetting(
        ref,
        settings,
        scannerCategorizeEnabledSettingDef,
        _categorize,
      );
      await applySetting(ref, settings, scannerAiModeSettingDef, _aiMode);
      if (_groupId != null) {
        await applySetting(
          ref,
          settings,
          scannerDefaultGroupIdSettingDef,
          _groupId!,
        );
      }
    }
    await ref.read(scannerControllerProvider).syncSendersToNative();
    ref.invalidate(senderRulesProvider);
    ref.invalidate(scannerPatternsProvider);
    if (mounted) Navigator.pop(context, true);
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
              Row(
                children: List.generate(_stepCount, (i) {
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
              const SizedBox(height: 24),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: WizardStepEnter(
                    key: ValueKey(_step),
                    child: _buildStep(context),
                  ),
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
        return _ExplainStep(onNext: () => setState(() => _step = 1));
      case 1:
        return _PermissionStep(
          listenerEnabled: _listenerEnabled,
          checking: _checking,
          onRequestPermission: () async {
            await NotificationBridge.openListenerSettings();
          },
          onCheckAgain: _checkListener,
          onNext: () async {
            await _checkListener();
            if (_listenerEnabled && mounted) setState(() => _step = 2);
          },
        );
      case 2:
        return _AppsStep(
          installed: _installed,
          selected: _selectedPackages,
          query: _appQuery,
          onQuery: (q) => setState(() => _appQuery = q),
          onToggle: (pkg, label) {
            setState(() {
              if (_selectedPackages.contains(pkg)) {
                _selectedPackages.remove(pkg);
              } else {
                _selectedPackages.add(pkg);
                _labels[pkg] = label;
              }
            });
          },
          onAddCustom: (pkg, label) {
            setState(() {
              _selectedPackages.add(pkg);
              if (label.isNotEmpty) _labels[pkg] = label;
            });
          },
          onNext: _selectedPackages.isEmpty
              ? null
              : () => setState(() => _step = 3),
        );
      case 3:
        return _TeachStep(
          body: _sampleBody,
          spans: _spans,
          onUseEn: () {
            setState(() {
              _sampleBody = _sampleEn;
              _spans = TransactionParser.parse(_sampleEn).fieldSpans;
            });
          },
          onUseAr: () {
            setState(() {
              _sampleBody = _sampleAr;
              _spans = TransactionParser.parse(_sampleAr).fieldSpans;
            });
          },
          onSpans: (s) => setState(() => _spans = s),
          onSkip: () => setState(() => _step = 4),
          onNext: () => setState(() => _step = 4),
        );
      case 4:
        return _DestinationStep(
          selectedId: _groupId,
          onSelected: (id) => setState(() => _groupId = id),
          onCreatePersonal: () async {
            await Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const GroupCreatePage(isPersonal: true),
              ),
            );
          },
          onNext: _groupId == null ? null : () => setState(() => _step = 5),
        );
      case 5:
        return _AiStep(
          categorize: _categorize,
          aiMode: _aiMode,
          onCategorize: (v) => setState(() => _categorize = v),
          onAiMode: (v) => setState(() => _aiMode = v),
          onNext: () => setState(() => _step = 6),
        );
      default:
        return _DoneStep(onFinish: _finish);
    }
  }
}

class _ExplainStep extends StatelessWidget {
  final VoidCallback onNext;

  const _ExplainStep({required this.onNext});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
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
        _bullet(context, Icons.lock_outline, 'scanner_setup_privacy'.tr()),
        _bullet(
          context,
          Icons.filter_alt_outlined,
          'scanner_setup_filter'.tr(),
        ),
        _bullet(
          context,
          Icons.visibility_outlined,
          'scanner_setup_review'.tr(),
        ),
        _bullet(context, Icons.history, 'scanner_setup_history_hint'.tr()),
        const Spacer(),
        FilledButton(
          onPressed: onNext,
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
          child: Text('scanner_setup_continue'.tr()),
        ),
      ],
    );
  }

  Widget _bullet(BuildContext context, IconData icon, String text) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: theme.colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: theme.textTheme.bodyMedium)),
        ],
      ),
    );
  }
}

class _PermissionStep extends StatelessWidget {
  final bool listenerEnabled;
  final bool checking;
  final VoidCallback onRequestPermission;
  final VoidCallback onCheckAgain;
  final VoidCallback onNext;

  const _PermissionStep({
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
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          listenerEnabled ? Icons.check_circle : Icons.notifications_outlined,
          size: 48,
          color: listenerEnabled ? Colors.green : theme.colorScheme.primary,
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
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
          child: Text('scanner_setup_continue'.tr()),
        ),
      ],
    );
  }
}

class _AppsStep extends StatelessWidget {
  final List<InstalledApp> installed;
  final Set<String> selected;
  final String query;
  final ValueChanged<String> onQuery;
  final void Function(String package, String label) onToggle;
  final void Function(String package, String label) onAddCustom;
  final VoidCallback? onNext;

  const _AppsStep({
    required this.installed,
    required this.selected,
    required this.query,
    required this.onQuery,
    required this.onToggle,
    required this.onAddCustom,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final q = query.trim().toLowerCase();
    final suggestedInstalled = suggestedScannerApps.where((s) {
      return installed.any((a) => a.packageName == s.packageName) ||
          selected.contains(s.packageName);
    });
    final others = installed.where((a) {
      if (isSuggestedScannerPackage(a.packageName)) return false;
      if (q.isEmpty) return true;
      return a.label.toLowerCase().contains(q) ||
          a.packageName.toLowerCase().contains(q);
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'scanner_setup_apps_title'.tr(),
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text('scanner_setup_apps_body'.tr(), style: theme.textTheme.bodyMedium),
        const SizedBox(height: 12),
        TextField(
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.search),
            hintText: 'scanner_search_apps'.tr(),
            border: const OutlineInputBorder(),
            isDense: true,
          ),
          onChanged: onQuery,
        ),
        const SizedBox(height: 8),
        Expanded(
          child: ListView(
            children: [
              if (suggestedInstalled.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4, top: 4),
                  child: Text(
                    'scanner_suggested_apps'.tr(),
                    style: theme.textTheme.labelLarge,
                  ),
                ),
              ...suggestedInstalled.map((s) {
                final label =
                    installed
                        .where((a) => a.packageName == s.packageName)
                        .firstOrNull
                        ?.label ??
                    s.label;
                return CheckboxListTile(
                  value: selected.contains(s.packageName),
                  onChanged: (_) => onToggle(s.packageName, label),
                  title: Text(label),
                  subtitle: Text(s.packageName),
                  dense: true,
                );
              }),
              ...others.take(80).map((a) {
                return CheckboxListTile(
                  value: selected.contains(a.packageName),
                  onChanged: (_) => onToggle(a.packageName, a.label),
                  title: Text(a.label),
                  subtitle: Text(a.packageName),
                  dense: true,
                );
              }),
            ],
          ),
        ),
        TextButton.icon(
          onPressed: () => _addCustom(context),
          icon: const Icon(Icons.add),
          label: Text('scanner_add_sender'.tr()),
        ),
        FilledButton(
          onPressed: onNext,
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
          child: Text('scanner_setup_continue'.tr()),
        ),
      ],
    );
  }

  void _addCustom(BuildContext context) {
    final pkg = TextEditingController();
    final label = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text('scanner_add_sender'.tr()),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: pkg,
                decoration: InputDecoration(
                  labelText: 'scanner_package_name'.tr(),
                ),
              ),
              TextField(
                controller: label,
                decoration: InputDecoration(
                  labelText: 'scanner_sender_label'.tr(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('cancel'.tr()),
            ),
            FilledButton(
              onPressed: () {
                final p = pkg.text.trim();
                if (p.isEmpty) return;
                onAddCustom(p, label.text.trim());
                Navigator.pop(ctx);
              },
              child: Text('scanner_add'.tr()),
            ),
          ],
        );
      },
    );
  }
}

class _TeachStep extends StatelessWidget {
  final String body;
  final List<FieldSpan> spans;
  final VoidCallback onUseEn;
  final VoidCallback onUseAr;
  final ValueChanged<List<FieldSpan>> onSpans;
  final VoidCallback onSkip;
  final VoidCallback onNext;

  const _TeachStep({
    required this.body,
    required this.spans,
    required this.onUseEn,
    required this.onUseAr,
    required this.onSpans,
    required this.onSkip,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final extracted = valuesFromSpans(body, spans);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'scanner_setup_teach_title'.tr(),
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'scanner_setup_teach_body'.tr(),
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            FilterChip(
              label: Text('scanner_sample_en'.tr()),
              selected: body == _sampleEn,
              onSelected: (_) => onUseEn(),
            ),
            const SizedBox(width: 8),
            FilterChip(
              label: Text('scanner_sample_ar'.tr()),
              selected: body == _sampleAr,
              onSelected: (_) => onUseAr(),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Expanded(
          child: ListView(
            children: [
              NotificationAnnotator(
                title: 'scanner_sample_notification'.tr(),
                body: body,
                spans: spans,
                onSpansChanged: onSpans,
              ),
              const SizedBox(height: 8),
              Text(
                [
                  if (extracted.amountCents != null)
                    '${(extracted.amountCents! / 100).toStringAsFixed(2)} ${extracted.currency ?? ''}',
                  if (extracted.merchant != null) extracted.merchant,
                  if (extracted.place != null) extracted.place,
                ].join(' · '),
                style: theme.textTheme.titleSmall,
              ),
            ],
          ),
        ),
        TextButton(onPressed: onSkip, child: Text('scanner_setup_skip'.tr())),
        FilledButton(
          onPressed: onNext,
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
          child: Text('scanner_setup_continue'.tr()),
        ),
      ],
    );
  }
}

class _DestinationStep extends ConsumerWidget {
  final String? selectedId;
  final ValueChanged<String> onSelected;
  final VoidCallback onCreatePersonal;
  final VoidCallback? onNext;

  const _DestinationStep({
    required this.selectedId,
    required this.onSelected,
    required this.onCreatePersonal,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final groupsAsync = ref.watch(groupsProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'scanner_setup_dest_title'.tr(),
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text('scanner_setup_dest_body'.tr(), style: theme.textTheme.bodyMedium),
        const SizedBox(height: 12),
        Expanded(
          child: groupsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text('$e'),
            data: (groups) {
              final list = groups.where((g) => !g.isArchived).toList();
              if (selectedId == null && list.isNotEmpty) {
                final pick =
                    list.where((g) => g.isPersonal).firstOrNull ?? list.first;
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  onSelected(pick.id);
                });
              }
              if (list.isEmpty) {
                return Center(
                  child: FilledButton.icon(
                    onPressed: onCreatePersonal,
                    icon: const Icon(Icons.add),
                    label: Text('scanner_create_personal'.tr()),
                  ),
                );
              }
              return ListView(
                children: [
                  ScannerGroupPicker(
                    groups: list,
                    selectedId: selectedId,
                    onSelected: onSelected,
                  ),
                  TextButton.icon(
                    onPressed: onCreatePersonal,
                    icon: const Icon(Icons.add),
                    label: Text('scanner_create_personal'.tr()),
                  ),
                ],
              );
            },
          ),
        ),
        FilledButton(
          onPressed: onNext,
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
          child: Text('scanner_setup_continue'.tr()),
        ),
      ],
    );
  }
}

class _AiStep extends ConsumerWidget {
  final bool categorize;
  final String aiMode;
  final ValueChanged<bool> onCategorize;
  final ValueChanged<String> onAiMode;
  final VoidCallback onNext;

  const _AiStep({
    required this.categorize,
    required this.aiMode,
    required this.onCategorize,
    required this.onAiMode,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final settings = ref.watch(hisabSettingsProvidersProvider);
    final provider = settings?.controller.get(receiptAiProviderSettingDef);
    final apiKey = provider == 'openai'
        ? settings?.controller.get(openaiApiKeySettingDef)
        : settings?.controller.get(geminiApiKeySettingDef);
    final hasCloudKey = apiKey is String && apiKey.trim().isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'scanner_setup_ai_title'.tr(),
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text('scanner_setup_ai_body'.tr(), style: theme.textTheme.bodyMedium),
        SwitchListTile.adaptive(
          value: categorize,
          onChanged: onCategorize,
          title: Text('scanner_categorize_enabled'.tr()),
          subtitle: Text('scanner_categorize_enabled_subtitle'.tr()),
        ),
        RadioListTile<String>(
          value: 'off',
          groupValue: aiMode,
          onChanged: (v) => onAiMode(v ?? 'off'),
          title: Text('scanner_ai_mode_off'.tr()),
        ),
        RadioListTile<String>(
          value: 'nano',
          groupValue: aiMode,
          onChanged: (v) => onAiMode(v ?? 'off'),
          title: Text('scanner_ai_mode_nano'.tr()),
        ),
        RadioListTile<String>(
          value: 'cloud',
          groupValue: aiMode,
          onChanged: (v) => onAiMode(v ?? 'off'),
          title: Text('scanner_ai_mode_cloud'.tr()),
          subtitle: Text(
            hasCloudKey
                ? 'scanner_ai_cloud_privacy'.tr()
                : 'scanner_ai_cloud_needs_key'.tr(),
          ),
        ),
        const Spacer(),
        FilledButton(
          onPressed: onNext,
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
          child: Text('scanner_setup_continue'.tr()),
        ),
      ],
    );
  }
}

class _DoneStep extends StatelessWidget {
  final VoidCallback onFinish;

  const _DoneStep({required this.onFinish});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
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
        Text('scanner_setup_done_ready'.tr(), style: theme.textTheme.bodyLarge),
        const Spacer(),
        FilledButton(
          onPressed: onFinish,
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
          child: Text('scanner_setup_finish'.tr()),
        ),
      ],
    );
  }
}
