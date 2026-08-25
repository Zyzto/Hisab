import '../domain/scanner_category_rule.dart';

/// Builtin merchant/keyword → preset category id (EN + AR).
const Map<String, String> builtinCategoryKeywords = {
  'uber': 'transport',
  'careem': 'transport',
  'bolt': 'transport',
  'lyft': 'transport',
  'taxi': 'transport',
  'metro': 'transport',
  'parking': 'transport',
  'petrol': 'transport',
  'gas station': 'transport',
  'shell': 'transport',
  'aramco': 'transport',
  'كريم': 'transport',
  'أوبر': 'transport',
  'starbucks': 'coffee',
  'costa': 'coffee',
  'dunkin': 'coffee',
  'cafe': 'coffee',
  'coffee': 'coffee',
  'ستاربكس': 'coffee',
  'قهوة': 'coffee',
  'netflix': 'subscriptions',
  'spotify': 'subscriptions',
  'apple.com/bill': 'subscriptions',
  'youtube': 'subscriptions',
  'icloud': 'subscriptions',
  'subscription': 'subscriptions',
  'اشتراك': 'subscriptions',
  'carrefour': 'groceries',
  'lulu': 'groceries',
  'panda': 'groceries',
  'tamimi': 'groceries',
  'grocery': 'groceries',
  'supermarket': 'groceries',
  'كارفور': 'groceries',
  'لولو': 'groceries',
  'بنده': 'groceries',
  'تموينات': 'groceries',
  'mcdonald': 'food',
  'kfc': 'food',
  'restaurant': 'food',
  'hungry': 'food',
  'talabat': 'food',
  'jahez': 'food',
  'hungerstation': 'food',
  'مطعم': 'food',
  'جاهز': 'food',
  'طلبات': 'food',
  'amazon': 'shopping',
  'noon': 'shopping',
  'namshi': 'shopping',
  'ikea': 'shopping',
  'store': 'shopping',
  'نون': 'shopping',
  'أمازون': 'shopping',
  'muvi': 'entertainment',
  'vox': 'entertainment',
  'cinema': 'entertainment',
  'سينما': 'entertainment',
  'stc': 'bills',
  'mobily': 'bills',
  'zain': 'bills',
  'sec': 'bills',
  'nwc': 'bills',
  'utility': 'bills',
  'electric': 'bills',
  'فاتورة': 'bills',
  'كهرباء': 'bills',
  'pharmacy': 'health',
  'hospital': 'health',
  'clinic': 'health',
  'صيدلية': 'health',
  'مستشفى': 'health',
  'hotel': 'travel',
  'airline': 'travel',
  'flight': 'travel',
  'booking': 'travel',
  'فندق': 'travel',
  'طيران': 'travel',
  'school': 'education',
  'university': 'education',
  'udemy': 'education',
  'مدرسة': 'education',
  'جامعة': 'education',
  'gift': 'gifts',
  'donation': 'gifts',
  'تبرع': 'gifts',
  'هدية': 'gifts',
};

/// Resolves a preset category id from merchant, place, sender, then raw text.
String? suggestCategory({
  String? merchant,
  String? place,
  String? senderTitle,
  String? rawText,
  List<ScannerCategoryRule> extraRules = const [],
}) {
  final haystacks = <String>[
    if (merchant != null) merchant,
    if (place != null) place,
    if (senderTitle != null) senderTitle,
    if (rawText != null) rawText,
  ];

  for (final rule in extraRules) {
    final needle = rule.merchantPattern.trim().toLowerCase();
    if (needle.isEmpty) continue;
    for (final hay in haystacks) {
      if (hay.toLowerCase().contains(needle)) return rule.categoryId;
    }
  }

  for (final hay in haystacks) {
    final lower = hay.toLowerCase();
    for (final entry in builtinCategoryKeywords.entries) {
      if (lower.contains(entry.key)) return entry.value;
    }
  }
  return null;
}
