import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/app_scroll_behavior.dart';
import 'core/theme/theme_config.dart';
import 'core/navigation/app_router.dart';

class App extends ConsumerWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    // Theme: use defaults for bootstrap; settings providers will be added in step 6
    const themeMode = ThemeMode.system;
    const themeColor = ThemeConfig.defaultSeedColor;
    const fontSizeScale = 'normal';

    final lightTheme = AppTheme.lightTheme(
      seedColor: themeColor,
      fontSizeScale: fontSizeScale,
    );
    final darkTheme = AppTheme.darkTheme(
      seedColor: themeColor,
      fontSizeScale: fontSizeScale,
    );

    return MaterialApp.router(
      title: 'Hisab',
      debugShowCheckedModeBanner: kDebugMode,
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
      theme: lightTheme,
      darkTheme: darkTheme,
      themeMode: themeMode,
      routerConfig: router,
    );
  }
}
