import 'dart:async';
import 'package:currency_picker/currency_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb, listEquals;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_logging_service/flutter_logging_service.dart';
import 'package:flutter_settings_framework/flutter_settings_framework.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:go_router/go_router.dart';
import 'package:feedback/feedback.dart';
import 'package:flex_color_picker/flex_color_picker.dart';

import '../../../core/auth/auth_providers.dart';
import '../../../core/log_web.dart';
import '../../../core/constants/app_config.dart';
import '../../../core/layout/content_aligned_app_bar.dart';
import '../../../core/layout/constrained_content.dart';
import '../../../core/layout/layout_breakpoints.dart';
import '../../../core/layout/responsive_sheet.dart';
import '../../../core/constants/supabase_config.dart';
import '../../../core/database/database_providers.dart';
import '../../../core/navigation/route_paths.dart';
import '../../../core/platform/network_image_decode.dart';
import '../../../core/receipt/receipt_scan_capability.dart';
import '../../../core/update/update_check_providers.dart';
import '../../../core/services/delete_my_data_service.dart';
import '../../../core/services/github_user_client.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/utils/currency_helpers.dart';
import '../settings_definitions.dart';
import '../providers/settings_framework_providers.dart';
import '../backup_ui.dart';
import '../backup_wipe.dart';
import '../feedback_handler.dart';
import '../widgets/logs_viewer_dialog.dart';
import '../../../core/theme/flex_theme_builder.dart'
    show flexSchemeOptionIds, primaryColorForSchemeId;
