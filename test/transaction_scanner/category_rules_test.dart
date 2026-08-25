import 'package:flutter_test/flutter_test.dart';
import 'package:hisab/features/transaction_scanner/domain/scanner_category_rule.dart';
import 'package:hisab/features/transaction_scanner/services/category_rules.dart';

void main() {
  test('maps English merchant keywords', () {
    expect(suggestCategory(merchant: 'Starbucks Riyadh'), 'coffee');
    expect(suggestCategory(merchant: 'Uber Trip'), 'transport');
    expect(suggestCategory(rawText: 'Netflix monthly'), 'subscriptions');
  });

  test('maps Arabic keywords', () {
    expect(suggestCategory(merchant: 'كريم'), 'transport');
    expect(suggestCategory(place: 'كارفور'), 'groceries');
  });

  test('learned rules win over builtins', () {
    final rules = [
      ScannerCategoryRule(
        id: '1',
        merchantPattern: 'starbucks',
        categoryId: 'gifts',
        source: CategoryRuleSource.learned,
        createdAt: DateTime(2026, 1, 1),
      ),
    ];
    expect(suggestCategory(merchant: 'Starbucks', extraRules: rules), 'gifts');
  });
}
