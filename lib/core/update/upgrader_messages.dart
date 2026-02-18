import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:upgrader/upgrader.dart';

/// Upgrader messages from EasyLocalization (assets/translations) so the update
/// dialog uses the same locale pipeline as the rest of the app.
class HisabUpgraderMessages extends UpgraderMessages {
  HisabUpgraderMessages({super.code, BuildContext? context}) : _context = context;

  final BuildContext? _context;

  static const _keys = (
    body: 'update_body',
    title: 'update_dialog_title',
    buttonTitleUpdate: 'update_now',
    buttonTitleLater: 'update_later',
    buttonTitleIgnore: 'update_ignore',
    prompt: 'update_prompt',
    releaseNotes: 'update_release_notes',
  );

  @override
  String? message(UpgraderMessage messageKey) {
    final ctx = _context;
    if (ctx != null && ctx.mounted) {
      final key = switch (messageKey) {
        UpgraderMessage.body => _keys.body,
        UpgraderMessage.title => _keys.title,
        UpgraderMessage.buttonTitleUpdate => _keys.buttonTitleUpdate,
        UpgraderMessage.buttonTitleLater => _keys.buttonTitleLater,
        UpgraderMessage.buttonTitleIgnore => _keys.buttonTitleIgnore,
        UpgraderMessage.prompt => _keys.prompt,
        UpgraderMessage.releaseNotes => _keys.releaseNotes,
      };
      try {
        return ctx.tr(key);
      } catch (_) {
        // Context may not have EasyLocalization (e.g. after async or in overlay).
        return super.message(messageKey);
      }
    }
    return super.message(messageKey);
  }
}
