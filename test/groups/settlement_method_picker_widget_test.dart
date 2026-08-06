import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hisab/domain/domain.dart';
import 'package:hisab/features/groups/widgets/settlement_method_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../widget_test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    EasyLocalization.logger.enableBuildModes = [];
    SharedPreferences.setMockInitialValues({});
  });

  void setPhoneViewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  Widget wrapWithRouter(Widget home) {
    final router = GoRouter(
      initialLocation: '/',
      routes: [GoRoute(path: '/', builder: (context, state) => home)],
    );
    return EasyLocalization(
      path: 'assets/translations',
      supportedLocales: testSupportedLocales,
      fallbackLocale: const Locale('en'),
      startLocale: const Locale('en'),
      child: MaterialApp.router(routerConfig: router),
    );
  }

  test('shouldShowSettleExplainer gates correctly', () {
    expect(
      shouldShowSettleExplainer(
        seen: false,
        readOnlyMode: false,
        isPersonal: false,
      ),
      isTrue,
    );
    expect(
      shouldShowSettleExplainer(
        seen: true,
        readOnlyMode: false,
        isPersonal: false,
      ),
      isFalse,
    );
    expect(
      shouldShowSettleExplainer(
        seen: false,
        readOnlyMode: true,
        isPersonal: false,
      ),
      isFalse,
    );
    expect(
      shouldShowSettleExplainer(
        seen: false,
        readOnlyMode: false,
        isPersonal: true,
      ),
      isFalse,
    );
  });

  testWidgets('guide card shows live plan chip and method content', (
    tester,
  ) async {
    setPhoneViewport(tester);
    await tester.pumpWidget(
      wrapWithRouter(
        const Scaffold(
          body: SettlementMethodGuideCard(
            method: SettlementMethod.greedy,
            showExample: true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(SettlementMethodGuideCard), findsOneWidget);
    expect(find.byIcon(Icons.bolt_outlined), findsOneWidget);
    expect(find.byIcon(Icons.help_outline_rounded), findsOneWidget);
    expect(
      find.text('settlement_live_plan_chip_reshuffle'.tr()),
      findsOneWidget,
    );
    expect(
      find.text('settlement_guide_live_line_reshuffle'.tr()),
      findsOneWidget,
    );
    expect(find.text('settlement_method_greedy'.tr()), findsOneWidget);
  });

  testWidgets('guide card for other methods has no live-plan chip', (
    tester,
  ) async {
    setPhoneViewport(tester);
    await tester.pumpWidget(
      wrapWithRouter(
        const Scaffold(
          body: SettlementMethodGuideCard(method: SettlementMethod.treasurer),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('settlement_method_treasurer'.tr()), findsOneWidget);
    expect(find.text('settlement_live_plan_chip_reshuffle'.tr()), findsNothing);
    expect(
      find.text('settlement_guide_live_line_reshuffle'.tr()),
      findsNothing,
    );
  });

  testWidgets('picker sheet shows greedy option and footer', (tester) async {
    setPhoneViewport(tester);
    await tester.pumpWidget(
      wrapWithRouter(
        Scaffold(
          body: Builder(
            builder: (ctx) => TextButton(
              onPressed: () => showSettlementMethodPickerSheet(
                ctx,
                selected: SettlementMethod.greedy,
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.bolt_outlined), findsWidgets);
    // Live-plan chip only on Fewest payments.
    expect(
      find.text('settlement_live_plan_chip_reshuffle'.tr()),
      findsOneWidget,
    );
    expect(find.text('settlement_picker_footer'.tr()), findsOneWidget);
  });

  testWidgets('info on guide opens explainer', (tester) async {
    setPhoneViewport(tester);
    await tester.pumpWidget(
      wrapWithRouter(
        const Scaffold(
          body: SettlementMethodGuideCard(method: SettlementMethod.pairwise),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.help_outline_rounded));
    await tester.pumpAndSettle();

    expect(find.text('settle_up_explainer_title'.tr()), findsWidgets);
    expect(find.text('settle_up_explainer_one_at_a_time'.tr()), findsOneWidget);
  });

  testWidgets('SettleUpExplainerBody renders three beats', (tester) async {
    setPhoneViewport(tester);
    await tester.pumpWidget(
      wrapWithRouter(const Scaffold(body: SettleUpExplainerBody())),
    );
    await tester.pumpAndSettle();

    expect(find.text('settle_up_explainer_balance'.tr()), findsOneWidget);
    expect(find.text('settle_up_explainer_suggestions'.tr()), findsOneWidget);
    expect(find.text('settle_up_explainer_one_at_a_time'.tr()), findsOneWidget);
  });
}
