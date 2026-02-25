import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hisab/domain/domain.dart';
import 'package:hisab/features/expenses/widgets/expense_split_section.dart';

void main() {
  final now = DateTime(2025, 1, 15);
  late List<Participant> participants;

  setUpAll(() {
    EasyLocalization.logger.enableBuildModes = [];
  });

  setUp(() {
    participants = [
      Participant(
        id: 'p1',
        groupId: 'g1',
        name: 'Alice',
        order: 0,
        createdAt: now,
        updatedAt: now,
      ),
      Participant(
        id: 'p2',
        groupId: 'g1',
        name: 'Bob',
        order: 1,
        createdAt: now,
        updatedAt: now,
      ),
    ];
  });

  Widget buildSplitSection({
    required SplitType splitType,
    required Set<String> includedInSplitIds,
    Map<String, String>? customSplitValues,
    Map<String, TextEditingController>? splitEditControllers,
    Map<String, FocusNode>? splitFocusNodes,
  }) {
    final sharesCents = splitType == SplitType.equal
        ? [2500, 2500]
        : [2500, 2500];
    customSplitValues ??= {};
    splitEditControllers ??= {};
    splitFocusNodes ??= {};
    return ExpenseSplitSection(
      participants: participants,
      sharesCents: sharesCents,
      amountCents: 5000,
      currencyCode: 'USD',
      splitType: splitType,
      includedInSplitIds: includedInSplitIds,
      customSplitValues: customSplitValues,
      splitEditControllers: splitEditControllers,
      splitFocusNodes: splitFocusNodes,
      getOrCreateController: (_) => null,
      getOrCreateFocusNode: (_) => null,
      onSplitTypeTap: () {},
      onIncludeChanged: (_, _) {},
      onAmountChanged: (_, _, _, _) {},
      onPartsChanged: (_, _) {},
      amountsSumCents: () => 5000,
    );
  }

  testWidgets('ExpenseSplitSection shows split label', (tester) async {
    await tester.pumpWidget(
      EasyLocalization(
        path: 'assets/translations',
        supportedLocales: const [Locale('en')],
        fallbackLocale: const Locale('en'),
        startLocale: const Locale('en'),
        child: MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: buildSplitSection(
                splitType: SplitType.equal,
                includedInSplitIds: {'p1', 'p2'},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(ExpenseSplitSection), findsOneWidget);
  });

  testWidgets('ExpenseSplitSection shows participant names for equal split', (tester) async {
    await tester.pumpWidget(
      EasyLocalization(
        path: 'assets/translations',
        supportedLocales: const [Locale('en')],
        fallbackLocale: const Locale('en'),
        startLocale: const Locale('en'),
        child: MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: buildSplitSection(
                splitType: SplitType.equal,
                includedInSplitIds: {'p1', 'p2'},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Alice'), findsOneWidget);
    expect(find.text('Bob'), findsOneWidget);
  });
}
