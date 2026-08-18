import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Placeholders easy_localization interpolates: `{name}`, `{}`, `{{appName}}`.
final _placeholderPattern = RegExp(r'\{[^{}]*\}');

/// Dialect / calque markers from [docs/AR_LOCALIZATION.md].
const _arabicDialectMarkers = [
  'عشان',
  'يشوف',
  'تشوف',
  'ليش',
  'أصحابكم',
  'لما تصير',
  'مصروفات',
  'إشعارات الدفع',
];

/// Push copy duplicated in hisab-cloud `send-notification` NOTIFICATION_STRINGS.
/// Changing these app values means the Edge Function strings need the same change.
const _pushCopyMustMatchServer = {
  'notification_group_activity': ('Group activity', 'نشاط المجموعة'),
  'notification_member_joined': (
    'A new member joined the group.',
    'انضم عضو جديد إلى المجموعة.',
  ),
  'notification_expense_updated': ('Edit', 'تعديل'),
  'notification_expense_deleted': ('Deleted', 'تم الحذف'),
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Map<String, String> en;
  late Map<String, String> ar;

  setUpAll(() async {
    en = _stringMap(
      jsonDecode(await rootBundle.loadString('assets/translations/en.json')),
    );
    ar = _stringMap(
      jsonDecode(await rootBundle.loadString('assets/translations/ar.json')),
    );
  });

  group('Translation files', () {
    test('en.json and ar.json are valid JSON with string values', () {
      expect(en, isNotEmpty);
      expect(ar, isNotEmpty);
    });

    test('both locales have the same set of keys', () {
      final enKeys = en.keys.toSet();
      final arKeys = ar.keys.toSet();
      expect(
        enKeys.difference(arKeys),
        isEmpty,
        reason: 'Keys in en but not in ar',
      );
      expect(
        arKeys.difference(enKeys),
        isEmpty,
        reason: 'Keys in ar but not in en',
      );
    });

    test('every value is non-empty in both locales', () {
      final emptyEn = [
        for (final e in en.entries)
          if (e.value.trim().isEmpty) e.key,
      ];
      final emptyAr = [
        for (final e in ar.entries)
          if (e.value.trim().isEmpty) e.key,
      ];
      expect(emptyEn, isEmpty, reason: 'Empty English values: $emptyEn');
      expect(emptyAr, isEmpty, reason: 'Empty Arabic values: $emptyAr');
    });

    test('placeholders match between en and ar', () {
      final mismatches = <String>[];
      for (final key in en.keys) {
        final enTokens = _placeholderPattern
            .allMatches(en[key]!)
            .map((m) => m.group(0)!)
            .toList();
        final arTokens = _placeholderPattern
            .allMatches(ar[key]!)
            .map((m) => m.group(0)!)
            .toList();
        enTokens.sort();
        arTokens.sort();
        if (!_listEquals(enTokens, arTokens)) {
          mismatches.add('$key: en $enTokens vs ar $arTokens');
        }
      }
      expect(mismatches, isEmpty, reason: mismatches.join('\n'));
    });
  });

  group('Dart usage vs JSON', () {
    test('referenced translation keys exist in en.json', () {
      final referenced = _collectReferencedKeys(Directory('lib'));
      final missing = referenced.difference(en.keys.toSet()).toList()..sort();
      expect(
        missing,
        isEmpty,
        reason:
            'UI references keys that are missing from en.json (add both '
            'en.json and ar.json in the same change):\n${missing.join('\n')}',
      );
    });

    test('preset category ids have category_* keys', () {
      final ids = _presetCategoryIds();
      expect(ids, isNotEmpty, reason: 'Failed to parse presetCategoryTags');
      final missing = [
        for (final id in ids)
          if (!en.containsKey('category_$id')) id,
      ];
      expect(
        missing,
        isEmpty,
        reason: 'Add category_<id> to en.json and ar.json: $missing',
      );
    });

    test('theme scheme ids have theme_scheme_* keys', () {
      final ids = _flexSchemeOptionIds();
      expect(ids, isNotEmpty, reason: 'Failed to parse flexSchemeOptionIds');
      final missing = [
        for (final id in ids)
          if (!en.containsKey('theme_scheme_$id')) id,
      ];
      expect(
        missing,
        isEmpty,
        reason: 'Add theme_scheme_<id> to en.json and ar.json: $missing',
      );
    });

    test('group icon options have wizard_icon_* keys', () {
      final keys = _groupIconLabelKeys();
      expect(keys, isNotEmpty, reason: 'Failed to parse groupIcons');
      final missing = [
        for (final key in keys)
          if (!en.containsKey(key)) key,
      ];
      expect(missing, isEmpty, reason: 'Missing wizard icon keys: $missing');
    });
  });

  group('Arabic MSA / Venus', () {
    test('UI copy has no dialect or glossary-forbidden markers', () {
      final hits = <String>[];
      for (final entry in ar.entries) {
        if (entry.key.startsWith('privacy_policy_')) continue;
        for (final marker in _arabicDialectMarkers) {
          if (entry.value.contains(marker)) {
            hits.add('${entry.key}: contains "$marker"');
          }
        }
      }
      expect(hits, isEmpty, reason: hits.join('\n'));
    });

    test('glossary terms match AR_LOCALIZATION.md', () {
      expect(ar['expenses'], contains('مصاريف'));
      expect(ar['balance'], 'الحسابات');
      expect(ar['your_balance'], contains('رصيد'));
      expect(ar['analytics'], 'الإحصاءات');
      expect(ar['notifications_enabled'], 'إشعارات فورية');
      expect(ar['receipt'], contains('إيصال'));
      expect(ar['scan_receipt'], contains('إيصال'));
      expect(ar['paid_by'], contains('دفعها'));
    });

    test('push prefixes stay in sync with documented server copy', () {
      for (final entry in _pushCopyMustMatchServer.entries) {
        expect(en[entry.key], entry.value.$1, reason: entry.key);
        expect(ar[entry.key], entry.value.$2, reason: entry.key);
      }
    });
  });
}

