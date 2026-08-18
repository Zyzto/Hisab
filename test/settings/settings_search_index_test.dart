import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_settings_framework/flutter_settings_framework.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hisab/core/settings/settings_definitions.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SearchIndex index;

  setUpAll(() async {
    final enRaw =
        jsonDecode(await rootBundle.loadString('assets/translations/en.json'))
            as Map;
    final arRaw =
        jsonDecode(await rootBundle.loadString('assets/translations/ar.json'))
            as Map;
    final en = enRaw.map((k, v) => MapEntry(k.toString(), v?.toString() ?? ''));
    final ar = arRaw.map((k, v) => MapEntry(k.toString(), v?.toString() ?? ''));

    index = SearchIndex(
      registry: createHisabSettingsRegistry(),
      localizationProvider: PreIndexedLocalizationProvider({
        'en': en,
        'ar': ar,
      }),
    );
    await index.build();
  });

  test('Arabic usage-tracking synonyms find telemetry', () {
    for (final query in ['تحليلات', 'إحصاءات']) {
      final results = index.search(query);
      expect(
        results.map((r) => r.setting.key),
        contains('telemetry_enabled'),
        reason: query,
      );
    }
  });

  test('Arabic query finds theme while UI terms are English-indexed too', () {
    final results = index.search('داكن');
    expect(results.map((r) => r.setting.key), contains('theme_mode'));
  });

  test('English query finds language setting', () {
    final results = index.search('locale');
    expect(results.map((r) => r.setting.key), contains('language'));
  });

  test('action rows are searchable', () {
    final exportHits = index.search('backup');
    expect(
      exportHits.map((r) => r.setting.key),
      contains('action_export_data'),
    );

    final privacyHits = index.search('privacy');
    expect(
      privacyHits.map((r) => r.setting.key),
      contains('action_privacy_policy'),
    );
  });

  test('internal settings never appear in results', () {
    // Exact key match is indexed but filtered by visible:false.
    final byKey = index.search('pending_invite_token');
    expect(
      byKey.map((r) => r.setting.key),
      isNot(contains('pending_invite_token')),
    );
    final byOnboarding = index.search('onboarding_online_pending');
    expect(
      byOnboarding.map((r) => r.setting.key),
      isNot(contains('onboarding_online_pending')),
    );
    expect(index.getTermsForSetting('pending_invite_token'), isNotEmpty);
  });

  test('home_list display is indexed but settings page filters separately', () {
    final results = index.search('home_list_display');
    // Still in registry/index; UI excludes the section.
    expect(results.any((r) => r.setting.section == 'home_list'), isTrue);
  });
}
