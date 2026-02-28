import 'dart:ui' as ui;
import 'package:feedback/feedback.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_logging_service/flutter_logging_service.dart';
import 'package:upgrader/upgrader.dart';
import 'core/auth/auth_providers.dart';
import 'core/database/database_providers.dart';
import 'core/services/notification_service.dart';
import 'core/debug/debug_menu.dart';
import 'core/update/app_update_helper.dart';
import 'core/update/update_check_providers.dart';
import 'core/update/upgrader_messages.dart';
import 'features/settings/providers/settings_framework_providers.dart';
import 'features/settings/settings_definitions.dart';
import 'core/theme/app_scroll_behavior.dart';
import 'core/theme/theme_config.dart';
import 'core/theme/theme_providers.dart';
import 'package:toastification/toastification.dart';
import 'core/navigation/app_router.dart';
import 'core/navigation/invite_link_handler.dart';
import 'core/services/connectivity_service.dart';
import 'core/widgets/back_button_keyboard_dismiss.dart';
import 'core/widgets/toast.dart';

class App extends ConsumerStatefulWidget {
  const App({super.key});

  @override
  ConsumerState<App> createState() => _AppState();
}

class _AppState extends ConsumerState<App>
    with WidgetsBindingObserver {
  late final Upgrader _upgrader;
  /// In release, defer UpgradeAlert until after first frame to avoid any
  /// upgrader work blocking the first paint (splash can disappear).
  bool _showUpgradeAlert = kDebugMode;
  /// Hide debug FAB while the debug menu sheet is open so it doesn't obstruct it.
  bool _debugFabVisible = true;
  bool _updateTriggerRegistered = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _upgrader = Upgrader(
      durationUntilAlertAgain: const Duration(days: 3),
      debugLogging: false, // use app-level aggregated log instead of package prints
      messages: HisabUpgraderMessages(context: context),
      willDisplayUpgrade: ({required bool display, String? installedVersion, UpgraderVersionInfo? versionInfo}) {
        Log.debug(
          'Upgrader (auto): store=${versionInfo?.appStoreVersion}, installed=$installedVersion, showDialog=$display',
        );
      },
    );
    if (!kDebugMode) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _showUpgradeAlert = true);
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _saveCurrentRoute();
    } else if (state == AppLifecycleState.resumed) {
      _clearSavedRoute();
    }
  }

  void _saveCurrentRoute() {
    if (!mounted) return;
    final path = ref.read(routerProvider).routerDelegate.currentConfiguration.uri.path;
    if (path.isEmpty || path == '/') return;
    final settings = ref.read(hisabSettingsProvidersProvider);
    if (settings != null) {
      ref.read(settings.provider(lastRoutePathSettingDef).notifier).set(path);
    }
  }

  void _clearSavedRoute() {
    if (!mounted) return;
    final settings = ref.read(hisabSettingsProvidersProvider);
    if (settings != null) {
      ref.read(settings.provider(lastRoutePathSettingDef).notifier).set('');
    }
  }

  void _registerUpdateCheckTrigger() {
    if (_updateTriggerRegistered) return;
    _updateTriggerRegistered = true;
    ref.read(updateCheckTriggerProvider).callback = (BuildContext context) {
      Future<void>(() async {
        Upgrader.clearSavedSettings();
        await _upgrader.updateVersionInfo();
        if (!mounted) return;
        _upgrader.updateState(
          _upgrader.state.copyWith(debugDisplayAlways: true),
        );
        await Future.delayed(const Duration(milliseconds: 400));
        if (!mounted) return;
        final shouldShow = _upgrader.shouldDisplayUpgrade();
        final vi = _upgrader.versionInfo;
        Log.debug(
          'Upgrader (manual): store=${vi?.appStoreVersion}, installed=${vi?.installedVersion}, showDialog=$shouldShow',
        );
        if (!shouldShow && context.mounted) {
          final msg = _upgrader.versionInfo == null
              ? 'could_not_check_for_updates'.tr()
              : 'no_update_available'.tr();
          context.showToast(msg);
        }
      });
    };
  }

  @override
  Widget build(BuildContext context) {
    _registerUpdateCheckTrigger();
    final router = ref.watch(routerProvider);
    final themes = ref.watch(appThemesProvider);
    final themeMode = ref.watch(appThemeModeProvider);

    // Watch DataSyncService to reactively fetch/push data
    ref.watch(dataSyncServiceProvider);

    // Initialize push notifications when user authenticates and setting is enabled.
    // listen handles sign-in/sign-out transitions; watch handles initial state.
    // Context is passed so the notification service can show a non-blocking
    // dialog when the user denies notification permission.
    ref.listen(isAuthenticatedProvider, (prev, isAuth) {
      if (isAuth && prev != true) {
        if (ref.read(notificationsEnabledProvider)) {
          ref.read(notificationServiceProvider.notifier).initialize(context);
        }
      } else if (!isAuth && prev == true) {
        ref.read(notificationServiceProvider.notifier).unregisterToken();
      }
    });

    // Locale is read exclusively from EasyLocalization (context.locale) so that
    // locale: and localizationsDelegates always come from the same frame.
    // _LocaleSync (in main.dart) bridges languageProvider → context.setLocale.
    final feedbackTheme = FeedbackThemeData(
      background: themes.light.colorScheme.surfaceContainerHighest,
      feedbackSheetColor: themes.light.colorScheme.surface,
      drawColors: [
        ThemeConfig.defaultSeedColor,
        themes.light.colorScheme.secondary,
        themes.light.colorScheme.tertiary,
      ],
    );
    return BetterFeedback(
      theme: feedbackTheme,
      localizationsDelegates: [
        ...context.localizationDelegates,
        GlobalFeedbackLocalizationsDelegate(),
      ],
      localeOverride: context.locale,
      child: InviteLinkHandler(
        ref: ref,
        child: ToastificationWrapper(
          config: const ToastificationConfig(alignment: Alignment.bottomCenter),
          child: MaterialApp.router(
        title: 'app_name'.tr(),
        debugShowCheckedModeBanner: false,
        scrollBehavior: AppScrollBehavior(),
        localizationsDelegates: context.localizationDelegates,
        supportedLocales: context.supportedLocales,
        locale: context.locale,
        builder: (context, child) {
          final isRtl = context.locale.languageCode == 'ar';
          final isDebug =
              ref.watch(isDebugBuildProvider).asData?.value == true;
          final innerContent = BackButtonKeyboardDismiss(
            child: GestureDetector(
              onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
              behavior: HitTestBehavior.deferToChild,
              child: Directionality(
                textDirection:
                    isRtl ? ui.TextDirection.rtl : ui.TextDirection.ltr,
                child: child ?? const SizedBox.shrink(),
              ),
            ),
          );
          final contentWithSyncIndicator = Stack(
            children: [
              Positioned.fill(child: innerContent),
              const Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: _SyncProgressLine(),
              ),
            ],
          );
          // In release, first frame paints without UpgradeAlert to avoid
          // any upgrader init blocking splash removal.
          if (!_showUpgradeAlert) {
            return Stack(
              children: [
                contentWithSyncIndicator,
                if (isDebug && _debugFabVisible)
                  Positioned(
                    bottom: 96,
                    left: isRtl ? null : 8,
                    right: isRtl ? 8 : null,
                    child: DebugMenuFab(
                      upgrader: _upgrader,
                      navigatorContext:
                          router.routerDelegate.navigatorKey.currentContext,
                      localeContext: context,
                      onBeforeOpen: () =>
                          setState(() => _debugFabVisible = false),
                      whenSheetClosed: () =>
                          setState(() => _debugFabVisible = true),
                    ),
                  ),
              ],
            );
          }
          return Stack(
            children: [
              UpgradeAlert(
                navigatorKey: router.routerDelegate.navigatorKey,
                upgrader: _upgrader,
                onUpdate: () {
                  if (!kIsWeb &&
                      defaultTargetPlatform == TargetPlatform.android) {
                    handleAndroidUpdateThenStore(_upgrader);
                    return false;
                  }
                  return true;
                },
                child: contentWithSyncIndicator,
              ),
              if (isDebug && _debugFabVisible)
                Positioned(
                  bottom: 96,
                  left: isRtl ? null : 8,
                  right: isRtl ? 8 : null,
                  child: DebugMenuFab(
                    upgrader: _upgrader,
                    navigatorContext:
                        router.routerDelegate.navigatorKey.currentContext,
                    localeContext: context,
                    onBeforeOpen: () =>
                        setState(() => _debugFabVisible = false),
                    whenSheetClosed: () =>
                        setState(() => _debugFabVisible = true),
                  ),
                ),
            ],
          );
        },
        theme: themes.light,
        darkTheme: themes.dark,
        themeMode: themeMode,
        routerConfig: router,
        ),
        ),
      ),
    );
  }
}

/// Sync progress line that watches [syncStatusForDisplayProvider] so only this
/// widget rebuilds when sync status changes, not the rest of the app (avoids
/// overlay/dialog rebuild and focus loss when sync completes).
class _SyncProgressLine extends ConsumerWidget {
  const _SyncProgressLine();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final syncStatus = ref.watch(syncStatusForDisplayProvider);
    if (syncStatus != SyncStatus.syncing) return const SizedBox.shrink();
    return SafeArea(
      bottom: false,
      child: SizedBox(
        height: 3,
        child: LinearProgressIndicator(
          backgroundColor: Theme.of(context)
              .colorScheme
              .surfaceContainerHighest,
        ),
      ),
    );
  }
}
