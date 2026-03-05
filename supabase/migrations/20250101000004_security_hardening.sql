-- Migration 4: Security hardening – fix search_path on all functions
-- Based on docs/SUPABASE_SETUP.md Migration 4

ALTER FUNCTION public.handle_updated_at() SET search_path = '';
ALTER FUNCTION public.get_user_role(UUID) SET search_path = '';
ALTER FUNCTION public.is_group_member(UUID) SET search_path = '';
ALTER FUNCTION public.get_invite_by_token(TEXT) SET search_path = '';
ALTER FUNCTION public.accept_invite(TEXT, UUID, TEXT) SET search_path = '';
ALTER FUNCTION public.transfer_ownership(UUID, UUID) SET search_path = '';
ALTER FUNCTION public.leave_group(UUID) SET search_path = '';
ALTER FUNCTION public.kick_member(UUID, UUID) SET search_path = '';
ALTER FUNCTION public.update_member_role(UUID, UUID, TEXT) SET search_path = '';
ALTER FUNCTION public.assign_participant(UUID, UUID, UUID) SET search_path = '';
ALTER FUNCTION public.create_invite(UUID, TEXT, TEXT) SET search_path = '';
