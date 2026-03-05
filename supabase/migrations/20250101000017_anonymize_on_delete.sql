-- Migration 18: Anonymize participant name only on account delete
-- Based on docs/SUPABASE_SETUP.md Migration 18 (Migration 17 is superseded)
-- Trigger on auth.users BEFORE DELETE: anonymize all participants for that user

CREATE OR REPLACE FUNCTION public.anonymize_participants_on_user_delete()
RETURNS TRIGGER AS $$
BEGIN
  UPDATE public.participants
  SET
    name = 'Former member ' || substr(OLD.id::text, 1, 6),
    avatar_id = NULL,
    updated_at = now()
  WHERE user_id = OLD.id;
  RETURN OLD;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = '';

CREATE TRIGGER trigger_anonymize_participants_on_user_delete
  BEFORE DELETE ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION public.anonymize_participants_on_user_delete();
