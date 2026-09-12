import 'dart:async';

import 'package:currency_picker/currency_picker.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';
import 'package:flutter_logging_service/flutter_logging_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_settings_framework/flutter_settings_framework.dart';
import 'package:flutter_settings_framework/safaeh.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:flutter/services.dart';

import '../../../core/navigation/route_paths.dart';
import '../../../core/database/database_providers.dart';
import '../../../core/layout/layout_breakpoints.dart';
import '../../../core/layout/responsive_sheet.dart';
import '../../../core/receipt/receipt_scan_capability.dart';
import '../../../core/settings/providers/settings_framework_providers.dart';
import '../../../core/settings/settings_definitions.dart';
import '../../../core/utils/currency_helpers.dart';
import '../../../core/widgets/toast.dart';
import '../../transaction_scanner/pages/scanner_hub_page.dart';
import '../backup_ui.dart';
import '../backup_wipe.dart';
import '../widgets/logs_viewer_dialog.dart';
import '../widgets/setting_tile_helper.dart';
import '../widgets/apply_setting.dart';

/// Local preferences, backups, and on-device scanner settings.
class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  bool _searchOpen = false;
  String? _focusedSetting;
  final _scrollController = ScrollController();
  final _settingAnchors = <String, GlobalKey>{};

  GlobalKey _anchorFor(String key) =>
      _settingAnchors.putIfAbsent(key, GlobalKey.new);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final uri = GoRouter.maybeOf(
        context,
      )?.routerDelegate.currentConfiguration.uri;
      final focus = uri?.queryParameters[RoutePaths.settingsFocusParam];
      if (focus == null || focus.isEmpty) return;
      setState(() => _focusedSetting = focus);
      // Focus links are one-shot, so browser history does not retain a stale
      // query after the target has been shown.
      context.go(RoutePaths.settings);
      unawaited(_scrollToFocusedSetting());
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _scrollToFocusedSetting() async {
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;
    await Future<void>.delayed(const Duration(milliseconds: 80));
    if (!mounted || !_scrollController.hasClients) return;
    final target = _settingAnchors[_focusedSetting]?.currentContext;
    if (target != null) {
      await Scrollable.ensureVisible(
        target,
        alignment: 0.2,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
      );
      return;
    }
    await _scrollController.animateTo(
      _scrollController.position.maxScrollExtent,
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
    );
  }

  SettingsProviders? get _settings => ref.read(hisabSettingsProvidersProvider);

  Widget _section(String title, IconData icon, List<Widget> children) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        initiallyExpanded: true,
        leading: Icon(icon),
        title: Text(title),
        children: children,
      ),
    );
  }

  Widget _enumTile(SettingsProviders settings, EnumSetting definition) {
    final value = ref.watch(settings.provider(definition));
    return EnumSettingsTile.fromSetting(
      setting: definition,
      title: definition.titleKey.tr(),
      subtitle: definition.subtitleKey?.tr(),
      value: value,
      labelBuilder: (option) =>
          (definition.optionLabels?[option] ?? option).tr(),
      onChanged: (next) => applySetting(ref, settings, definition, next),
    );
  }

  Widget _colorTile(SettingsProviders settings) {
    final value = ref.watch(settings.provider(themeColorSettingDef));
    return ColorSettingsTile.fromSetting(
      setting: themeColorSettingDef,
      title: themeColorSettingDef.titleKey.tr(),
      value: value,
      onChanged: (next) =>
          applySetting(ref, settings, themeColorSettingDef, next),
    );
  }

  Widget _favoriteCurrenciesTile(
    BuildContext context,
    SettingsProviders settings,
  ) {
    final stored = ref.watch(settings.provider(favoriteCurrenciesSettingDef));
    final effective = CurrencyHelpers.getEffectiveFavorites(stored);
    final labels = effective
        .map((code) {
          final currency = CurrencyHelpers.fromCode(code);
          return currency == null ? code : CurrencyHelpers.shortLabel(currency);
        })
        .join(', ');
    final isCustom = stored.trim().isNotEmpty;
    return KeyedSubtree(
      key: _anchorFor(favoriteCurrenciesSettingDef.key),
      child: ListTile(
        leading: const Icon(Icons.star_outline),
        title: Text('favorite_currencies'.tr()),
        subtitle: Text(
          isCustom ? labels : '${'default'.tr()}: $labels',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: isCustom
            ? IconButton(
                icon: const Icon(Icons.restore),
                tooltip: 'reset_to_default'.tr(),
                onPressed: () => applySetting(
                  ref,
                  settings,
                  favoriteCurrenciesSettingDef,
                  '',
                ),
              )
            : null,
        onTap: () => _showFavoriteCurrenciesEditor(context, settings),
      ),
    );
  }

  Widget _displayCurrencyTile(
    BuildContext context,
    SettingsProviders settings,
  ) {
    final stored = ref
        .watch(settings.provider(displayCurrencySettingDef))
        .trim();
    final currency = CurrencyHelpers.fromCode(stored);
    final label = stored.isEmpty
        ? 'display_currency_none'.tr()
        : currency == null
        ? stored
        : CurrencyHelpers.shortLabel(currency);
    return KeyedSubtree(
      key: _anchorFor(displayCurrencySettingDef.key),
      child: ListTile(
        leading: const Icon(Icons.visibility_outlined),
        title: Text('display_currency'.tr()),
        subtitle: Text(
          'display_currency_hint'.tr(),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: stored.isEmpty
            ? null
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.clear),
                    tooltip: 'display_currency_none'.tr(),
                    onPressed: () => applySetting(
                      ref,
                      settings,
                      displayCurrencySettingDef,
                      '',
                    ),
                  ),
                ],
              ),
        onTap: () => _showDisplayCurrencyPicker(context, settings),
      ),
    );
  }

  void _showDisplayCurrencyPicker(
    BuildContext context,
    SettingsProviders settings,
  ) {
    CurrencyHelpers.showPicker(
      context: context,
      title: 'display_currency'.tr(),
      centerInFullViewport: false,
      favorite: CurrencyHelpers.getEffectiveFavorites(
        ref.read(settings.provider(favoriteCurrenciesSettingDef)),
      ),
      onSelect: (currency) =>
          applySetting(ref, settings, displayCurrencySettingDef, currency.code),
    );
  }

  void _showFavoriteCurrenciesEditor(
    BuildContext context,
    SettingsProviders settings,
  ) {
    final initial = CurrencyHelpers.getEffectiveFavorites(
      ref.read(settings.provider(favoriteCurrenciesSettingDef)),
    );
    showResponsiveSheet<void>(
      context: context,
      title: 'favorite_currencies'.tr(),
      maxHeight: MediaQuery.sizeOf(context).height * 0.75,
      isScrollControlled: true,
      centerInFullViewport: false,
      child: _FavoriteCurrenciesSheet(
        initial: initial,
        onSave: (codes) => applySetting(
          ref,
          settings,
          favoriteCurrenciesSettingDef,
          CurrencyHelpers.encodeFavorites(codes),
        ),
      ),
    );
  }

  Widget _action(
    ActionSetting definition,
    VoidCallback onTap, {
    bool destructive = false,
  }) {
    return ActionSettingsTile(
      leading: Icon(definition.icon),
      title: Text(definition.titleKey.tr()),
      subtitle: definition.subtitleKey == null
          ? null
          : Text(definition.subtitleKey!.tr()),
      isDangerous: destructive,
      onTap: onTap,
    );
  }

  Future<void> _resetSettings() async {
    final settings = _settings;
    if (settings == null) return;
    await settings.controller.resetAll();
    if (mounted) context.showSuccess('settings_reset_success'.tr());
  }

  Future<void> _deleteLocalData() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('delete_local_data'.tr()),
        content: Text('delete_local_data_description'.tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('cancel'.tr()),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('delete'.tr()),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await wipeLocalDataTables(ref.read(powerSyncDatabaseProvider));
    if (mounted) context.showSuccess('delete_local_data_success'.tr());
  }

  Future<void> _showLogs() async {
    final content = await LoggingService.getLogContent(maxLines: 500);
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        child: SizedBox(
          width: 700,
          height: 600,
          child: LogsViewerDialog(
            content: content,
            onCopy: () => Clipboard.setData(ClipboardData(text: content)),
            onClear: LoggingService.clearLogs,
            onReportIssue: () =>
                Clipboard.setData(ClipboardData(text: content)),
            onClose: () => Navigator.pop(context),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = _settings;
    if (settings == null) {
      return Scaffold(
        appBar: AppBar(title: Text('settings'.tr())),
        body: Center(child: Text('settings_unavailable'.tr())),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('settings'.tr()),
        actions: [
          IconButton(
            key: const ValueKey('safaeh_settings_search_button'),
            tooltip: 'search'.tr(),
            icon: const Icon(Icons.search),
            onPressed: () => setState(() => _searchOpen = true),
          ),
        ],
      ),
      body: Stack(
        children: [
          ListView(
            controller: _scrollController,
            padding: const EdgeInsets.symmetric(vertical: 8),
            children: [
              _section('appearance'.tr(), Icons.palette, [
                _enumTile(settings, themeModeSettingDef),
                _enumTile(settings, themeSchemeSettingDef),
                _colorTile(settings),
                _enumTile(settings, languageSettingDef),
                _enumTile(settings, fontSizeScaleSettingDef),
                _favoriteCurrenciesTile(context, settings),
                _displayCurrencyTile(context, settings),
                _enumTile(settings, receiptScanModeSettingDef),
                buildBoolSettingTile(ref, settings, use24HourFormatSettingDef),
                buildBoolSettingTile(ref, settings, subtleAccentsSettingDef),
                buildBoolSettingTile(
                  ref,
                  settings,
                  extraAnimationsEnabledSettingDef,
                ),
              ]),
              _section('functional_settings'.tr(), Icons.tune, [
                buildBoolSettingTile(
                  ref,
                  settings,
                  expenseFormFullFeaturesSettingDef,
                ),
                buildBoolSettingTile(
                  ref,
                  settings,
                  expenseFormExpandDescriptionSettingDef,
                ),
                buildBoolSettingTile(
                  ref,
                  settings,
                  expenseFormExpandBillBreakdownSettingDef,
                ),
              ]),
              _section('data_backup'.tr(), Icons.storage, [
                _action(
                  actionExportDataSettingDef,
                  () => runBackupExportFlow(context, ref),
                ),
                _action(
                  actionImportDataSettingDef,
                  () => runBackupImportFlow(context, ref),
                ),
              ]),
              _section(
                'scanner_section'.tr(),
                Icons.document_scanner_outlined,
                [
                  buildBoolSettingTile(ref, settings, scannerEnabledSettingDef),
                  buildBoolSettingTile(
                    ref,
                    settings,
                    scannerCategorizeEnabledSettingDef,
                  ),
                  _action(
                    actionScannerHubSettingDef,
                    () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const ScannerHubPage(),
                      ),
                    ),
                  ),
                  if (!ReceiptScanCapability.supportsOcr)
                    ListTile(
                      leading: const Icon(Icons.info_outline),
                      title: Text('receipt_scan_unavailable'.tr()),
                    ),
                ],
              ),
              _section('advanced'.tr(), Icons.build, [
                _action(
                  actionReturnToOnboardingSettingDef,
                  () => context.go(RoutePaths.onboarding),
                ),
                _action(actionViewLogsSettingDef, _showLogs),
                _action(actionResetAllSettingsSettingDef, _resetSettings),
                _action(
                  actionDeleteLocalDataSettingDef,
                  _deleteLocalData,
                  destructive: true,
                ),
              ]),
              _section('about'.tr(), Icons.info, [
                _action(
                  actionPrivacyPolicySettingDef,
                  () => context.push(RoutePaths.privacyPolicy),
                ),
                _action(
                  actionLicensesSettingDef,
                  () => showLicensePage(context: context),
                ),
                FutureBuilder<PackageInfo>(
                  future: PackageInfo.fromPlatform(),
                  builder: (context, snapshot) => ListTile(
                    leading: Icon(actionVersionSettingDef.icon),
                    title: Text(actionVersionSettingDef.titleKey.tr()),
                    subtitle: Text(snapshot.data?.version ?? '—'),
                  ),
                ),
              ]),
              if (_focusedSetting != null)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    '${'settings'.tr()}: ${_focusedSetting!}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
            ],
          ),
          SafaehSettingsSearchOverlay(
            isOpen: _searchOpen,
            onClose: () => setState(() => _searchOpen = false),
            searchIndex: settings.searchIndex,
            onResultSelected: (result) {
              setState(() {
                _searchOpen = false;
                _focusedSetting = result.setting.key;
              });
            },
            sectionTitleBuilder: (key) => key.tr(),
            settingTitleBuilder: (setting) => setting.titleKey.tr(),
            settingSubtitleBuilder: (setting) => setting.subtitleKey?.tr(),
            showResultSubtitles: true,
          ),
        ],
      ),
    );
  }
}

