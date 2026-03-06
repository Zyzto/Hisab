import 'dart:ui' as ui;
import 'dart:async';
import 'package:feedback/feedback.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_logging_service/flutter_logging_service.dart';
import 'package:go_router/go_router.dart';
import 'package:upgrader/upgrader.dart';
import 'package:version/version.dart';
import 'core/auth/auth_providers.dart';
import 'core/database/database_providers.dart';
import 'core/services/notification_service.dart';
import 'core/debug/debug_menu.dart';
import 'core/debug/integration_test_mode.dart';
import 'core/update/app_update_helper.dart';
import 'core/update/hisab_upgrader.dart';
import 'core/update/update_check_providers.dart';
import 'core/update/upgrader_messages.dart';
import 'features/settings/providers/settings_framework_providers.dart';
import 'features/settings/settings_definitions.dart';
import 'core/theme/app_scroll_behavior.dart';
import 'core/theme/theme_providers.dart';
import 'package:toastification/toastification.dart';
import 'core/layout/layout_breakpoints.dart';
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

class _AppState extends ConsumerState<App> with WidgetsBindingObserver {
  late final HisabUpgrader _upgrader;

  /// In release, defer UpgradeAlert until after first frame to avoid any
  /// upgrader work blocking the first paint (splash can disappear).
  bool _showUpgradeAlert = kDebugMode;

