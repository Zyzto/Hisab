import 'package:flutter_test/flutter_test.dart';
import 'package:hisab/core/services/supabase_project_health_client.dart';

void main() {
  group('classifySupabaseProjectHealthResponse', () {
    test('treats 2xx as active', () {
      final result = classifySupabaseProjectHealthResponse(statusCode: 200);
      expect(result, isA<SupabaseProjectHealthActive>());
    });

    test('treats HTTP 540 as paused', () {
      final result = classifySupabaseProjectHealthResponse(
        statusCode: supabaseProjectPausedStatusCode,
      );
      expect(result, isA<SupabaseProjectHealthPaused>());
    });

    test('detects paused from response body', () {
      final result = classifySupabaseProjectHealthResponse(
        statusCode: 503,
        body: 'Project is paused',
      );
      expect(result, isA<SupabaseProjectHealthPaused>());
    });

    test('treats other errors as unreachable', () {
      final result = classifySupabaseProjectHealthResponse(statusCode: 502);
      expect(result, isA<SupabaseProjectHealthUnreachable>());
    });
  });
}
