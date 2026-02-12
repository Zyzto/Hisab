import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import 'core/theme/app_scroll_behavior.dart';
import 'core/theme/theme_providers.dart';
import 'core/navigation/app_router.dart';
import 'features/settings/providers/settings_framework_providers.dart';

class App extends ConsumerWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final themes = ref.watch(appThemesProvider);
    final themeMode = ref.watch(appThemeModeProvider);
    final languageCode = ref.watch(languageProvider);

    return MaterialApp.router(
      title: 'Hisab',
      debugShowCheckedModeBanner: kDebugMode,
      scrollBehavior: AppScrollBehavior(),
      localizationsDelegates: context.localizationDelegates,
      supportedLocales: context.supportedLocales,
      locale: Locale(languageCode),
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
      routerConfig: router,
    );
  }
}
