import 'package:flutter_test/flutter_test.dart';
import 'package:hisab/core/auth/sign_in/auth_error_messages.dart';
import 'package:hisab_backend/hisab_backend.dart';

void main() {
  group('isEmailNotConfirmedError', () {
    test('matches the backend code', () {
      expect(
        isEmailNotConfirmedError(
          const CloudException('nope', code: 'email_not_confirmed'),
        ),
        isTrue,
      );
    });

    test('matches the message in either casing', () {
      expect(
        isEmailNotConfirmedError(const CloudException('Email not confirmed')),
        isTrue,
      );
      expect(
        isEmailNotConfirmedError(
          Exception('AuthApiException: email_not_confirmed'),
        ),
        isTrue,
      );
    });

    test('does not match unrelated failures', () {
      expect(
        isEmailNotConfirmedError(const CloudException('Invalid credentials')),
        isFalse,
      );
    });
  });

  group('isRateLimitError', () {
    test('matches the throttle code and the message', () {
      expect(
        isRateLimitError(
          const CloudException('too many', code: 'over_email_send_rate_limit'),
        ),
        isTrue,
      );
      expect(
        isRateLimitError(const CloudException('Email rate limit exceeded')),
        isTrue,
      );
      expect(isRateLimitError(Exception('rate_limit')), isTrue);
    });

    test('does not match unrelated failures', () {
      expect(isRateLimitError(const CloudException('boom')), isFalse);
    });
  });

  group('authErrorKey', () {
    test('unconfirmed email wins over everything else', () {
      expect(
        authErrorKey(
          const CloudException(
            'Email not confirmed',
            code: 'email_not_confirmed',
          ),
        ),
        AuthErrorKeys.emailNotConfirmed,
      );
    });

    test('rate limit is reported as such', () {
      expect(
        authErrorKey(
          const CloudException('slow down', code: 'over_email_send_rate_limit'),
        ),
        AuthErrorKeys.rateLimit,
      );
    });

    test('bad credentials map for both error shapes', () {
      expect(
        authErrorKey(const CloudException('Invalid login credentials')),
        AuthErrorKeys.invalidCredentials,
      );
      expect(
        authErrorKey(Exception('Invalid login credentials')),
        AuthErrorKeys.invalidCredentials,
      );
    });

    test('duplicate sign-up maps for both error shapes', () {
      expect(
        authErrorKey(const CloudException('User already registered')),
        AuthErrorKeys.alreadyRegistered,
      );
      expect(
        authErrorKey(Exception('User already registered')),
        AuthErrorKeys.alreadyRegistered,
      );
    });

    test('server-side weak password maps to the length message', () {
      expect(
        authErrorKey(
          const CloudException('Password should be at least 6 characters'),
        ),
        AuthErrorKeys.passwordTooShort,
      );
      expect(
        authErrorKey(Exception('weak_password')),
        AuthErrorKeys.passwordTooShort,
      );
    });

    test('anything unrecognised falls back to the generic message', () {
      expect(
        authErrorKey(const CloudException('kaboom')),
        AuthErrorKeys.generic,
      );
      expect(authErrorKey(Exception('kaboom')), AuthErrorKeys.generic);
      expect(authErrorKey('kaboom'), AuthErrorKeys.generic);
    });
  });
}
