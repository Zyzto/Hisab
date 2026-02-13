import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import 'core/auth/auth_providers.dart';
import 'core/database/database_providers.dart';
import 'core/services/notification_service.dart';
import 'core/theme/app_scroll_behavior.dart';
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

    // Watch DataSyncService to reactively fetch/push data
    ref.watch(dataSyncServiceProvider);

    // Initialize push notifications when user authenticates.
    // listen handles sign-in/sign-out transitions; watch handles initial state.
    ref.listen(isAuthenticatedProvider, (prev, isAuth) {
      if (isAuth && prev != true) {
        ref.read(notificationServiceProvider.notifier).initialize();
      } else if (!isAuth && prev == true) {
        ref.read(notificationServiceProvider.notifier).unregisterToken();
      }
    });
    // Handle already-authenticated on first build (initialize() is idempotent).
    if (ref.read(isAuthenticatedProvider)) {
      Future.microtask(
        () => ref.read(notificationServiceProvider.notifier).initialize(),
      );
    }

    // Locale is read exclusively from EasyLocalization (context.locale) so that
    // locale: and localizationsDelegates always come from the same frame.
    // _LocaleSync (in main.dart) bridges languageProvider → context.setLocale.
    return InviteLinkHandler(
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
          return Directionality(
            textDirection: isRtl ? ui.TextDirection.rtl : ui.TextDirection.ltr,
            child: child ?? const SizedBox.shrink(),
          );
        },
        theme: themes.light,
        darkTheme: themes.dark,
        themeMode: themeMode,
        routerConfig: router
      ),
    );
  }
}
