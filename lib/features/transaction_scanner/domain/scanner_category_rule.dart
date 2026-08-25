/// Source of a merchant → category mapping.
enum CategoryRuleSource {
  builtin,
  user,
  learned;

  static CategoryRuleSource fromString(String s) => CategoryRuleSource.values
      .firstWhere((v) => v.name == s, orElse: () => CategoryRuleSource.user);
}

/// Local rule that maps merchant/keyword text to a category id.
class ScannerCategoryRule {
  final String id;
  final String merchantPattern;
  final String categoryId;
  final CategoryRuleSource source;
  final int hitCount;
  final DateTime createdAt;

  const ScannerCategoryRule({
    required this.id,
    required this.merchantPattern,
    required this.categoryId,
    this.source = CategoryRuleSource.user,
    this.hitCount = 0,
    required this.createdAt,
  });

  ScannerCategoryRule copyWith({
    String? merchantPattern,
    String? categoryId,
    CategoryRuleSource? source,
    int? hitCount,
    DateTime? createdAt,
  }) {
    return ScannerCategoryRule(
      id: id,
      merchantPattern: merchantPattern ?? this.merchantPattern,
      categoryId: categoryId ?? this.categoryId,
      source: source ?? this.source,
      hitCount: hitCount ?? this.hitCount,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
