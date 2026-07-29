-- Demo group for analytics / expense variety.
-- Safe to re-run: deletes prior demo group by fixed id first.
-- Users: test-a@hisab.test (owner) + test-b@hisab.test (member) + 8 guests.

BEGIN;

DELETE FROM public.groups
WHERE id = 'dddddddd-dddd-dddd-dddd-dddddddddddd';

INSERT INTO public.groups (
  id,
  name,
  currency_code,
  owner_id,
  icon,
  color,
  settlement_method,
  allow_member_add_expense,
  allow_member_add_participant,
  allow_member_change_settings,
  require_participant_assignment,
  is_personal
) VALUES (
  'dddddddd-dddd-dddd-dddd-dddddddddddd',
  'Analytics Demo Trip',
  'USD',
  'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
  'flight',
  -14326805, -- signed int32 for 0xFF2563EB
  'greedy',
  true,
  true,
  true,
  false,
  false
);

-- 10 participants: User A, User B, then 8 guests
WITH people(id, name, sort_order, user_id) AS (
  VALUES
    ('d0000000-0000-0000-0000-000000000001'::uuid, 'Test User A', 0, 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'::uuid),
    ('d0000000-0000-0000-0000-000000000002'::uuid, 'Test User B', 1, 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb'::uuid),
    ('d0000000-0000-0000-0000-000000000003'::uuid, 'Sara', 2, NULL::uuid),
    ('d0000000-0000-0000-0000-000000000004'::uuid, 'Omar', 3, NULL::uuid),
    ('d0000000-0000-0000-0000-000000000005'::uuid, 'Lina', 4, NULL::uuid),
    ('d0000000-0000-0000-0000-000000000006'::uuid, 'Hassan', 5, NULL::uuid),
    ('d0000000-0000-0000-0000-000000000007'::uuid, 'Maya', 6, NULL::uuid),
    ('d0000000-0000-0000-0000-000000000008'::uuid, 'Nour', 7, NULL::uuid),
    ('d0000000-0000-0000-0000-000000000009'::uuid, 'Karim', 8, NULL::uuid),
    ('d0000000-0000-0000-0000-00000000000a'::uuid, 'Rana', 9, NULL::uuid)
)
INSERT INTO public.participants (id, group_id, name, sort_order, user_id)
SELECT id, 'dddddddd-dddd-dddd-dddd-dddddddddddd', name, sort_order, user_id
FROM people;

INSERT INTO public.group_members (group_id, user_id, role, participant_id)
VALUES
  (
    'dddddddd-dddd-dddd-dddd-dddddddddddd',
    'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
    'owner',
    'd0000000-0000-0000-0000-000000000001'
  ),
  (
    'dddddddd-dddd-dddd-dddd-dddddddddddd',
    'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb',
    'member',
    'd0000000-0000-0000-0000-000000000002'
  );

INSERT INTO public.expense_tags (group_id, label, icon_name)
VALUES
  ('dddddddd-dddd-dddd-dddd-dddddddddddd', 'Souvenirs', 'shopping_bag'),
  ('dddddddd-dddd-dddd-dddd-dddddddddddd', 'Snacks', 'restaurant_menu');

-- 100 mixed transactions spanning ~16 months ending "today"
DO $$
DECLARE
  g uuid := 'dddddddd-dddd-dddd-dddd-dddddddddddd';
  pids uuid[] := ARRAY[
    'd0000000-0000-0000-0000-000000000001'::uuid,
    'd0000000-0000-0000-0000-000000000002'::uuid,
    'd0000000-0000-0000-0000-000000000003'::uuid,
    'd0000000-0000-0000-0000-000000000004'::uuid,
    'd0000000-0000-0000-0000-000000000005'::uuid,
    'd0000000-0000-0000-0000-000000000006'::uuid,
    'd0000000-0000-0000-0000-000000000007'::uuid,
    'd0000000-0000-0000-0000-000000000008'::uuid,
    'd0000000-0000-0000-0000-000000000009'::uuid,
    'd0000000-0000-0000-0000-00000000000a'::uuid
  ];
  tags text[] := ARRAY[
    'food', 'groceries', 'transport', 'shopping', 'entertainment',
    'bills', 'health', 'coffee', 'travel', 'subscriptions',
    'education', 'gifts', NULL, NULL
  ];
  expense_titles text[] := ARRAY[
    'Dinner', 'Lunch', 'Groceries', 'Taxi', 'Uber', 'Hotel night',
    'Museum tickets', 'Coffee run', 'Train tickets', 'Airbnb deposit',
    'Snacks', 'Concert', 'Pharmacy', 'SIM card', 'Laundry',
    'Boat tour', 'Parking', 'Souvenirs', 'Group brunch', 'Ice cream'
  ];
  income_titles text[] := ARRAY[
    'Trip reimbursement', 'Group fund top-up', 'Cashback',
    'Shared refund', 'Friend paid back'
  ];
  transfer_titles text[] := ARRAY[
    'Settle up', 'Cash handoff', 'Split correction', 'IOU payment'
  ];
  i int;
  tx_type text;
  payer uuid;
  payee uuid;
  amount int;
  day_offset int;
  evt_date timestamptz;
  split_kind text;
  shares jsonb;
  tag text;
  title text;
  subset uuid[];
  n int;
  part int;
  remaining int;
  j int;
  pid uuid;
  line_items text;
BEGIN
  FOR i IN 1..100 LOOP
    -- Timeline: denser near the end, overall ~480 days
    day_offset := CASE
      WHEN i <= 20 THEN 400 + ((i * 37) % 80)          -- older cluster
      WHEN i <= 55 THEN 180 + ((i * 53) % 170)         -- mid span
      ELSE (i * 7 + i * i) % 120                       -- recent
    END;
    evt_date := (CURRENT_DATE - day_offset)
      + make_interval(hours => (i * 3) % 20, mins => (i * 11) % 60);

    -- Mix: ~75 expense, ~12 income, ~13 transfer
    tx_type := CASE
      WHEN i % 8 = 0 THEN 'income'
      WHEN i % 7 = 0 THEN 'transfer'
      ELSE 'expense'
    END;

    payer := pids[1 + ((i * 3) % array_length(pids, 1))];
    tag := tags[1 + ((i * 5) % array_length(tags, 1))];

    IF tx_type = 'transfer' THEN
      LOOP
        payee := pids[1 + ((i * 5 + 2) % array_length(pids, 1))];
        EXIT WHEN payee <> payer;
        payee := pids[1 + ((i + 1) % array_length(pids, 1))];
        EXIT WHEN payee <> payer;
      END LOOP;
      amount := 1500 + ((i * 173) % 18000); -- $15–$195
      title := transfer_titles[1 + ((i - 1) % array_length(transfer_titles, 1))];
      shares := jsonb_build_object(payee::text, amount);
      INSERT INTO public.expenses (
        group_id, payer_participant_id, amount_cents, currency_code, title,
        description, date, split_type, split_shares_json, type, to_participant_id, tag
      ) VALUES (
        g, payer, amount, 'USD', title,
        'Demo transfer between members',
        evt_date, 'amounts', shares::text, 'transfer', payee, NULL
      );
      CONTINUE;
    END IF;

    IF tx_type = 'income' THEN
      amount := 5000 + ((i * 211) % 45000); -- $50–$500
      title := income_titles[1 + ((i - 1) % array_length(income_titles, 1))];
      -- Income often benefits everyone equally
      shares := '{}'::jsonb;
      FOREACH pid IN ARRAY pids LOOP
        shares := shares || jsonb_build_object(pid::text, (amount / 10));
      END LOOP;
      -- Fix remainder on payer
      shares := shares || jsonb_build_object(
        payer::text,
        (amount / 10) + (amount - (amount / 10) * 10)
      );
      INSERT INTO public.expenses (
        group_id, payer_participant_id, amount_cents, currency_code, title,
        description, date, split_type, split_shares_json, type, tag
      ) VALUES (
        g, payer, amount, 'USD', title,
        'Demo income / reimbursement',
        evt_date, 'equal', shares::text, 'income', COALESCE(tag, 'gifts')
      );
      CONTINUE;
    END IF;

    -- Regular expense
    amount := 800 + ((i * 997) % 42000); -- $8–$428
    title := expense_titles[1 + ((i - 1) % array_length(expense_titles, 1))];
    split_kind := CASE
      WHEN i % 5 = 0 THEN 'parts'
      WHEN i % 4 = 0 THEN 'amounts'
      ELSE 'equal'
    END;

    -- Subset of participants in the split (3–10 people)
    n := 3 + (i % 8);
    subset := ARRAY[]::uuid[];
    FOR j IN 0..(n - 1) LOOP
      pid := pids[1 + ((i + j * 3) % array_length(pids, 1))];
      IF NOT pid = ANY (subset) THEN
        subset := subset || pid;
      END IF;
    END LOOP;
    IF NOT payer = ANY (subset) THEN
      subset := subset || payer;
    END IF;

    shares := '{}'::jsonb;
    IF split_kind = 'equal' THEN
      part := amount / array_length(subset, 1);
      remaining := amount - part * array_length(subset, 1);
      FOR j IN 1..array_length(subset, 1) LOOP
        shares := shares || jsonb_build_object(
          subset[j]::text,
          part + CASE WHEN j = 1 THEN remaining ELSE 0 END
        );
      END LOOP;
    ELSIF split_kind = 'parts' THEN
      -- parts 1..n stored as integers; app interprets as parts
      FOR j IN 1..array_length(subset, 1) LOOP
        shares := shares || jsonb_build_object(subset[j]::text, 1 + ((i + j) % 3));
      END LOOP;
    ELSE
      -- amounts: exact cents summing to amount
      remaining := amount;
      FOR j IN 1..array_length(subset, 1) LOOP
        IF j = array_length(subset, 1) THEN
          part := remaining;
        ELSE
          part := GREATEST(100, remaining / (array_length(subset, 1) - j + 1 + ((i + j) % 3)));
          part := LEAST(part, remaining - 100 * (array_length(subset, 1) - j));
          remaining := remaining - part;
        END IF;
        shares := shares || jsonb_build_object(subset[j]::text, part);
      END LOOP;
    END IF;

    line_items := NULL;
    IF i % 9 = 0 THEN
      line_items := json_build_array(
        json_build_object('description', 'Item A', 'amountCents', amount / 2),
        json_build_object('description', 'Item B', 'amountCents', amount - amount / 2)
      )::text;
    END IF;

    INSERT INTO public.expenses (
      group_id, payer_participant_id, amount_cents, currency_code, title,
      description, date, split_type, split_shares_json, type, tag, line_items_json
    ) VALUES (
      g, payer, amount, 'USD', title || ' #' || i::text,
      CASE WHEN i % 6 = 0 THEN 'Demo expense with notes' ELSE NULL END,
      evt_date, split_kind, shares::text, 'expense', tag, line_items
    );
  END LOOP;
END $$;

COMMIT;

-- Sanity counts
SELECT
  (SELECT count(*) FROM public.participants WHERE group_id = 'dddddddd-dddd-dddd-dddd-dddddddddddd') AS participants,
  (SELECT count(*) FROM public.group_members WHERE group_id = 'dddddddd-dddd-dddd-dddd-dddddddddddd') AS members,
  (SELECT count(*) FROM public.expenses WHERE group_id = 'dddddddd-dddd-dddd-dddd-dddddddddddd') AS expenses,
  (SELECT count(*) FROM public.expenses WHERE group_id = 'dddddddd-dddd-dddd-dddd-dddddddddddd' AND type = 'expense') AS expense_n,
  (SELECT count(*) FROM public.expenses WHERE group_id = 'dddddddd-dddd-dddd-dddd-dddddddddddd' AND type = 'income') AS income_n,
  (SELECT count(*) FROM public.expenses WHERE group_id = 'dddddddd-dddd-dddd-dddd-dddddddddddd' AND type = 'transfer') AS transfer_n,
  (SELECT min(date)::date FROM public.expenses WHERE group_id = 'dddddddd-dddd-dddd-dddd-dddddddddddd') AS first_day,
  (SELECT max(date)::date FROM public.expenses WHERE group_id = 'dddddddd-dddd-dddd-dddd-dddddddddddd') AS last_day;
