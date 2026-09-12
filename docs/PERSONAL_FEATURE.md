# Personal groups

A personal group is a local group with is_personal set to true, one
participant, and an optional budget. It uses the same local group, expense,
and backup repositories as every other group.

## Behavior

- The home screen can create a personal group or a regular group.
- Personal groups show the budget and expense list without split/settle tabs.
- The expense form uses the single participant and local records.
- A personal group can become a regular local group without deleting its
  participant, expenses, or budget.

## Data

groups.is_personal and groups.budget_amount_cents are local SQLite fields.
Backup export/import preserves both fields. Missing fields in old backups use
regular-group and no-budget defaults.

## Safety

Conversion changes the group mode only. It does not delete records. Database
upgrades and backup restore must retain these fields.