  /// Hide debug FAB while the debug menu sheet is open so it doesn't obstruct it.
  bool _debugFabVisible = true;
  bool _updateTriggerRegistered = false;
  bool _manualUpdateCheckInFlight = false;
  ProviderSubscription<bool>? _authSubscription;
  void Function(BuildContext context)? _updateCheckCallback;
  VoidCallback? _clearOwnedUpdateCheckTrigger;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scheduleStartupKeyboardDismiss();
    _upgrader = HisabUpgrader(
      durationUntilAlertAgain: const Duration(days: 3),
      debugLogging:
          false, // use app-level aggregated log instead of package prints
      messages: HisabUpgraderMessages(context: context),
      willDisplayUpgrade:
          ({
            required bool display,
            String? installedVersion,
            UpgraderVersionInfo? versionInfo,
          }) {
            Log.debug(
              'Upgrader (auto): store=${versionInfo?.appStoreVersion}, installed=$installedVersion, showDialog=$display',
            );
          },
    );
    _registerAuthListener();
    if (!kDebugMode) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _showUpgradeAlert = true);
      });
    }
  }

  void _scheduleStartupKeyboardDismiss() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _dismissKeyboardIfVisible();
      // Some emulators/dev builds can restore IME visibility shortly after
      // first frame (especially after restart). Retry once after a short delay.
      Future<void>.delayed(const Duration(milliseconds: 250), () {
        if (!mounted) return;
        _dismissKeyboardIfVisible();
      });
    });
  }

  @override
  void dispose() {
    _clearOwnedUpdateCheckTrigger?.call();
    _clearOwnedUpdateCheckTrigger = null;
    _authSubscription?.close();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached ||
        state == AppLifecycleState.resumed) {
      _dismissKeyboardIfVisible();
    }
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _saveCurrentRoute();
    } else if (state == AppLifecycleState.resumed) {
      _clearSavedRoute();
    }
  }

  @override
  void reassemble() {
    super.reassemble();
    _dismissKeyboardIfVisible();
  }

  void _dismissKeyboardIfVisible() {
    final focus = FocusManager.instance.primaryFocus;
    final hadFocus = focus != null && focus.hasFocus;
    if (focus != null && focus.hasFocus) {
      focus.unfocus();
    }
    if (!hadFocus && !_hasVisibleImeInsets()) return;
    // Hot reload keeps state by design; explicitly ask the platform to hide
    // the IME so keyboards do not remain visible after reload/lifecycle hops.
    unawaited(SystemChannels.textInput.invokeMethod<void>('TextInput.hide'));
  }

  bool _hasVisibleImeInsets() {
    final views = WidgetsBinding.instance.platformDispatcher.views;
    for (final view in views) {
      if (view.viewInsets.bottom > 0) return true;
    }
    return false;
  }

  void _saveCurrentRoute() {
    if (!mounted) return;
    final path = ref
        .read(routerProvider)
        .routerDelegate
        .currentConfiguration
        .uri
        .path;
    if (path.isEmpty || path == '/') return;
    final settings = ref.read(hisabSettingsProvidersProvider);
    if (settings != null) {
      final current = ref.read(settings.provider(lastRoutePathSettingDef));
      if (current == path) return;
      ref.read(settings.provider(lastRoutePathSettingDef).notifier).set(path);
      Log.info('Setting changed: ${lastRoutePathSettingDef.key}=$path');
    }
  }

  void _clearSavedRoute() {
    if (!mounted) return;
    final settings = ref.read(hisabSettingsProvidersProvider);
    if (settings != null) {
      final current = ref.read(settings.provider(lastRoutePathSettingDef));
      if (current.isEmpty) return;
      ref.read(settings.provider(lastRoutePathSettingDef).notifier).set('');
      Log.info('Setting changed: ${lastRoutePathSettingDef.key}=(cleared)');
    }
  }

  void _registerAuthListener() {
    _authSubscription?.close();
    _authSubscription = ref.listenManual<bool>(isAuthenticatedProvider, (
      prev,
      isAuth,
    ) {
      if (!mounted) return;
      if (isAuth && prev != true) {
        if (ref.read(notificationsEnabledProvider)) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            unawaited(
              ref
                  .read(notificationServiceProvider.notifier)
                  .initialize(context),
            );
          });
        }
      } else if (!isAuth && prev == true) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          unawaited(
            ref.read(notificationServiceProvider.notifier).unregisterToken(),
          );
        });
      }
    }, fireImmediately: true);
  }

  void _registerUpdateCheckTrigger() {
    if (_updateTriggerRegistered) return;
    _updateTriggerRegistered = true;
    _updateCheckCallback = (BuildContext context) {
      if (_manualUpdateCheckInFlight) return;
      _manualUpdateCheckInFlight = true;
      Future<void>(() async {
        try {
          await _upgrader.updateVersionInfo();
          if (!mounted) return;
          final vi = _upgrader.versionInfo;
          final pkg = _upgrader.state.packageInfo;
          // When HisabUpgrader cleared versionInfo (store ≤ installed), show toast.
          if (vi == null && _upgrader.lastCheckStoreNotNewer) {
            if (context.mounted) context.showToast('no_update_available'.tr());
            return;
          }
          // Don't show update dialog when store version is same or older (e.g. Play
          // Store internal/closed/open testing returning same version).
          if (vi != null &&
              vi.appStoreVersion != null &&
              pkg != null &&
              pkg.version.isNotEmpty) {
            try {
              final installed = Version.parse(pkg.version);
              if (vi.appStoreVersion! <= installed) {
                if (context.mounted) {
                  context.showToast('no_update_available'.tr());
                }
                return;
              }
            } catch (_) {
              // Continue and let upgrader decide if parse failed.
            }
          }
          _upgrader.updateState(
            _upgrader.state.copyWith(debugDisplayAlways: true),
          );
          await Future.delayed(const Duration(milliseconds: 400));
          if (!mounted) return;
          final shouldShow = _upgrader.shouldDisplayUpgrade();
          Log.debug(
            'Upgrader (manual): store=${vi?.appStoreVersion}, installed=${vi?.installedVersion}, showDialog=$shouldShow',
          );
          if (!shouldShow && context.mounted) {
            final msg = _upgrader.versionInfo == null
                ? 'could_not_check_for_updates'.tr()
                : 'no_update_available'.tr();
            context.showToast(msg);
          }
        } catch (e, st) {
          Log.warning(
            'Upgrader (manual): failed to check for updates',
            error: e,
            stackTrace: st,
          );
          if (context.mounted) {
            context.showToast('could_not_check_for_updates'.tr());
          }
        } finally {
          _manualUpdateCheckInFlight = false;
        }
      });
    };
    final dynamic triggerHolder = ref.read(updateCheckTriggerProvider);
    triggerHolder.callback = _updateCheckCallback;
    _clearOwnedUpdateCheckTrigger = () {
      if (identical(triggerHolder.callback, _updateCheckCallback)) {
        triggerHolder.callback = null;
      }
    };
  }

  Widget _buildDebugFab({
    required bool isDebug,
    required bool isRtl,
    required BuildContext context,
    required GoRouter router,
  }) {
    if (!isDebug || isIntegrationTestMode || !_debugFabVisible) {
      return const SizedBox.shrink();
    }
    return Positioned(
      bottom: 96,
      left: isRtl ? null : 8,
      right: isRtl ? 8 : null,
      child: DebugMenuFab(
        upgrader: _upgrader,
        navigatorContext: router.routerDelegate.navigatorKey.currentContext,
        localeContext: context,
        onBeforeOpen: () => setState(() => _debugFabVisible = false),
        whenSheetClosed: () => setState(() => _debugFabVisible = true),
      ),
    );
  }

  Widget _buildRootContent({
    required BuildContext context,
    required Widget contentWithSyncIndicator,
    required bool isDebug,
    required bool isRtl,
    required GoRouter router,
  }) {
    final debugFab = _buildDebugFab(
      isDebug: isDebug,
      isRtl: isRtl,
      context: context,
      router: router,
    );
    final rootChild = _showUpgradeAlert
        ? UpgradeAlert(
            navigatorKey: router.routerDelegate.navigatorKey,
            upgrader: _upgrader,
            onUpdate: () {
              if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
                handleAndroidUpdateThenStore(_upgrader);
                return false;
              }
              return true;
            },
            child: contentWithSyncIndicator,
          )
        : contentWithSyncIndicator;
    return Stack(children: [rootChild, debugFab]);
  }

  @override
  Widget build(BuildContext context) {
    _registerUpdateCheckTrigger();
    final router = ref.watch(routerProvider);
    final themes = ref.watch(appThemesProvider);
    final themeMode = ref.watch(appThemeModeProvider);

    // Watch DataSyncService to reactively fetch/push data
    ref.watch(dataSyncServiceProvider);

    // Locale is read exclusively from EasyLocalization (context.locale) so that
    // locale: and localizationsDelegates always come from the same frame.
    // _LocaleSync (in main.dart) bridges languageProvider → context.setLocale.
    final feedbackTheme = FeedbackThemeData(
      background: themes.light.colorScheme.surfaceContainerHighest,
      feedbackSheetColor: themes.light.colorScheme.surface,
      drawColors: [
        themes.light.colorScheme.primary,
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
          config: ToastificationConfig(
            alignment: Alignment.bottomCenter,
            itemWidth: LayoutBreakpoints.isTabletOrWider(context)
                ? LayoutBreakpoints.sheetDialogMaxWidth
                : (MediaQuery.sizeOf(context).width - 32).clamp(
                    0.0,
                    LayoutBreakpoints.sheetDialogMaxWidth,
                  ),
          ),
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
                    textDirection: isRtl
                        ? ui.TextDirection.rtl
                        : ui.TextDirection.ltr,
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
              return _buildRootContent(
                context: context,
                contentWithSyncIndicator: contentWithSyncIndicator,
                isDebug: isDebug,
                isRtl: isRtl,
                router: router,
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
          backgroundColor: Theme.of(
            context,
          ).colorScheme.surfaceContainerHighest,
        ),
      ),
    );
  }
}