class _FavoriteCurrenciesSheet extends StatefulWidget {
  const _FavoriteCurrenciesSheet({required this.initial, required this.onSave});

  final List<String> initial;
  final ValueChanged<List<String>> onSave;

  @override
  State<_FavoriteCurrenciesSheet> createState() =>
      _FavoriteCurrenciesSheetState();
}

class _FavoriteCurrenciesSheetState extends State<_FavoriteCurrenciesSheet> {
  late List<String> _codes;

  @override
  void initState() {
    super.initState();
    _codes = List<String>.from(widget.initial);
  }

  void _addCurrency() {
    CurrencyHelpers.showPicker(
      context: context,
      centerInFullViewport: false,
      onSelect: (currency) {
        if (!_codes.contains(currency.code)) {
          setState(() => _codes.add(currency.code));
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            title: Text('favorite_currencies'.tr()),
            trailing: IconButton(
              icon: const Icon(Icons.add),
              tooltip: 'add_currency'.tr(),
              onPressed: _addCurrency,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'favorite_currencies_hint'.tr(),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(height: 8),
          if (_codes.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Text('favorite_currencies_empty'.tr()),
            )
          else
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * 0.5,
              ),
              child: ReorderableListView.builder(
                itemCount: _codes.length,
                shrinkWrap: true,
                onReorder: (oldIndex, newIndex) {
                  setState(() {
                    if (newIndex > oldIndex) newIndex--;
                    final code = _codes.removeAt(oldIndex);
                    _codes.insert(newIndex, code);
                  });
                },
                itemBuilder: (context, index) {
                  final code = _codes[index];
                  final currency = CurrencyHelpers.fromCode(code);
                  final flag = currency == null
                      ? ''
                      : CurrencyUtils.currencyToEmoji(currency);
                  return ListTile(
                    key: ValueKey(code),
                    leading: Text(flag, style: const TextStyle(fontSize: 24)),
                    title: Text('$code - ${currency?.name ?? code}'),
                    trailing: IconButton(
                      icon: Icon(
                        Icons.remove_circle_outline,
                        color: colorScheme.error,
                      ),
                      onPressed: () => setState(() => _codes.removeAt(index)),
                    ),
                  );
                },
              ),
            ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              16,
              8,
              16,
              16 + MediaQuery.paddingOf(context).bottom,
            ),
            child: Row(
              children: [
                if (!LayoutBreakpoints.isTabletOrWider(context)) ...[
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text('cancel'.tr()),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: FilledButton(
                    onPressed: () {
                      if (!listEquals(_codes, widget.initial)) {
                        widget.onSave(_codes);
                      }
                      Navigator.pop(context);
                    },
                    child: Text('done'.tr()),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
