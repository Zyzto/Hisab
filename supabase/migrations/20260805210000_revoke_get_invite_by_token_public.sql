-- Harden get_invite_by_token: revoke default PUBLIC execute; allow anon + authenticated
-- (invite links are opened before/after sign-in). Matches preview RPC grant pattern.
REVOKE ALL ON FUNCTION public.get_invite_by_token(TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_invite_by_token(TEXT) TO anon, authenticated;
