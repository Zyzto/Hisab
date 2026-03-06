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

  testWidgets('ExpenseSplitSection shows participant names for equal split', (
    tester,
  ) async {
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

  testWidgets('parts split +/- buttons update parts value', (tester) async {
    final customSplitValues = <String, String>{'p1': '1', 'p2': '1'};
    final controllers = <String, TextEditingController>{
      'p1': TextEditingController(text: '1'),
      'p2': TextEditingController(text: '1'),
    };
    final focusNodes = <String, FocusNode>{
      'p1': FocusNode(),
      'p2': FocusNode(),
    };
    final updates = <String>[];

    await tester.pumpWidget(
      EasyLocalization(
        path: 'assets/translations',
        supportedLocales: const [Locale('en')],
        fallbackLocale: const Locale('en'),
        startLocale: const Locale('en'),
        child: MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ExpenseSplitSection(
                participants: participants,
                sharesCents: const [2500, 2500],
                amountCents: 5000,
                currencyCode: 'USD',
                splitType: SplitType.parts,
                includedInSplitIds: const {'p1', 'p2'},
                customSplitValues: customSplitValues,
                splitEditControllers: controllers,
                splitFocusNodes: focusNodes,
                getOrCreateController: (p) => controllers[p.id],
                getOrCreateFocusNode: (p) => focusNodes[p.id],
                onSplitTypeTap: () {},
                onIncludeChanged: (_, _) {},
                onAmountChanged: (_, _, _, _) {},
                onPartsChanged: (p, v) {
                  customSplitValues[p.id] = v;
                  updates.add('${p.id}:$v');
                },
                amountsSumCents: () => 5000,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.add).first);
    await tester.pumpAndSettle();
    expect(updates.last, 'p1:2');
    expect(customSplitValues['p1'], '2');

    await tester.tap(find.byIcon(Icons.remove).first);
    await tester.pumpAndSettle();
    expect(updates.last, 'p1:1');
    expect(customSplitValues['p1'], '1');

    for (final c in controllers.values) {
      c.dispose();
    }
    for (final f in focusNodes.values) {
      f.dispose();
    }
  });
}
