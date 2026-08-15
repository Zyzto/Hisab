import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:hisab/core/database/sync_errors.dart';
import 'package:hisab_backend/hisab_backend.dart';

void main() {
  group('sync error classification', () {
    test('auth CloudException is an auth error', () {
      expect(
        isSyncAuthError(
          const CloudException(
            'x',
            kind: CloudErrorKind.auth,
            statusCode: 401,
          ),
        ),
        true,
      );
      expect(
        isSyncAuthError(
          const CloudException(
            'x',
            kind: CloudErrorKind.auth,
            statusCode: 403,
          ),
        ),
        true,
      );
      expect(
        isSyncTransientError(
          const CloudException(
            'x',
            kind: CloudErrorKind.auth,
            statusCode: 401,
          ),
        ),
        false,
      );
    });

    test('kind alone classifies when no status code is carried', () {
      expect(
        isSyncAuthError(const CloudException('x', kind: CloudErrorKind.auth)),
        true,
      );
      expect(
        isSyncTransientError(
          const CloudException('x', kind: CloudErrorKind.network),
        ),
        true,
      );
    });

    test('TimeoutException is transient', () {
      expect(isSyncTransientError(TimeoutException('x')), true);
      expect(isSyncAuthError(TimeoutException('x')), false);
    });

    test('syncErrorStatusCode extracts from CloudException', () {
      expect(
        syncErrorStatusCode(
          const CloudException(
            'x',
            kind: CloudErrorKind.auth,
            statusCode: 401,
          ),
        ),
        401,
      );
      expect(
        syncErrorStatusCode(
          const CloudException(
            'x',
            kind: CloudErrorKind.auth,
            statusCode: 403,
          ),
        ),
        403,
      );
    });

    test('status 500 and 429 are transient', () {
      final e500 = _ExceptionWithStatus(500);
      final e429 = _ExceptionWithStatus(429);
      expect(isSyncTransientError(e500), true);
      expect(isSyncTransientError(e429), true);
      expect(isSyncAuthError(e500), false);
    });

    test('generic Exception is transient (non-auth)', () {
      expect(isSyncTransientError(Exception('network')), true);
      expect(isSyncAuthError(Exception('network')), false);
    });
  });
}

class _ExceptionWithStatus implements Exception {
  _ExceptionWithStatus(this.status);
  final int status;
}
