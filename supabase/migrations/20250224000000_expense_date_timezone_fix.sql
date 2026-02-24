-- Fix expense dates that were stored as "local midnight" and appear one day early in UTC.
-- Old app behavior: date picker returned local midnight (e.g. 2025-02-24 00:00 in UTC+3),
-- which was stored as 2025-02-23 21:00 UTC, so the UTC calendar day was wrong.
-- Heuristic: for any expense where the stored time is not UTC midnight, assume it was
-- local midnight in a positive-offset timezone and set date to UTC midnight of the
-- "next" calendar day (add 12 hours, then truncate to day). Best-effort without
-- per-row timezone; negative-offset entries may be unchanged or already correct.

UPDATE public.expenses
SET date = date_trunc('day', date + interval '12 hours')
WHERE extract(hour from date) != 0
   OR extract(minute from date) != 0
   OR extract(second from date) != 0;
