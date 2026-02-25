import 'package:flutter_test/flutter_test.dart';
import 'package:hisab/core/navigation/invite_link_handler.dart';

void main() {
  group('extractInviteTokenFromUri', () {
    test('returns null for null uri', () {
      expect(extractInviteTokenFromUri(null), isNull);
    });

    test('returns token for deep link io.supabase.hisab://invite?token=abc', () {
      final uri = Uri.parse('io.supabase.hisab://invite?token=abc');
      expect(extractInviteTokenFromUri(uri), 'abc');
    });

    test('returns token for web-style path containing invite', () {
      final uri = Uri.parse('https://hisab.example.com/invite?token=xyz');
      expect(extractInviteTokenFromUri(uri), 'xyz');
    });

    test('returns null when token is missing', () {
      final uri = Uri.parse('io.supabase.hisab://invite');
      expect(extractInviteTokenFromUri(uri), isNull);
    });

    test('returns null when token is empty', () {
      final uri = Uri.parse('io.supabase.hisab://invite?token=');
      expect(extractInviteTokenFromUri(uri), isNull);
    });

    test('returns null when path does not contain invite', () {
      final uri = Uri.parse('https://example.com/other?token=foo');
      expect(extractInviteTokenFromUri(uri), isNull);
    });

    test('returns token when path is /invite with trailing slash', () {
      final uri = Uri.parse('https://example.com/invite/?token=bar');
      expect(extractInviteTokenFromUri(uri), 'bar');
    });
  });
}
