-- Seed data for integration testing.
-- Creates two test users with known credentials for the invite flow.
--
-- User A: test-a@hisab.test / TestPass123!
-- User B: test-b@hisab.test / TestPass123!

INSERT INTO auth.users (
  instance_id,
  id,
  aud,
  role,
  email,
  encrypted_password,
  email_confirmed_at,
  raw_app_meta_data,
  raw_user_meta_data,
  created_at,
  updated_at,
  confirmation_token,
  email_change,
  email_change_token_new,
  recovery_token
) VALUES (
  '00000000-0000-0000-0000-000000000000',
  'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
  'authenticated',
  'authenticated',
  'test-a@hisab.test',
  crypt('TestPass123!', gen_salt('bf')),
  now(),
  '{"provider": "email", "providers": ["email"]}',
  '{"full_name": "Test User A"}',
  now(),
  now(),
  '',
  '',
  '',
  ''
), (
  '00000000-0000-0000-0000-000000000000',
  'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb',
  'authenticated',
  'authenticated',
  'test-b@hisab.test',
  crypt('TestPass123!', gen_salt('bf')),
  now(),
  '{"provider": "email", "providers": ["email"]}',
  '{"full_name": "Test User B"}',
  now(),
  now(),
  '',
  '',
  '',
  ''
);

INSERT INTO auth.identities (
  id,
  user_id,
  provider_id,
  identity_data,
  provider,
  last_sign_in_at,
  created_at,
  updated_at
) VALUES (
  'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
  'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
  'test-a@hisab.test',
  '{"sub": "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa", "email": "test-a@hisab.test", "email_verified": true, "phone_verified": false}',
  'email',
  now(),
  now(),
  now()
), (
  'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb',
  'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb',
  'test-b@hisab.test',
  '{"sub": "bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb", "email": "test-b@hisab.test", "email_verified": true, "phone_verified": false}',
  'email',
  now(),
  now(),
  now()
);
