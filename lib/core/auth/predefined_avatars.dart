import 'package:collection/collection.dart';

/// Pre-defined avatar options for sign-up and profile.
/// Each entry is [id, emoji]. Emoji are used so no assets are required.
const List<MapEntry<String, String>> predefinedAvatars = [
  MapEntry('person', '👤'),
  MapEntry('smile', '😊'),
  MapEntry('star', '⭐'),
  MapEntry('heart', '❤️'),
  MapEntry('sun', '☀️'),
  MapEntry('moon', '🌙'),
  MapEntry('rocket', '🚀'),
  MapEntry('leaf', '🍀'),
  MapEntry('fire', '🔥'),
  MapEntry('wave', '👋'),
  MapEntry('globe', '🌍'),
  MapEntry('book', '📚'),
];

/// Default avatar id when none is set.
const String defaultAvatarId = 'person';

String avatarEmoji(String? avatarId) {
  if (avatarId == null || avatarId.isEmpty) return '👤';
  final found = predefinedAvatars
      .where((e) => e.key == avatarId)
      .map((e) => e.value)
      .firstOrNull;
  return found ?? '👤';
}
