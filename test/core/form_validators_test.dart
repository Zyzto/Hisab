import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hisab/core/utils/form_validators.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../widget_test_helpers.dart';

void main() {
  setUpAll(() async {
    EasyLocalization.logger.enableBuildModes = [];
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('required rejects blank and whitespace', (tester) async {
    await pumpApp(tester, child: const SizedBox.shrink());
    expect(FormValidators.required(null), isNotNull);
    expect(FormValidators.required(''), isNotNull);
    expect(FormValidators.required('   '), isNotNull);
    expect(FormValidators.required('ok'), isNull);
  });

  testWidgets('groupName enforces 1–200', (tester) async {
    await pumpApp(tester, child: const SizedBox.shrink());
    expect(FormValidators.groupName('Trip'), isNull);
    expect(FormValidators.groupName(''), isNotNull);
    expect(FormValidators.groupName('a' * 201), isNotNull);
    expect(FormValidators.groupName('a' * 200), isNull);
  });

  testWidgets('participantName enforces 1–100', (tester) async {
    await pumpApp(tester, child: const SizedBox.shrink());
    expect(FormValidators.participantName('Ali'), isNull);
    expect(FormValidators.participantName('a' * 101), isNotNull);
  });

  testWidgets('expenseTitle enforces 1–500', (tester) async {
    await pumpApp(tester, child: const SizedBox.shrink());
    expect(FormValidators.expenseTitle('Lunch'), isNull);
    expect(FormValidators.expenseTitle('a' * 501), isNotNull);
  });

  testWidgets('positiveAmount rejects zero/negative/invalid', (tester) async {
    await pumpApp(tester, child: const SizedBox.shrink());
    expect(FormValidators.positiveAmount('12.5'), isNull);
    expect(FormValidators.positiveAmount('0'), isNotNull);
    expect(FormValidators.positiveAmount('-1'), isNotNull);
    expect(FormValidators.positiveAmount('abc'), isNotNull);
    expect(FormValidators.positiveAmount(''), isNotNull);
  });

  testWidgets('email accepts plausible addresses', (tester) async {
    await pumpApp(tester, child: const SizedBox.shrink());
    expect(FormValidators.email('a@b.co'), isNull);
    expect(FormValidators.email('first.last+tag@sub.example.com'), isNull);
    // Trimmed before matching, so a stray space from autofill is not an error.
    expect(FormValidators.email('  a@b.co  '), isNull);
  });

  testWidgets('email rejects typos and blanks', (tester) async {
    await pumpApp(tester, child: const SizedBox.shrink());
    expect(FormValidators.email(null), isNotNull);
    expect(FormValidators.email(''), isNotNull);
    expect(FormValidators.email('   '), isNotNull);
    expect(FormValidators.email('nope'), isNotNull);
    expect(FormValidators.email('no@domain'), isNotNull);
    expect(FormValidators.email('@example.com'), isNotNull);
    expect(FormValidators.email('two@at@example.com'), isNotNull);
    expect(FormValidators.email('spaced out@example.com'), isNotNull);
  });

  testWidgets('password enforces the Supabase minimum', (tester) async {
    await pumpApp(tester, child: const SizedBox.shrink());
    expect(FormValidators.passwordMin, 6);
    expect(FormValidators.password(null), isNotNull);
    expect(FormValidators.password(''), isNotNull);
    expect(FormValidators.password('a' * 5), isNotNull);
    expect(FormValidators.password('a' * 6), isNull);
  });

  testWidgets('password never trims, so spaces count', (tester) async {
    await pumpApp(tester, child: const SizedBox.shrink());
    expect(FormValidators.password('      '), isNull);
  });

  testWidgets('short and empty passwords fail differently', (tester) async {
    await pumpApp(tester, child: const SizedBox.shrink());
    expect(
      FormValidators.password('abc'),
      isNot(FormValidators.password('')),
      reason: 'blank should say "required", not "too short"',
    );
  });
}
