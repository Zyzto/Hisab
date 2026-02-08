import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/app_scroll_behavior.dart';
import 'core/navigation/app_router.dart';
import 'features/settings/providers/settings_framework_providers.dart';

class App extends ConsumerWidget {
  const App({super.key});

  static ThemeMode _themeModeFromString(String value) {
    switch (value) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      case 'amoled':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final themeModeValue = ref.watch(themeModeProvider);
    final themeColorValue = ref.watch(themeColorProvider);
    final fontSizeScaleValue = ref.watch(fontSizeScaleProvider);
    final languageCode = ref.watch(languageProvider);

    final themeMode = _themeModeFromString(themeModeValue);
    final themeColor = Color(themeColorValue);
    final fontSizeScale = fontSizeScaleValue;

    final lightTheme = AppTheme.lightTheme(
      seedColor: themeColor,
      fontSizeScale: fontSizeScale,
    );
    final darkTheme = themeModeValue == 'amoled'
        ? AppTheme.amoledTheme(
            seedColor: themeColor,
            fontSizeScale: fontSizeScale,
          )
        : AppTheme.darkTheme(
            seedColor: themeColor,
            fontSizeScale: fontSizeScale,
          );

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
      theme: lightTheme,
      darkTheme: darkTheme,
      themeMode: themeMode,
      routerConfig: router,
    );
  }
}
