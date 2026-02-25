import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Public profile of a GitHub user (from GET /users/:username).
class GitHubUserProfile {
  const GitHubUserProfile({
    required this.avatarUrl,
    required this.login,
    this.name,
    this.bio,
    required this.htmlUrl,
    this.location,
    this.blog,
  });

  final String avatarUrl;
  final String login;
  final String? name;
  final String? bio;
  final String htmlUrl;
  final String? location;
  final String? blog;

  String get displayName => name?.trim().isNotEmpty == true ? name! : login;
}

const _timeout = Duration(seconds: 10);
const _baseUrl = 'https://api.github.com/users';

/// Fetches public profile for [username] from GitHub API.
/// Returns null on network error, non-200, or parse failure.
Future<GitHubUserProfile?> fetchGitHubUser(String username) async {
  if (username.isEmpty) return null;
  try {
    final uri = Uri.parse('$_baseUrl/$username');
    final response = await http.get(uri).timeout(_timeout);
    if (response.statusCode != 200) return null;
    final map = jsonDecode(response.body);
    if (map is! Map<String, dynamic>) return null;
    return GitHubUserProfile(
      avatarUrl: map['avatar_url'] as String? ?? '',
      login: map['login'] as String? ?? username,
      name: map['name'] as String?,
      bio: map['bio'] as String?,
      htmlUrl: map['html_url'] as String? ?? 'https://github.com/$username',
      location: map['location'] as String?,
      blog: map['blog'] as String?,
    );
  } catch (e, st) {
    if (kDebugMode) {
      // ignore: avoid_print
      print('GitHub user fetch error: $e\n$st');
    }
    return null;
  }
}