Map<String, String> _stringMap(Object? decoded) {
  final map = decoded as Map<String, dynamic>;
  return {for (final e in map.entries) e.key: e.value as String};
}

bool _listEquals(List<String> a, List<String> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

final _trCall = RegExp(r"""['"]([a-z][a-z0-9_]{2,})['"]\s*\.tr\s*\(""");
final _trArg = RegExp(r"""\.tr\s*\(\s*['"]([a-z][a-z0-9_]{2,})['"]""");
final _namedKeyField = RegExp(
  r"""(?:titleKey|subtitleKey|labelKey)\s*[:=]\s*['"]([a-z][a-z0-9_]{2,})['"]""",
);
final _optionLabelsBlock = RegExp(r'optionLabels:\s*\{(.*?)\},', dotAll: true);
final _optionLabelValue = RegExp(
  r"""['"][^'"]+['"]\s*:\s*['"]([a-z][a-z0-9_]{2,})['"]""",
);
final _authErrorConst = RegExp(
  r"""static const String \w+ = '([a-z][a-z0-9_]+)';""",
);
final _labelKeysMap = RegExp(r'LabelKeys\s*=\s*\{(.*?)\};', dotAll: true);
final _quotedKey = RegExp(r"""['"]([a-z][a-z0-9_]{2,})['"]""");
final _expiryOption = RegExp(r"""_ExpiryOption\(\s*'([a-z][a-z0-9_]+)'""");
final _experimentStyleKey = RegExp(r"""'(theme_style_[a-z_]+)'""");
final _oauthCallbackKey = RegExp(
  r"""pendingWebOAuthCallbackError\s*=\s*'([a-z][a-z0-9_]+)'""",
);

Set<String> _collectReferencedKeys(Directory libDir) {
  final keys = <String>{};
  for (final entity in libDir.listSync(recursive: true)) {
    if (entity is! File || !entity.path.endsWith('.dart')) continue;
    if (entity.path.endsWith('.g.dart')) continue;
    final source = entity.readAsStringSync();
    final hideHiddenSettings = entity.path.endsWith(
      'settings_definitions.dart',
    );

    for (final match in _trCall.allMatches(source)) {
      keys.add(match.group(1)!);
    }
    for (final match in _trArg.allMatches(source)) {
      keys.add(match.group(1)!);
    }
    for (final match in _namedKeyField.allMatches(source)) {
      if (hideHiddenSettings && _settingBlockIsHidden(source, match.start)) {
        continue;
      }
      keys.add(match.group(1)!);
    }
    for (final block in _optionLabelsBlock.allMatches(source)) {
      for (final value in _optionLabelValue.allMatches(block.group(1)!)) {
        keys.add(value.group(1)!);
      }
    }
    if (source.contains('abstract final class AuthErrorKeys')) {
      for (final match in _authErrorConst.allMatches(source)) {
        keys.add(match.group(1)!);
      }
    }
    for (final block in _labelKeysMap.allMatches(source)) {
      for (final value in _quotedKey.allMatches(block.group(1)!)) {
        final key = value.group(1)!;
        if (key.contains('_')) keys.add(key);
      }
    }
    for (final match in _expiryOption.allMatches(source)) {
      keys.add(match.group(1)!);
    }
    for (final match in _experimentStyleKey.allMatches(source)) {
      keys.add(match.group(1)!);
    }
    for (final match in _oauthCallbackKey.allMatches(source)) {
      keys.add(match.group(1)!);
    }
  }
  return keys;
}

bool _settingBlockIsHidden(String source, int offset) {
  final close = source.indexOf(');', offset);
  if (close == -1) return false;
  return source.substring(offset, close).contains('visible: false');
}

List<String> _presetCategoryIds() {
  final source = File(
    'lib/features/expenses/category_icons.dart',
  ).readAsStringSync();
  final block = RegExp(
    r'presetCategoryTags = \[([\s\S]*?)\];',
  ).firstMatch(source);
  if (block == null) return const [];
  return [
    for (final m in RegExp(r"id:\s*'([a-z_]+)'").allMatches(block.group(1)!))
      m.group(1)!,
  ];
}

List<String> _flexSchemeOptionIds() {
  final source = File(
    'lib/core/theme/flex_theme_builder.dart',
  ).readAsStringSync();
  final block = RegExp(
    r'flexSchemeOptionIds = \[([\s\S]*?)\];',
  ).firstMatch(source);
  if (block == null) return const [];
  return [
    for (final m in RegExp(r"'([A-Za-z0-9_]+)'").allMatches(block.group(1)!))
      m.group(1)!,
  ];
}

List<String> _groupIconLabelKeys() {
  final source = File(
    'lib/features/groups/utils/group_icon_utils.dart',
  ).readAsStringSync();
  return [
    for (final m in RegExp(r"'(wizard_icon_[a-z_]+)'").allMatches(source))
      m.group(1)!,
  ];
}
