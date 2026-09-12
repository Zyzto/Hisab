import 'dart:ui' as ui;

import 'package:collection/collection.dart';
import 'package:flutter/painting.dart';

/// Special avatar id that means "show my initials instead of an emoji".
const String initialsAvatarId = 'initials';

/// Bundled avatar options for local participant profiles.
const List<MapEntry<String, String>> predefinedAvatars = [
  MapEntry('initials', 'Aa'),
  MapEntry('smile', '😊'),
  MapEntry('cool', '😎'),
  MapEntry('wink', '😉'),
  MapEntry('laugh', '😂'),
  MapEntry('think', '🤔'),
  MapEntry('wave', '👋'),
  MapEntry('party', '🥳'),
  MapEntry('cat', '🐱'),
  MapEntry('dog', '🐶'),
  MapEntry('fox', '🦊'),
  MapEntry('panda', '🐼'),
  MapEntry('unicorn', '🦄'),
  MapEntry('butterfly', '🦋'),
  MapEntry('sun', '☀️'),
  MapEntry('moon', '🌙'),
  MapEntry('star', '⭐'),
  MapEntry('rainbow', '🌈'),
  MapEntry('leaf', '🍀'),
  MapEntry('flower', '🌸'),
  MapEntry('globe', '🌍'),
  MapEntry('rocket', '🚀'),
  MapEntry('fire', '🔥'),
  MapEntry('heart', '❤️'),
  MapEntry('diamond', '💎'),
  MapEntry('bolt', '⚡'),
  MapEntry('book', '📚'),
  MapEntry('music', '🎵'),
  MapEntry('coffee', '☕'),
  MapEntry('pizza', '🍕'),
  MapEntry('avocado', '🥑'),
  MapEntry('soccer', '⚽'),
  MapEntry('basketball', '🏀'),
  MapEntry('game', '🎮'),
  MapEntry('robot', '🤖'),
  MapEntry('laptop', '💻'),
  MapEntry('alien', '👽'),
];

const String defaultAvatarId = initialsAvatarId;

String? avatarEmoji(String? avatarId) {
  if (avatarId == null || avatarId.isEmpty || avatarId == initialsAvatarId) {
    return null;
  }
  return predefinedAvatars
      .where((entry) => entry.key == avatarId)
      .map((entry) => entry.value)
      .firstOrNull;
}

Future<void>? _preloadAvatarEmojisFuture;

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
