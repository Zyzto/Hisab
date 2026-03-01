import 'package:powersync/powersync.dart';

/// Local SQLite schema managed by PowerSync (used as a local DB engine).
/// Mirrors the Supabase Postgres tables for caching, plus a pending_writes
/// queue for offline operations.
const schema = Schema([
  Table('groups', [
    Column.text('name'),
    Column.text('currency_code'),
    Column.text('owner_id'),
    Column.text('settlement_method'),
    Column.text('treasurer_participant_id'),
    Column.text('settlement_freeze_at'),
    Column.text('settlement_snapshot_json'),
    Column.integer('allow_member_add_expense'),
    Column.integer('allow_member_add_participant'),
    Column.integer('allow_member_change_settings'),
    Column.integer('require_participant_assignment'),
    Column.integer('allow_expense_as_other_participant'),
    Column.integer('allow_member_settle_for_others'),
    Column.text('icon'),
    Column.integer('color'),
    Column.text('archived_at'),
    Column.integer('is_personal'),
    Column.integer('budget_amount_cents'),
    Column.text('created_at'),
    Column.text('updated_at'),
  ]),
  Table('group_members', [
    Column.text('group_id'),
    Column.text('user_id'),
    Column.text('role'),
    Column.text('participant_id'),
    Column.text('joined_at'),
  ]),
  Table('participants', [
    Column.text('group_id'),
    Column.text('name'),
    Column.integer('sort_order'),
    Column.text('user_id'),
    Column.text('avatar_id'),
    Column.text('left_at'),
    Column.text('created_at'),
    Column.text('updated_at'),
  ]),
  Table('expenses', [
    Column.text('group_id'),
    Column.text('payer_participant_id'),
    Column.integer('amount_cents'),
    Column.text('currency_code'),
    Column.real('exchange_rate'),
    Column.integer('base_amount_cents'),
    Column.text('title'),
    Column.text('description'),
    Column.text('date'),
    Column.text('split_type'),
    Column.text('split_shares_json'),
    Column.text('type'),
    Column.text('to_participant_id'),
    Column.text('tag'),
    Column.text('line_items_json'),
    Column.text('receipt_image_path'),
    Column.text('receipt_image_paths'),
    Column.text('created_at'),
    Column.text('updated_at'),
  ]),
  Table('expense_tags', [
    Column.text('group_id'),
    Column.text('label'),
    Column.text('icon_name'),
    Column.text('created_at'),
    Column.text('updated_at'),
  ]),
  Table('group_invites', [
    Column.text('group_id'),
    Column.text('token'),
    Column.text('invitee_email'),
    Column.text('role'),
    Column.text('created_at'),
    Column.text('expires_at'),
    Column.text('created_by'),
    Column.text('label'),
    Column.integer('max_uses'),
    Column.integer('use_count'),
    Column.integer('is_active'),
  ]),
  Table('invite_usages', [
    Column.text('invite_id'),
    Column.text('user_id'),
    Column.text('accepted_at'),
  ]),

  // ── Local-only (not synced) ──────────────────────────────────────────
  // Per-user "hide from my list" for non-owners; never written by sync.
  Table('local_archived_groups', [
    Column.text('group_id'),
    Column.text('archived_at'),
  ]),

  // ── Offline queue ────────────────────────────────────────────────────
  // Stores writes made while in Online mode but temporarily offline.
  // Processed by DataSyncService when connectivity returns.
  Table('pending_writes', [
    Column.text('table_name'),
    Column.text('operation'), // insert, update, delete
    Column.text('row_id'),
    Column.text('data_json'),
    Column.text('created_at'),
  ]),
]);
