import 'dart:ui' as ui;
import 'package:feedback/feedback.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:upgrader/upgrader.dart';
import 'core/auth/auth_providers.dart';
import 'core/database/database_providers.dart';
import 'core/services/notification_service.dart';
import 'core/update/app_update_helper.dart';
import 'core/update/upgrader_messages.dart';
import 'features/settings/providers/settings_framework_providers.dart';
import 'core/theme/app_scroll_behavior.dart';
import 'core/theme/theme_config.dart';
import 'core/theme/theme_providers.dart';
import 'core/navigation/app_router.dart';
import 'core/navigation/invite_link_handler.dart';

class App extends ConsumerWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final themes = ref.watch(appThemesProvider);
    final themeMode = ref.watch(appThemeModeProvider);
    final upgrader = Upgrader(
      durationUntilAlertAgain: const Duration(days: 3),
      messages: HisabUpgraderMessages(code: context.locale.languageCode, context: context),
    );

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
    // Handle already-authenticated on first build (initialize() is idempotent).
    if (ref.read(isAuthenticatedProvider) &&
        ref.read(notificationsEnabledProvider)) {
      Future.microtask(() {
        if (!context.mounted) return;
        ref.read(notificationServiceProvider.notifier).initialize(context);
      });
    }

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
        child: MaterialApp.router(
        title: 'Hisab',
        debugShowCheckedModeBanner: false,
        scrollBehavior: AppScrollBehavior(),
        localizationsDelegates: context.localizationDelegates,
        supportedLocales: context.supportedLocales,
        locale: context.locale,
        builder: (context, child) {
          final isRtl = context.locale.languageCode == 'ar';
          return UpgradeAlert(
            navigatorKey: router.routerDelegate.navigatorKey,
            upgrader: upgrader,
            onUpdate: () {
              if (!kIsWeb &&
                  defaultTargetPlatform == TargetPlatform.android) {
                handleAndroidUpdateThenStore(upgrader);
                return false;
              }
              return true;
            },
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
        },
        theme: themes.light,
        darkTheme: themes.dark,
        themeMode: themeMode,
        routerConfig: router,
        ),
      ),
    );
  }
}
