import 'dart:ui' as ui;

import 'package:collection/collection.dart';
import 'package:flutter/painting.dart';

/// Special avatar id that means "show my initials instead of an emoji".
const String initialsAvatarId = 'initials';

/// Pre-defined avatar options for sign-up and profile.
/// Each entry is [id, emoji]. Emoji are used so no assets are required.
/// The first entry is the special "initials" option (rendered by the UI as
/// the user's initials rather than an emoji).
const List<MapEntry<String, String>> predefinedAvatars = [
  // Special: rendered as initials by the UI
  MapEntry('initials', 'Aa'),
  // People & gestures
  MapEntry('smile', '😊'),
  MapEntry('cool', '😎'),
  MapEntry('wink', '😉'),
  MapEntry('laugh', '😂'),
  MapEntry('think', '🤔'),
  MapEntry('wave', '👋'),
  MapEntry('party', '🥳'),
  // Animals
  MapEntry('cat', '🐱'),
  MapEntry('dog', '🐶'),
  MapEntry('fox', '🦊'),
  MapEntry('panda', '🐼'),
  MapEntry('unicorn', '🦄'),
  MapEntry('butterfly', '🦋'),
  // Nature & weather
  MapEntry('sun', '☀️'),
  MapEntry('moon', '🌙'),
  MapEntry('star', '⭐'),
  MapEntry('rainbow', '🌈'),
  MapEntry('leaf', '🍀'),
  MapEntry('flower', '🌸'),
  MapEntry('globe', '🌍'),
  // Objects & symbols
  MapEntry('rocket', '🚀'),
  MapEntry('fire', '🔥'),
  MapEntry('heart', '❤️'),
  MapEntry('diamond', '💎'),
  MapEntry('bolt', '⚡'),
  MapEntry('book', '📚'),
  MapEntry('music', '🎵'),
  // Food & drink
  MapEntry('coffee', '☕'),
  MapEntry('pizza', '🍕'),
  MapEntry('avocado', '🥑'),
  // Sports & games
  MapEntry('soccer', '⚽'),
  MapEntry('basketball', '🏀'),
  MapEntry('game', '🎮'),
  // Tech
  MapEntry('robot', '🤖'),
  MapEntry('laptop', '💻'),
  MapEntry('alien', '👽'),
];

/// Default avatar id when none is set.
const String defaultAvatarId = 'initials';

/// Returns the emoji for a given avatar id, or `null` if the avatar should
/// render as initials (i.e. [initialsAvatarId] or unknown id).
String? avatarEmoji(String? avatarId) {
  if (avatarId == null || avatarId.isEmpty || avatarId == initialsAvatarId) {
    return null;
  }
  final found = predefinedAvatars
      .where((e) => e.key == avatarId)
      .map((e) => e.value)
      .firstOrNull;
  return found;
}

Future<void>? _preloadAvatarEmojisFuture;

/// Warms emoji glyph caches for [predefinedAvatars] so the avatar picker does
/// not flash empty/tofu boxes on first open (especially on web).
///
/// Safe to call multiple times; only the first call does work.
Future<void> preloadPredefinedAvatarEmojis() {
  return _preloadAvatarEmojisFuture ??= _preloadPredefinedAvatarEmojis();
}

Future<void> _preloadPredefinedAvatarEmojis() async {
  const style = TextStyle(fontSize: 22);
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  var x = 0.0;
  for (final entry in predefinedAvatars) {
    if (entry.key == initialsAvatarId) continue;
    final painter = TextPainter(
      text: TextSpan(text: entry.value, style: style),
      textDirection: TextDirection.ltr,
      textScaler: TextScaler.noScaling,
    )..layout();
    painter.paint(canvas, Offset(x, 0));
    x += painter.width + 2;
  }
  final picture = recorder.endRecording();
  try {
    final image = await picture.toImage(x.ceil().clamp(1, 4096), 32);
    image.dispose();
  } finally {
    picture.dispose();
  }
}