import '../account_mode_actions.dart';
import '../widgets/apply_setting.dart';
import '../widgets/setting_tile_helper.dart';
import '../../transaction_scanner/pages/scanner_hub_page.dart';
import '../../transaction_scanner/providers/scanner_providers.dart';
import '../../transaction_scanner/services/notification_bridge.dart';
import '../sections/settings_functional_section.dart';
import '../sections/settings_privacy_section.dart';
import '../sections/settings_advanced_section.dart';
import '../sections/settings_data_backup_section.dart';
import '../sections/settings_receipt_ai_section.dart';
import '../../../core/widgets/page_section_index.dart';
import '../../../core/widgets/participant_avatar.dart';
import '../../../core/widgets/sheet_helpers.dart';
import '../../../core/widgets/sheet_option_tile.dart';
import '../../../core/widgets/shell_menu_button.dart';
import '../../../core/widgets/sync_status_icon.dart';
import '../../../core/widgets/toast.dart';
import '../../../domain/domain.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  final Map<String, bool> _sectionExpanded = {};
  final _scrollController = ScrollController();
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();
  final _anchors = SettingAnchorRegistry();
  final Map<String, GlobalKey> _sectionKeys = {
    'account': GlobalKey(),
    'appearance': GlobalKey(),
    'functional': GlobalKey(),
    'data_backup': GlobalKey(),
    'receipt_ai': GlobalKey(),
    'scanner': GlobalKey(),
    'privacy': GlobalKey(),
    'advanced': GlobalKey(),
    'about': GlobalKey(),
  };
  final Map<String, double> _sectionOffsets = {};
  String? _activeSectionId;
  bool _programmaticScroll = false;
  int _scrollGeneration = 0;
  String _searchQuery = '';

  static const List<Locale> _supportedLocales = [Locale('en'), Locale('ar')];

  static String _localeDisplayName(Locale locale) {
    switch (locale.languageCode) {
      case 'ar':
        return 'language_name_ar'.tr();
      case 'en':
      default:
        return 'language_name_en'.tr();
    }
  }

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    _scrollController.dispose();
    _anchors.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchController.text.trim();
    if (query != _searchQuery) setState(() => _searchQuery = query);
  }

  bool _isExpanded(SettingSection section) {
    return _sectionExpanded[section.key] ?? section.initiallyExpanded;
  }

  void _onExpansionChanged(String key, bool expanded) {
    setState(() => _sectionExpanded[key] = expanded);
  }

  List<PageSectionIndexEntry> _indexEntries({
    required bool showReceiptAi,
    required bool showScanner,
  }) {
    final sections = <SettingSection>[
      accountSection,
      appearanceSection,
      functionalSection,
      dataBackupSection,
      if (showReceiptAi) receiptAiSection,
      if (showScanner) scannerSection,
      privacySection,
      advancedSection,
      aboutSection,
    ];
    return [
      for (final section in sections)
        PageSectionIndexEntry(
          id: section.key,
          label: section.titleKey.tr(),
          key: _sectionKeys[section.key]!,
          icon: section.icon,
        ),
    ];
  }

  void _rememberSectionOffset(String id, GlobalKey key) {
    final ctx = key.currentContext;
    if (ctx == null || !_scrollController.hasClients) return;
    final box = ctx.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return;
    final scrollable = Scrollable.maybeOf(ctx);
    if (scrollable == null) return;
    final scrollBox = scrollable.context.findRenderObject();
    if (scrollBox is! RenderBox) return;
    final local = box.localToGlobal(Offset.zero, ancestor: scrollBox);
    _sectionOffsets[id] = (local.dy + scrollable.position.pixels).clamp(
      0.0,
      double.infinity,
    );
  }

  void _captureVisibleOffsets(List<PageSectionIndexEntry> entries) {
    for (final entry in entries) {
      _rememberSectionOffset(entry.id, entry.key);
    }
  }

  Future<void> _jumpToSection(PageSectionIndexEntry entry) async {
    final token = ++_scrollGeneration;
    final section = _sectionByKey(entry.id);
    final wasCollapsed =
        section != null && !(_sectionExpanded[entry.id] ?? section.initiallyExpanded);

    setState(() {
      _activeSectionId = entry.id;
      _programmaticScroll = true;
      _sectionExpanded[entry.id] = true;
    });

    // Let CardSettingsSection AnimatedSize (~200ms) finish before measuring.
    if (wasCollapsed) {
      await Future<void>.delayed(const Duration(milliseconds: 220));
    }
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted || token != _scrollGeneration) return;

    _rememberSectionOffset(entry.id, entry.key);
    final known = entry.id == 'account' ? 0.0 : _sectionOffsets[entry.id];
    await scrollToPageSection(
      entry.key,
      controller: _scrollController,
      knownOffset: known,
    );
    if (!mounted || token != _scrollGeneration) return;

    _captureVisibleOffsets(_indexEntries(
      showReceiptAi: ReceiptScanCapability.showReceiptAiSettings,
      showScanner: scannerAvailable,
    ));
    // Hold scroll-spy until ensureVisible settles so the index doesn't flash.
    await Future<void>.delayed(const Duration(milliseconds: 320));
    if (mounted && token == _scrollGeneration) {
      setState(() {
        _activeSectionId = entry.id;
        _programmaticScroll = false;
      });
    }
  }

  SettingSection? _sectionByKey(String key) {
    for (final s in allSections) {
      if (s.key == key) return s;
    }
    return null;
  }

  bool _onScroll(
    ScrollNotification notification,
    List<PageSectionIndexEntry> entries,
  ) {
    if (notification is ScrollUpdateNotification ||
        notification is ScrollEndNotification) {
      _captureVisibleOffsets(entries);
    }
    if (_programmaticScroll) return false;
    if (notification is! ScrollUpdateNotification &&
        notification is! ScrollEndNotification) {
      return false;
    }
    final scrollCtx = notification.context;
    if (scrollCtx == null) return false;
    final next = activePageSectionId(
      entries: entries,
      scrollContext: scrollCtx,
    );
    if (next != null && next != _activeSectionId) {
      setState(() => _activeSectionId = next);
    }
    return false;
  }

  /// Settings that are searchable but live inside sheets/hubs: jump to the
  /// nearest on-page tile instead of a missing anchor.
  static const _searchJumpAliases = <String, String>{
    'theme_color': 'theme_scheme',
    'scanner_location_enabled': 'scanner_enabled',
    'scanner_notify_on_capture': 'action_scanner_hub',
    'gemini_api_key': 'receipt_ai_provider',
    'openai_api_key': 'receipt_ai_provider',
    'receipt_ai_provider': 'receipt_scan_mode',
  };

  bool _includeSearchResult(SearchResult result) {
    final section = result.setting.section;
    if (section == null || !settingsPageSectionKeys.contains(section)) {
      return false;
    }
    if (section == 'home_list') return false;
    if (section == 'receipt_ai' &&
        !ReceiptScanCapability.showReceiptAiSettings) {
      return false;
    }
    if (section == 'scanner' && !scannerAvailable) return false;
    return true;
  }

  Future<void> _onSearchResultSelected(SearchResult result) async {
    final setting = result.setting;
    final sectionKey = setting.section;
    final jumpKey = _searchJumpAliases[setting.key] ?? setting.key;
    final token = ++_scrollGeneration;
    setState(() {
      _searchController.clear();
      _searchQuery = '';
      _programmaticScroll = true;
      if (sectionKey != null) {
        _activeSectionId = sectionKey;
        _sectionExpanded[sectionKey] = true;
      }
    });
    _searchFocusNode.unfocus();

    await Future<void>.delayed(const Duration(milliseconds: 220));
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted || token != _scrollGeneration) return;

    if (sectionKey != null) {
      final sectionGlobalKey = _sectionKeys[sectionKey];
      if (sectionGlobalKey != null) {
        _rememberSectionOffset(sectionKey, sectionGlobalKey);
      }
    }
    final sectionOffset =
        sectionKey != null ? _sectionOffsets[sectionKey] : null;

    // Prefer section scroll first so the tile is built, then highlight.
    if (sectionKey != null) {
      final sectionGlobalKey = _sectionKeys[sectionKey];
      if (sectionGlobalKey != null) {
        await scrollToPageSection(
          sectionGlobalKey,
          controller: _scrollController,
          knownOffset: sectionOffset,
        );
      }
    }
    if (!mounted || token != _scrollGeneration) return;

    await _anchors.scrollTo(
      jumpKey,
      controller: _scrollController,
      knownOffset: sectionOffset,
    );
    if (_anchors.keyFor(jumpKey).currentContext == null) {
      await Future<void>.delayed(const Duration(milliseconds: 80));
      if (!mounted || token != _scrollGeneration) return;
      await _anchors.scrollTo(
        jumpKey,
        controller: _scrollController,
        knownOffset: sectionOffset,
      );
    }
    await Future<void>.delayed(const Duration(milliseconds: 320));
    if (mounted && token == _scrollGeneration) {
      setState(() => _programmaticScroll = false);
    }
  }

  bool _canShowSideIndex(BuildContext context, double contentAreaWidth) {
    return LayoutBreakpoints.canShowContentAside(context, contentAreaWidth);
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(hisabSettingsProvidersProvider);

    if (settings == null) {
      return LayoutBuilder(
        builder: (context, layoutConstraints) {
          return Scaffold(
            appBar: ContentAlignedAppBar(
              contentAreaWidth: layoutConstraints.maxWidth,
              leadingWidth: ShellAppBarLeading.widthFor(context),
              leading: const ShellAppBarLeading(fallback: SyncStatusChip()),
              title: Text('settings'.tr()),
              actions: [
                if (ShellAppBarLeading.syncInActions(context))
                  const SyncStatusChip(),
              ],
            ),
            body: Center(child: Text('settings_unavailable'.tr())),
          );
        },
      );
    }

    final showReceiptAi = ReceiptScanCapability.showReceiptAiSettings;
    final showScanner = scannerAvailable;
    final entries = _indexEntries(
      showReceiptAi: showReceiptAi,
      showScanner: showScanner,
    );
    final entryIds = {for (final e in entries) e.id};
    final activeId =
        (_activeSectionId != null && entryIds.contains(_activeSectionId))
            ? _activeSectionId
            : entries.firstOrNull?.id;
    final hasSearch = _searchQuery.isNotEmpty;

    return LayoutBuilder(
      builder: (context, layoutConstraints) {
        final showSideIndex =
            !hasSearch && _canShowSideIndex(context, layoutConstraints.maxWidth);
        return Scaffold(
          appBar: ContentAlignedAppBar(
            contentAreaWidth: layoutConstraints.maxWidth,
            leadingWidth: ShellAppBarLeading.widthFor(context),
            leading: const ShellAppBarLeading(fallback: SyncStatusChip()),
            title: Text('settings'.tr()),
            actions: [
              if (ShellAppBarLeading.syncInActions(context))
                const SyncStatusChip(),
            ],
          ),
          body: ConstrainedContent(
            aside: showSideIndex
                ? PageSectionIndex(
                    entries: entries,
                    activeId: activeId,
                    onSelect: _jumpToSection,
                  )
                : null,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                  child: SettingsSearchBar(
                    mode: SettingsSearchBarMode.persistent,
                    hintText: 'settings_search_hint'.tr(),
                    controller: _searchController,
                    focusNode: _searchFocusNode,
                    onChanged: (_) {},
                  ),
                ),
                Expanded(
                  child: Stack(
                    children: [
                      NotificationListener<ScrollNotification>(
                        onNotification: (n) => _onScroll(n, entries),
                        child: hasSearch
                            ? ListView(
                                padding: const EdgeInsets.only(bottom: 32),
                                children: _buildSearchBody(settings),
                              )
                            : ListView(
                                key: const PageStorageKey<String>(
                                  'settings_list',
                                ),
                                controller: _scrollController,
                                // Keep section cards mounted so index jumps
                                // don't need multi-step probes.
                                cacheExtent: 2400,
                                padding: EdgeInsets.only(
                                  bottom: showSideIndex ? 32 : 88,
                                ),
                                children: _buildBrowseChildren(
                                  context,
                                  ref,
                                  settings,
                                  showReceiptAi: showReceiptAi,
                                  showScanner: showScanner,
                                ),
                              ),
                      ),
                      if (!hasSearch && !showSideIndex)
                        PageSectionIndexOverlay(
                          entries: entries,
                          activeId: activeId,
                          onSelect: _jumpToSection,
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  List<Widget> _buildBrowseChildren(
    BuildContext context,
    WidgetRef ref,
    SettingsProviders settings, {
    required bool showReceiptAi,
    required bool showScanner,
  }) {
    return [
      _buildAccountSection(context, ref, settings),
      _buildSection(context, ref, settings, appearanceSection, [
        _anchors.wrap(
          languageSettingDef.key,
          _languageTile(context, ref, settings),
        ),
        _anchors.wrap(
          themeModeSettingDef.key,
          _themeModeTile(context, ref, settings),
        ),
        _anchors.wrap(
          themeSchemeSettingDef.key,
          _themeSchemeTile(context, ref, settings),
        ),
        buildBoolSettingTile(
          ref,
          settings,
          subtleAccentsSettingDef,
          anchors: _anchors,
        ),
        buildBoolSettingTile(
          ref,
          settings,
          extraAnimationsEnabledSettingDef,
          anchors: _anchors,
        ),
        _anchors.wrap(
          fontSizeScaleSettingDef.key,
          _fontSizeTile(context, ref, settings),
        ),
        _anchors.wrap(
          favoriteCurrenciesSettingDef.key,
          _favoriteCurrenciesTile(context, ref, settings),
        ),
        _anchors.wrap(
          displayCurrencySettingDef.key,
          _displayCurrencyTile(context, ref, settings),
        ),
        buildBoolSettingTile(
          ref,
          settings,
          use24HourFormatSettingDef,
          anchors: _anchors,
        ),
      ]),
      _buildSection(
        context,
        ref,
        settings,
        functionalSection,
        buildFunctionalSectionTiles(
          context,
          ref,
          settings,
          anchors: _anchors,
        ),
      ),
      _buildSection(
        context,
        ref,
        settings,
        dataBackupSection,
        buildDataBackupSectionTiles(
          context,
          ref,
          settings,
          localOnlyTile: _anchors.wrap(
            localOnlySettingDef.key,
            _buildLocalOnlyTile(context, ref, settings),
          ),
          onExport: () => runBackupExportFlow(context, ref),
          onImport: () => runBackupImportFlow(context, ref),
          anchors: _anchors,
        ),
      ),
      if (showReceiptAi)
        _buildSection(
          context,
          ref,
          settings,
          receiptAiSection,
          buildReceiptAiSectionTiles(
            context,
            ref,
            settings,
            ({
              required BuildContext context,
              required WidgetRef ref,
              required String titleKey,
              required String currentValue,
              required StringSetting settingDef,
            }) => _showApiKeyDialog(
              context: context,
              ref: ref,
              titleKey: titleKey,
              currentValue: currentValue,
              settingDef: settingDef,
            ),
            anchors: _anchors,
          ),
        ),
      if (showScanner)
        _buildSection(
          context,
          ref,
          settings,
          scannerSection,
          _buildScannerSectionTiles(context, ref, settings),
        ),
      _buildSection(
        context,
        ref,
        settings,
        privacySection,
        buildPrivacySectionTiles(
          context,
          ref,
          settings,
          anchors: _anchors,
        ),
      ),
      _buildSection(
        context,
        ref,
        settings,
        advancedSection,
        buildAdvancedSectionTiles(
          context,
          ref,
          settings,
          onReturnToOnboarding: () =>
              _resetToOnboarding(context, ref, settings),
          onViewLogs: () => _showLogsDialog(context),
          onResetAllSettings: () => _resetAllSettings(context, ref, settings),
          onDeleteLocalData: () => _showDeleteLocalData(context, ref),
          onDeleteCloudData: () => _showDeleteCloudData(context, ref),
          supabaseAvailable: supabaseConfigAvailable,
          isSignedIn: ref.watch(currentUserProvider) != null,
          anchors: _anchors,
        ),
      ),
      _buildAboutSection(context, ref, settings),
    ];
  }

  List<Widget> _buildSearchBody(SettingsProviders settings) {
    final results = ref
        .watch(settingsSearchResultsProvider(_searchQuery))
        .where(_includeSearchResult)
        .toList();
    if (results.isEmpty) {
      return [
        EmptySearchResults(
          query: _searchQuery,
          message: 'settings_search_empty'.tr(
            namedArgs: {'query': _searchQuery},
          ),
        ),
      ];
    }
    return buildSearchResultWidgets(
      results,
      tileBuilder: (setting) {
        final title = setting.titleKey.tr();
        final subtitle = setting.subtitleKey?.tr();
        return ListTile(
          leading: setting.icon != null ? Icon(setting.icon) : null,
          title: Text(title),
          subtitle: subtitle != null ? Text(subtitle) : null,
          trailing: const Icon(Icons.chevron_right),
        );
      },
      sectionTitleBuilder: (sectionKey) {
        final section = settings.registry.getSection(sectionKey);
        return (section?.titleKey ?? sectionKey).tr();
      },
      settingTitleBuilder: (setting) => setting.titleKey.tr(),
      onResultSelected: _onSearchResultSelected,
    );
  }

  Widget _buildAccountSection(
    BuildContext context,
    WidgetRef ref,
    SettingsProviders settings,
  ) {
    final profile = ref.watch(authUserProfileProvider).asData?.value;
    final colorScheme = Theme.of(context).colorScheme;
    final displayName =
        profile?.name ?? profile?.email ?? 'profile'.tr();

    return _buildSection(context, ref, settings, accountSection, [
      _anchors.wrap(
        actionOpenProfileSettingDef.key,
        ListTile(
          leading: profile != null
              ? ParticipantAvatar(
                  name: displayName,
                  avatarId: profile.avatarId,
                  initials: AccountModeActions.initials(
                    profile.name,
                    profile.email,
                  ),
                  backgroundColor: colorScheme.primaryContainer,
                  foregroundColor: colorScheme.onPrimaryContainer,
                )
              : CircleAvatar(
                  backgroundColor: colorScheme.primaryContainer,
                  child: Icon(
                    Icons.person_outline,
                    color: colorScheme.onPrimaryContainer,
                  ),
                ),
          title: Text('profile'.tr()),
          subtitle: Text('profile_settings_link_subtitle'.tr()),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.push(RoutePaths.profile),
        ),
      ),
    ]);
  }

  Widget _buildSection(
    BuildContext context,
    WidgetRef ref,
    SettingsProviders settings,
    SettingSection section,
    List<Widget> children,
  ) {
    final isExpanded = _isExpanded(section);
    final title = section.titleKey.tr();
    final icon = section.icon ?? Icons.settings;
    final sectionKey = _sectionKeys[section.key];
    final card = CardSettingsSection(
      title: title,
      icon: icon,
      sectionId: section.key,
      isExpanded: isExpanded,
      onExpansionChanged: (expanded) =>
          _onExpansionChanged(section.key, expanded),
      isLandscape: false,
      children: children,
    );
    if (sectionKey == null) return card;
    return KeyedSubtree(key: sectionKey, child: card);
  }

  static Future<void> _resetToOnboarding(
    BuildContext context,
    WidgetRef ref,
    SettingsProviders settings,
  ) async {
    final confirmed = await showConfirmSheet(
      context,
      title: 'return_to_onboarding'.tr(),
      content: 'return_to_onboarding_confirm'.tr(),
      confirmLabel: 'return_to_onboarding'.tr(),
      centerInFullViewport: false,
    );
    if (confirmed == true && context.mounted) {
      ref
          .read(settings.provider(onboardingCompletedSettingDef).notifier)
          .set(false);
      Log.info('Setting changed: ${onboardingCompletedSettingDef.key}=false');
      if (context.mounted) {
        context.go(RoutePaths.onboarding);
      }
    }
  }

  static Future<void> _resetAllSettings(
    BuildContext context,
    WidgetRef ref,
    SettingsProviders settings,
  ) async {
    final confirmed = await showConfirmSheet(
      context,
      title: 'reset_all_settings'.tr(),
      content: 'reset_all_settings_confirm'.tr(),
      confirmLabel: 'reset_all_settings'.tr(),
      centerInFullViewport: false,
    );
    if (confirmed != true || !context.mounted) return;
    await settings.controller.resetAll();
    Log.info('Setting changed: reset_all');
    if (!context.mounted) return;
    // _LocaleSync handles locale sync automatically via languageProvider
    context.showSuccess('reset_all_settings_done'.tr());
  }

  static Future<void> _showDeleteLocalData(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final counts = await _getLocalDataCounts(ref);
    if (!context.mounted) return;
    final confirmed = await showResponsiveSheet<bool>(
      context: context,
      title: 'delete_local_data'.tr(),
      maxHeight: MediaQuery.of(context).size.height * 0.75,
      isScrollControlled: true,
      centerInFullViewport: false,
      child: _DeleteLocalDataDialogContent(
        groups: counts.groups,
        participants: counts.participants,
        expenses: counts.expenses,
        expenseTags: counts.expenseTags,
        groupInvites: counts.groupInvites,
      ),
    );
    if (confirmed == true && context.mounted) {
      try {
        final db = ref.read(powerSyncDatabaseProvider);
        await wipeLocalDataTables(db);
        final settings = ref.read(hisabSettingsProvidersProvider);
        if (settings != null) {
          await ref
              .read(settings.provider(homeListCustomOrderSettingDef).notifier)
              .set('');
          await ref
              .read(settings.provider(homeListPinnedIdsSettingDef).notifier)
              .set('');
        }
        Log.info('Local data deleted');
        if (context.mounted) {
          if (settings != null) {
            ref
                .read(settings.provider(onboardingCompletedSettingDef).notifier)
                .set(false);
            Log.info(
              'Setting changed: ${onboardingCompletedSettingDef.key}=false',
            );
          }
          context.showSuccess('delete_local_data_done'.tr());
          context.go(RoutePaths.onboarding);
        }
      } catch (e, st) {
        Log.warning('Delete local data failed', error: e, stackTrace: st);
        if (context.mounted) {
          context.showError('delete_local_data_failed'.tr());
        }
      }
    }
  }

  static Future<
    ({
      int groups,
      int participants,
      int expenses,
      int expenseTags,
      int groupInvites,
    })
  >
  _getLocalDataCounts(WidgetRef ref) async {
    final db = ref.read(powerSyncDatabaseProvider);
    final groupRows = await db.getAll('SELECT COUNT(*) as cnt FROM groups');
    final participantRows = await db.getAll(
      'SELECT COUNT(*) as cnt FROM participants',
    );
    final expenseRows = await db.getAll('SELECT COUNT(*) as cnt FROM expenses');
    final tagRows = await db.getAll('SELECT COUNT(*) as cnt FROM expense_tags');
    final inviteRows = await db.getAll(
      'SELECT COUNT(*) as cnt FROM group_invites',
    );
    int fromFirst(List<dynamic> rows) {
      if (rows.isEmpty) return 0;
      final r = rows.first;
      if (r is Map) {
        final v = r['cnt'];
        if (v == null) return 0;
        if (v is int) return v;
        if (v is num) return v.toInt();
        return int.tryParse(v.toString()) ?? 0;
      }
      return 0;
    }

    return (
      groups: fromFirst(groupRows),
      participants: fromFirst(participantRows),
      expenses: fromFirst(expenseRows),
      expenseTags: fromFirst(tagRows),
      groupInvites: fromFirst(inviteRows),
    );
  }

  static Future<void> _showDeleteCloudData(
    BuildContext context,
    WidgetRef ref,
  ) async {
    try {
      final preview = await ref
          .read(deleteMyDataServiceProvider)
          .getDeleteMyDataPreview();
      if (!context.mounted) return;
      final result = await showResponsiveSheet<bool?>(
        context: context,
        title: 'delete_cloud_data'.tr(),
        maxHeight: MediaQuery.of(context).size.height * 0.75,
        isScrollControlled: true,
        centerInFullViewport: false,
        child: _DeleteCloudDataDialogContent(preview: preview),
      );
      // result: null = cancel, true = alsoDeleteLocal, false = cloud only
      if (result == null || !context.mounted) return;
      final alsoDeleteLocal = result;
      await ref.read(deleteMyDataServiceProvider).deleteMyData();
      if (!context.mounted) return;
      await ref.read(notificationServiceProvider.notifier).unregisterToken();
      await ref.read(authServiceProvider).signOut();
      if (!context.mounted) return;
      if (alsoDeleteLocal) {
        final db = ref.read(powerSyncDatabaseProvider);
        await wipeLocalDataTables(db);
        final settings = ref.read(hisabSettingsProvidersProvider);
        if (settings != null) {
          await ref
              .read(settings.provider(homeListCustomOrderSettingDef).notifier)
              .set('');
          await ref
              .read(settings.provider(homeListPinnedIdsSettingDef).notifier)
              .set('');
          ref
              .read(settings.provider(onboardingCompletedSettingDef).notifier)
              .set(false);
          Log.info(
            'Setting changed: ${onboardingCompletedSettingDef.key}=false',
          );
        }
        if (context.mounted) {
          context.showSuccess('delete_local_data_done'.tr());
          context.go(RoutePaths.onboarding);
        }
      } else if (context.mounted) {
        context.showSuccess('delete_cloud_data_done'.tr());
      }
    } catch (e, st) {
      Log.warning('Delete cloud data failed', error: e, stackTrace: st);
      if (context.mounted) {
        context.showError('delete_cloud_data_failed'.tr());
      }
    }
  }

  Widget _buildLocalOnlyTile(
    BuildContext context,
    WidgetRef ref,
    SettingsProviders settings,
  ) {
    final onlineAvailable = supabaseConfigAvailable;
    final value = ref.watch(settings.provider(localOnlySettingDef));
    String subtitle = 'local_only_description'.tr();
    if (!onlineAvailable) {
      subtitle = '$subtitle\n${'onboarding_online_unavailable'.tr()}';
    }
    return SwitchSettingsTile.fromSetting(
      setting: localOnlySettingDef,
      title: 'local_only'.tr(),
      subtitle: subtitle,
      value: value,
      onChanged: (v) =>
          AccountModeActions.handleLocalOnlyChanged(context, ref, settings, v),
      enabled: onlineAvailable,
    );
  }

  Widget _languageTile(
    BuildContext context,
    WidgetRef ref,
    SettingsProviders settings,
  ) {
    final currentLang = ref.watch(settings.provider(languageSettingDef));
    return ListTile(
      leading: Icon(languageSettingDef.icon),
      title: Text('language'.tr()),
      subtitle: Text(
        currentLang == 'ar'
            ? _localeDisplayName(const Locale('ar'))
            : _localeDisplayName(const Locale('en')),
      ),
      onTap: () async {
        final chosen = await showOptionPickerSheet<Locale>(
          context,
          title: 'language'.tr(),
          centerInFullViewport: false,
          selected: currentLang == 'ar'
              ? const Locale('ar')
              : const Locale('en'),
          options: [
            for (final locale in _supportedLocales)
              SheetPickerOption(
                value: locale,
                label: _localeDisplayName(locale),
              ),
          ],
        );
        if (chosen != null && context.mounted) {
          final langCode = chosen.languageCode;
          await applySetting(ref, settings, languageSettingDef, langCode);
          // _LocaleSync will call setLocale when it sees provider != context.locale
        }
      },
    );
  }

  static const _themeModeOptions = ['system', 'light', 'dark', 'amoled'];

  Widget _themeModeTile(
    BuildContext context,
    WidgetRef ref,
    SettingsProviders settings,
  ) {
    final value = ref.watch(settings.provider(themeModeSettingDef));
    return ListTile(
      leading: Icon(themeModeSettingDef.icon),
      title: Text('theme'.tr()),
      subtitle: Text(value.tr()),
      onTap: () async {
        final chosen = await showOptionPickerSheet<String>(
          context,
          title: 'theme'.tr(),
          centerInFullViewport: false,
          selected: value,
          options: [
            for (final option in _themeModeOptions)
              SheetPickerOption(value: option, label: option.tr()),
          ],
        );
        if (chosen != null && context.mounted) {
          await applySetting(ref, settings, themeModeSettingDef, chosen);
        }
      },
    );
  }

  /// Preset theme colors for "Custom" scheme: (value as int, label key for .tr()).
  static const _themeColorPresets = [
    (0xFF2E7D32, 'green'),
    (0xFF1565C0, 'blue'),
    (0xFF00897B, 'teal'),
    (0xFF6A1B9A, 'purple'),
    (0xFFC62828, 'red'),
    (0xFFE65100, 'orange'),
  ];

  /// Color swatch sized like a default [Icon] (24) so ListTile alignment matches.
  static Widget _schemeColorSwatch(
    BuildContext context,
    Color color, {
    double size = 24,
  }) {
    final cs = Theme.of(context).colorScheme;
    final fill = color == Colors.transparent
        ? cs.surfaceContainerHighest
        : color;
    return SizedBox(
      width: size,
      height: size,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: fill,
          shape: BoxShape.circle,
          border: Border.all(color: cs.outline),
        ),
      ),
    );
  }

  Widget _themeSchemeTile(
    BuildContext context,
    WidgetRef ref,
    SettingsProviders settings,
  ) {
    final schemeValue = ref.watch(settings.provider(themeSchemeSettingDef));
    final themeColorValue = ref.watch(settings.provider(themeColorSettingDef));
    final currentLabel = 'theme_scheme_$schemeValue'.tr();
    final displayColor = schemeValue == 'custom'
        ? Color(themeColorValue)
        : primaryColorForSchemeId(schemeValue);
    // Match default Icon size (24) so the swatch aligns with sibling leadings.
    const swatchSize = 24.0;
    return ListTile(
      leading: _schemeColorSwatch(
        context,
        displayColor,
        size: swatchSize,
      ),
      title: Text('color_scheme'.tr()),
      subtitle: Text(currentLabel),
      onTap: () async {
        final chosenScheme = await showOptionPickerSheet<String>(
          context,
          title: 'color_scheme'.tr(),
          centerInFullViewport: false,
          selected: schemeValue,
          options: [
            for (final schemeId in flexSchemeOptionIds)
              SheetPickerOption(
                value: schemeId,
                label: 'theme_scheme_$schemeId'.tr(),
                leading: Builder(
                  builder: (ctx) {
                    final chipColor = schemeId == 'custom'
                        ? Color(themeColorValue)
                        : primaryColorForSchemeId(schemeId);
                    return _schemeColorSwatch(ctx, chipColor, size: swatchSize);
                  },
                ),
              ),
          ],
        );
        if (chosenScheme != null && context.mounted) {
          await applySetting(
            ref,
            settings,
            themeSchemeSettingDef,
            chosenScheme,
          );
          if (chosenScheme == 'custom' && context.mounted) {
            final chosenColor = await showResponsiveSheet<int>(
              context: context,
              title: 'select_theme_color'.tr(),
              maxHeight: MediaQuery.of(context).size.height * 0.75,
              isScrollControlled: true,
              centerInFullViewport: false,
              child: Builder(
                builder: (ctx) => SafeArea(
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: EdgeInsets.only(
                        bottom: MediaQuery.of(ctx).padding.bottom + 16,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (!LayoutBreakpoints.isTabletOrWider(context))
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                              child: Text(
                                'select_theme_color'.tr(),
                                style: Theme.of(ctx).textTheme.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w700),
                              ),
                            ),
                          SheetOptionList(
                            children: [
                              for (final preset in _themeColorPresets)
                                SheetOptionTile(
                                  title: preset.$2.tr(),
                                  selected: themeColorValue == preset.$1,
                                  leading: Container(
                                    width: 24,
                                    height: 24,
                                    decoration: BoxDecoration(
                                      color: Color(preset.$1),
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: Theme.of(ctx).colorScheme.outline,
                                      ),
                                    ),
                                  ),
                                  onTap: () =>
                                      Navigator.of(ctx).pop(preset.$1),
                                ),
                              SheetOptionTile(
                                title: 'pick_custom_theme_color'.tr(),
                                leading: Icon(
                                  Icons.palette_outlined,
                                  color: Theme.of(ctx).colorScheme.primary,
                                ),
                                onTap: () async {
                                  final picked = await showColorPickerDialog(
                                    ctx,
                                    Color(themeColorValue),
                                    barrierDismissible: true,
                                    pickersEnabled:
                                        const <ColorPickerType, bool>{
                                          ColorPickerType.primary: false,
                                          ColorPickerType.accent: false,
                                          ColorPickerType.bw: false,
                                          ColorPickerType.both: false,
                                          ColorPickerType.custom: false,
                                          ColorPickerType.wheel: true,
                                        },
                                  );
                                  if (!context.mounted || !ctx.mounted) return;
                                  final colorChanged =
                                      picked.toARGB32() != themeColorValue;
                                  if (colorChanged) {
                                    applySetting(
                                      ref,
                                      settings,
                                      themeColorSettingDef,
                                      picked.toARGB32(),
                                    );
                                    if (ctx.mounted) {
                                      Navigator.of(ctx).pop();
                                    }
                                  }
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
            if (chosenColor != null && context.mounted) {
              await applySetting(
                ref,
                settings,
                themeColorSettingDef,
                chosenColor,
              );
            }
          }
        }
      },
    );
  }

  static const _fontSizeOptions = ['small', 'normal', 'large', 'extra_large'];

  Widget _fontSizeTile(
    BuildContext context,
    WidgetRef ref,
    SettingsProviders settings,
  ) {
    final value = ref.watch(settings.provider(fontSizeScaleSettingDef));
    return ListTile(
      leading: Icon(fontSizeScaleSettingDef.icon),
      title: Text('font_size'.tr()),
      subtitle: Text(value.tr()),
      onTap: () async {
        final chosen = await showOptionPickerSheet<String>(
          context,
          title: 'font_size'.tr(),
          centerInFullViewport: false,
          selected: value,
          options: [
            for (final option in _fontSizeOptions)
              SheetPickerOption(value: option, label: option.tr()),
          ],
        );
        if (chosen != null && context.mounted) {
          await applySetting(ref, settings, fontSizeScaleSettingDef, chosen);
        }
      },
    );
  }

  Widget _favoriteCurrenciesTile(
    BuildContext context,
    WidgetRef ref,
    SettingsProviders settings,
  ) {
    final stored = ref.watch(settings.provider(favoriteCurrenciesSettingDef));
    final effective = CurrencyHelpers.getEffectiveFavorites(stored);
    final isCustom = stored.trim().isNotEmpty;

    // Build short labels: "🇸🇦 SAR, 🇯🇵 JPY, ..."
    final labels = effective
        .map((code) {
          final c = CurrencyHelpers.fromCode(code);
          return c != null ? CurrencyHelpers.shortLabel(c) : code;
        })
        .join(', ');

    return ListTile(
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
              onPressed: () {
                applySetting(ref, settings, favoriteCurrenciesSettingDef, '');
              },
            )
          : null,
      onTap: () => _showFavoriteCurrenciesEditor(context, ref, settings),
    );
  }

  Widget _displayCurrencyTile(
    BuildContext context,
    WidgetRef ref,
    SettingsProviders settings,
  ) {
    final stored = ref
        .watch(settings.provider(displayCurrencySettingDef))
        .trim();
    final label = stored.isEmpty
        ? 'display_currency_none'.tr()
        : (CurrencyHelpers.fromCode(stored) != null
              ? CurrencyHelpers.shortLabel(CurrencyHelpers.fromCode(stored)!)
              : stored);

    return ListTile(
      leading: const Icon(Icons.visibility_outlined),
      title: Text('display_currency'.tr()),
      subtitle: Text(
        'display_currency_hint'.tr(),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (stored.isNotEmpty)
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 8),
              child: Text(
                label,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          if (stored.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear),
              tooltip: 'display_currency_none'.tr(),
              onPressed: () {
                applySetting(ref, settings, displayCurrencySettingDef, '');
              },
            ),
        ],
      ),
      onTap: () => _showDisplayCurrencyPicker(context, ref, settings),
    );
  }

  void _showDisplayCurrencyPicker(
    BuildContext context,
    WidgetRef ref,
    SettingsProviders settings,
  ) {
    final favorites = CurrencyHelpers.getEffectiveFavorites(
      ref.read(favoriteCurrenciesProvider),
    );
    CurrencyHelpers.showPicker(
      context: context,
      title: 'display_currency'.tr(),
      centerInFullViewport: false,
      favorite: favorites,
      onSelect: (currency) {
        applySetting(
          ref,
          settings,
          displayCurrencySettingDef,
          currency.code,
        );
      },
    );
  }

  void _showFavoriteCurrenciesEditor(
    BuildContext context,
    WidgetRef ref,
    SettingsProviders settings,
  ) {
    final stored = ref.read(settings.provider(favoriteCurrenciesSettingDef));
    final current = List<String>.from(
      CurrencyHelpers.getEffectiveFavorites(stored),
    );

    showResponsiveSheet<void>(
      context: context,
      title: 'favorite_currencies'.tr(),
      maxHeight: MediaQuery.of(context).size.height * 0.75,
      isScrollControlled: true,
      centerInFullViewport: false,
      child: _FavoriteCurrenciesSheet(
        initial: current,
        onSave: (updated) {
          final encoded = CurrencyHelpers.encodeFavorites(updated);
          applySetting(
            ref,
            settings,
            favoriteCurrenciesSettingDef,
            encoded,
          );
        },
      ),
    );
  }

  Widget _buildAboutSection(
    BuildContext context,
    WidgetRef ref,
    SettingsProviders settings,
  ) {
    final sectionKey = _sectionKeys[aboutSection.key]!;
    return KeyedSubtree(
      key: sectionKey,
      child: CardSettingsSection(
        title: 'about'.tr(),
        icon: aboutSection.icon ?? Icons.info,
        sectionId: aboutSection.key,
        isExpanded: _isExpanded(aboutSection),
        onExpansionChanged: (expanded) =>
            _onExpansionChanged(aboutSection.key, expanded),
        isLandscape: false,
        children: [
          _anchors.wrap(
            actionVersionSettingDef.key,
            FutureBuilder<PackageInfo>(
              future: PackageInfo.fromPlatform(),
              builder: (context, snapshot) {
                final version = snapshot.hasData
                    ? '${snapshot.data!.appName} ${snapshot.data!.version}+${snapshot.data!.buildNumber}'
                    : '—';
                final isWeb = kIsWeb;
                return NavigationSettingsTile(
                  leading: const Icon(Icons.info_outline),
                  title: Text('version'.tr()),
                  subtitle: Text(version),
                  onTap: isWeb
                      ? null
                      : () {
                          final trigger = ref
                              .read(updateCheckTriggerProvider)
                              .callback;
                          if (trigger != null) {
                            if (context.mounted) {
                              context.showToast('checking_for_updates'.tr());
                            }
                            trigger(context);
                          }
                        },
                );
              },
            ),
          ),
          _anchors.wrap(
            actionSendFeedbackSettingDef.key,
            NavigationSettingsTile(
              leading: const Icon(Icons.feedback_outlined),
              title: Text('send_feedback'.tr()),
              onTap: () {
                if (!context.mounted) return;
                // Reset controller so sheet can open again after being dismissed.
                BetterFeedback.of(context).hide();
                BetterFeedback.of(context).show(
                  (UserFeedback feedback) =>
                      handleFeedback(context, feedback: feedback),
                );
              },
            ),
          ),
          _anchors.wrap(
            actionLicensesSettingDef.key,
            NavigationSettingsTile(
              leading: const Icon(Icons.info_outline),
              title: Text('licenses'.tr()),
              onTap: () => _showLicenses(context),
            ),
          ),
          _anchors.wrap(
            actionAboutMeSettingDef.key,
            NavigationSettingsTile(
              leading: const Icon(Icons.person_outline),
              title: Text('about_me'.tr()),
              subtitle: Text('about_me_description'.tr()),
              onTap: () => _showAboutMe(context),
            ),
          ),
          _anchors.wrap(
            actionDonateSettingDef.key,
            NavigationSettingsTile(
              leading: const Icon(Icons.favorite_outline),
              title: Text('donate'.tr()),
              subtitle: Text('donate_description'.tr()),
              onTap: () => _openDonateLink(context),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildScannerSectionTiles(
    BuildContext context,
    WidgetRef ref,
    SettingsProviders settings,
  ) {
    final isEnabled = ref.watch(scannerEnabledProvider);
    final pendingCount =
        ref.watch(pendingDraftCountProvider).asData?.value ?? 0;
    return [
      _anchors.wrap(
        scannerEnabledSettingDef.key,
        SwitchSettingsTile.fromSetting(
          setting: scannerEnabledSettingDef,
          title: 'scanner_enabled'.tr(),
          subtitle: 'scanner_enabled_description'.tr(),
          value: isEnabled,
          onChanged: (v) {
            applySetting(ref, settings, scannerEnabledSettingDef, v);
            NotificationBridge.setEnabled(v);
          },
        ),
      ),
      _anchors.wrap(
        actionScannerHubSettingDef.key,
        NavigationSettingsTile(
          leading: const Icon(Icons.checklist),
          title: Text('scanner_pending_title'.tr()),
          subtitle: pendingCount > 0
              ? Text(
                  'scanner_pending_count'.tr(args: [pendingCount.toString()]),
                )
              : Text('scanner_no_pending'.tr()),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const ScannerHubPage(),
              ),
            );
          },
        ),
      ),
    ];
  }

  static Future<void> _showApiKeyDialog({
    required BuildContext context,
    required WidgetRef ref,
    required String titleKey,
    required String currentValue,
    required StringSetting settingDef,
  }) async {
    final value = await showTextInputSheet(
      context,
      title: titleKey.tr(),
      hint: 'receipt_ai_key_hint'.tr(),
      initialValue: currentValue,
      obscureText: true,
      centerInFullViewport: false,
    );
    if (value != null && context.mounted) {
      try {
        final settings = ref.read(hisabSettingsProvidersProvider);
        if (settings != null) {
          ref.read(settings.provider(settingDef).notifier).set(value);
          Log.info('Setting changed: ${settingDef.key}=(set)');
        }
      } catch (e, st) {
        Log.warning('Failed to set API key', error: e, stackTrace: st);
      }
    }
  }

  static Future<void> _showLogsDialog(BuildContext context) async {
    Log.debug('Opening logs dialog');
    String content;
    if (kIsWeb) {
      content = getWebLogContent();
      if (content.isEmpty) {
        content = 'logs_web_empty'.tr();
      }
    } else {
      try {
        content = await LoggingService.getLogContent(maxLines: 500);
      } catch (e) {
        content = 'logs_not_available'.tr();
      }
    }
    if (!context.mounted) return;
    final scaffoldContext = context;
    await showResponsiveSheet<void>(
      context: context,
      title: 'view_logs'.tr(),
      maxWidth: 600,
      maxHeight: 700,
      centerInFullViewport: false,
      barrierDismissible: false,
      child: Builder(
        builder: (ctx) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).padding.bottom + 16,
          ),
          child: LogsViewerDialog(
            content: content,
            onCopy: () async {
              await Clipboard.setData(ClipboardData(text: content));
              if (scaffoldContext.mounted) {
                scaffoldContext.showSuccess('logs_copied'.tr());
              }
            },
            onClear: () async {
              final confirmed = await showConfirmSheet(
                ctx,
                title: 'clear_logs'.tr(),
                content: 'clear_logs_confirm'.tr(),
                confirmLabel: 'clear_logs'.tr(),
                centerInFullViewport: false,
              );
              if (confirmed == true) {
                if (kIsWeb) {
                  clearWebLogContent();
                  if (ctx.mounted) Navigator.pop(ctx);
                  if (scaffoldContext.mounted) {
                    scaffoldContext.showSuccess('logs_cleared'.tr());
                  }
                } else {
                  try {
                    await LoggingService.clearLogs();
                    if (ctx.mounted) Navigator.pop(ctx);
                    if (scaffoldContext.mounted) {
                      scaffoldContext.showSuccess('logs_cleared'.tr());
                    }
                  } catch (e, st) {
                    Log.warning('Clear logs failed', error: e, stackTrace: st);
                    if (scaffoldContext.mounted) {
                      scaffoldContext.showToast('logs_not_available'.tr());
                    }
                  }
                }
              }
            },
            onReportIssue: () =>
                _handleReportIssue(ctx, scaffoldContext, content),
            onClose: () => Navigator.pop(ctx),
          ),
        ),
      ),
    );
  }

  static Future<void> _handleReportIssue(
    BuildContext dialogContext,
    BuildContext scaffoldContext,
    String logsContent,
  ) async {
    String description = '';
    if (reportIssueUrl.isNotEmpty) {
      final result = await showTextInputSheet(
        dialogContext,
        title: 'report_issue'.tr(),
        hint: 'report_issue_description_hint'.tr(),
        maxLines: 3,
        centerInFullViewport: false,
      );
      if (result == null) return;
      description = result;
    }
    try {
      final String formatted = kIsWeb
          ? '**Description**\n$description\n\n**Logs**\n$logsContent'
          : await LoggingService.formatLogsForGitHub(description);
      await Clipboard.setData(ClipboardData(text: formatted));
      if (reportIssueUrl.isNotEmpty) {
        await launchUrl(Uri.parse(reportIssueUrl));
      }
      if (scaffoldContext.mounted) {
        scaffoldContext.showSuccess(
          reportIssueUrl.isEmpty
              ? 'logs_copied_paste'.tr()
              : 'logs_copied'.tr(),
        );
      }
    } catch (e, st) {
      Log.warning('Report issue / copy logs failed', error: e, stackTrace: st);
      if (scaffoldContext.mounted) {
        scaffoldContext.showToast('logs_not_available'.tr());
      }
    }
  }

  static void _showLicenses(BuildContext context) {
    showLicensePage(context: context, applicationName: 'app_name'.tr());
  }

  static Future<void> _openDonateLink(BuildContext context) async {
    final uri = Uri.parse(githubDonateUrl);
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e, st) {
      Log.warning('Open donate link failed', error: e, stackTrace: st);
      if (context.mounted) {
        context.showToast('donate'.tr());
      }
    }
  }

  static void _showAboutMe(BuildContext context) {
    final isTablet = LayoutBreakpoints.isTabletOrWider(context);
    showResponsiveSheet<void>(
      context: context,
      title: 'about_me'.tr(),
      maxHeight: MediaQuery.of(context).size.height * 0.75,
      isScrollControlled: true,
      centerInFullViewport: false,
      child: Builder(
        builder: (ctx) => buildSheetShell(
          ctx,
          title: 'about_me'.tr(),
          showTitleInBody: !isTablet,
          body: _AboutMeDialogContent(
            profileUrl: githubDeveloperProfileUrl,
            username: githubDeveloperUsername,
          ),
          actions: [
            if (!isTablet)
              FilledButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text('done'.tr()),
              ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// About me dialog content (developer info from GitHub)
// =============================================================================

class _AboutMeDialogContent extends StatefulWidget {
  const _AboutMeDialogContent({
    required this.profileUrl,
    required this.username,
  });

  final String profileUrl;
  final String username;

  @override
  State<_AboutMeDialogContent> createState() => _AboutMeDialogContentState();
}

class _AboutMeDialogContentState extends State<_AboutMeDialogContent> {
  GitHubUserProfile? _profile;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      final p = await fetchGitHubUser(widget.username);
      if (mounted) {
        setState(() {
          _profile = p;
          _loading = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    final profile = _profile;
    final displayName = profile?.displayName ?? widget.username;
    final avatarUrl = profile?.avatarUrl;
    final bio = profile?.bio;
    final location = profile?.location;
    final blog = profile?.blog;
    final linkUrl = profile?.htmlUrl ?? widget.profileUrl;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (avatarUrl != null && avatarUrl.isNotEmpty)
          ClipOval(
            child: Builder(
              builder: (context) {
                final decode = NetworkImageDecode.cacheSize(
                  context,
                  logicalWidth: 80,
                  logicalHeight: 80,
                );
                return Image.network(
                  avatarUrl,
                  fit: BoxFit.cover,
                  width: 80,
                  height: 80,
                  cacheWidth: decode.width,
                  cacheHeight: decode.height,
                  errorBuilder: (_, _, _) => Container(
                    width: 80,
                    height: 80,
                    color: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest,
                    child: Icon(
                      Icons.person,
                      size: 40,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                );
              },
            ),
          )
        else
          CircleAvatar(
            radius: 40,
            child: Icon(
              Icons.person,
              size: 40,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        const SizedBox(height: 16),
        Text(
          displayName,
          style: Theme.of(context).textTheme.titleMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          'about_me_summary'.tr(),
          style: Theme.of(context).textTheme.bodyMedium,
          textAlign: TextAlign.center,
        ),
        if (bio != null && bio.trim().isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            bio.trim(),
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
        ],
        if (location != null && location.trim().isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            location.trim(),
            style: Theme.of(context).textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
        ],
        if (blog != null && blog.trim().isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            blog.trim(),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
        const SizedBox(height: 16),
        TextButton.icon(
          onPressed: () async {
            final uri = Uri.parse(linkUrl);
            try {
              await launchUrl(uri, mode: LaunchMode.externalApplication);
            } catch (_) {}
          },
          icon: const Icon(Icons.open_in_new, size: 18),
          label: Text('view_profile'.tr()),
        ),
      ],
    );
  }
}

// =============================================================================
// Migration Progress Dialog
// =============================================================================

// =============================================================================
// Favorite Currencies Editor Sheet
// =============================================================================

class _FavoriteCurrenciesSheet extends StatefulWidget {
  final List<String> initial;
  final ValueChanged<List<String>> onSave;

  const _FavoriteCurrenciesSheet({required this.initial, required this.onSave});

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
      onSelect: (currency) {
        if (!_codes.contains(currency.code)) {
          setState(() => _codes.add(currency.code));
        }
      },
      centerInFullViewport: false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          if (!LayoutBreakpoints.isTabletOrWider(context))
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'favorite_currencies'.tr(),
                      style: textTheme.titleMedium,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add),
                    tooltip: 'add_currency'.tr(),
                    onPressed: _addCurrency,
                  ),
                ],
              ),
            ),
          if (LayoutBreakpoints.isTabletOrWider(context))
            Padding(
              padding: const EdgeInsets.only(top: 8, right: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  IconButton(
                    icon: const Icon(Icons.add),
                    tooltip: 'add_currency'.tr(),
                    onPressed: _addCurrency,
                  ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'favorite_currencies_hint'.tr(),
              style: textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(height: 8),
          // List
          if (_codes.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'favorite_currencies_empty'.tr(),
                style: textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            )
          else
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.5,
              ),
              child: ReorderableListView.builder(
                itemCount: _codes.length,
                shrinkWrap: true,
                onReorder: (oldIndex, newIndex) {
                  setState(() {
                    if (newIndex > oldIndex) newIndex--;
                    final item = _codes.removeAt(oldIndex);
                    _codes.insert(newIndex, item);
                  });
                },
                itemBuilder: (context, index) {
                  final code = _codes[index];
                  final currency = CurrencyHelpers.fromCode(code);
                  final flag = currency != null
                      ? CurrencyUtils.currencyToEmoji(currency)
                      : '';
                  final name = currency?.name ?? code;

                  return ListTile(
                    key: ValueKey(code),
                    leading: Text(flag, style: const TextStyle(fontSize: 24)),
                    title: Text('$code - $name'),
                    trailing: IconButton(
                      icon: Icon(
                        Icons.remove_circle_outline,
                        color: colorScheme.error,
                      ),
                      onPressed: () {
                        setState(() => _codes.removeAt(index));
                      },
                    ),
                  );
                },
              ),
            ),
          const SizedBox(height: 8),
          // Actions
          Padding(
            padding: EdgeInsets.fromLTRB(
              16,
              0,
              16,
              16 + MediaQuery.of(context).padding.bottom,
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

class _DeleteLocalDataDialogContent extends StatefulWidget {
  const _DeleteLocalDataDialogContent({
    required this.groups,
    required this.participants,
    required this.expenses,
    required this.expenseTags,
    required this.groupInvites,
  });

  final int groups;
  final int participants;
  final int expenses;
  final int expenseTags;
  final int groupInvites;

  @override
  State<_DeleteLocalDataDialogContent> createState() =>
      _DeleteLocalDataDialogContentState();
}

class _DeleteLocalDataDialogContentState
    extends State<_DeleteLocalDataDialogContent> {
  int _secondsLeft = 30;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        if (_secondsLeft > 0) _secondsLeft--;
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final canConfirm = _secondsLeft <= 0;
    final summary = 'delete_local_data_summary'.tr(
      namedArgs: {
        'groups': '${widget.groups}',
        'participants': '${widget.participants}',
        'expenses': '${widget.expenses}',
      },
    );
    return SafeArea(
      child: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).padding.bottom + 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!LayoutBreakpoints.isTabletOrWider(context))
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'delete_local_data'.tr(),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(summary),
                    const SizedBox(height: 16),
                    Text(
                      canConfirm
                          ? 'delete_confirm_ready'.tr()
                          : 'delete_confirm_countdown'.tr(
                              namedArgs: {'seconds': '$_secondsLeft'},
                            ),
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (!LayoutBreakpoints.isTabletOrWider(context))
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: Text('cancel'.tr()),
                      ),
                    if (!LayoutBreakpoints.isTabletOrWider(context))
                      const SizedBox(width: 8),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.error,
                      ),
                      onPressed: canConfirm
                          ? () => Navigator.pop(context, true)
                          : null,
                      child: Text('delete_local_data_confirm_label'.tr()),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DeleteCloudDataDialogContent extends StatefulWidget {
  const _DeleteCloudDataDialogContent({required this.preview});

  final DeleteMyDataPreview preview;

  @override
  State<_DeleteCloudDataDialogContent> createState() =>
      _DeleteCloudDataDialogContentState();
}

class _DeleteCloudDataDialogContentState
    extends State<_DeleteCloudDataDialogContent> {
  int _secondsLeft = 30;
  bool _alsoDeleteLocal = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        if (_secondsLeft > 0) _secondsLeft--;
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final canConfirm = _secondsLeft <= 0;
    final p = widget.preview;
    final summary = 'delete_cloud_data_summary'.tr(
      namedArgs: {
        'ownerGroups': '${p.groupsWhereOwner}',
        'memberships': '${p.groupMemberships}',
        'tokens': '${p.deviceTokensCount}',
        'invites': '${p.inviteUsagesCount}',
      },
    );
    return SafeArea(
      child: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).padding.bottom + 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!LayoutBreakpoints.isTabletOrWider(context))
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'delete_cloud_data'.tr(),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(summary),
                    if (p.soleMemberGroupCount > 0) ...[
                      const SizedBox(height: 8),
                      Text(
                        'delete_cloud_data_sole_member_warning'.tr(
                          namedArgs: {'count': '${p.soleMemberGroupCount}'},
                        ),
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    CheckboxListTile(
                      value: _alsoDeleteLocal,
                      onChanged: (v) =>
                          setState(() => _alsoDeleteLocal = v ?? false),
                      title: Text('also_delete_local_data_option'.tr()),
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: EdgeInsets.zero,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      canConfirm
                          ? 'delete_confirm_ready'.tr()
                          : 'delete_confirm_countdown'.tr(
                              namedArgs: {'seconds': '$_secondsLeft'},
                            ),
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (!LayoutBreakpoints.isTabletOrWider(context))
                      TextButton(
                        onPressed: () => Navigator.pop(context, null),
                        child: Text('cancel'.tr()),
                      ),
                    if (!LayoutBreakpoints.isTabletOrWider(context))
                      const SizedBox(width: 8),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.error,
                      ),
                      onPressed: canConfirm
                          ? () => Navigator.pop(context, _alsoDeleteLocal)
                          : null,
                      child: Text('delete_cloud_data_confirm_label'.tr()),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
