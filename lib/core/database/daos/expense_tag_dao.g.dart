// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'expense_tag_dao.dart';

// ignore_for_file: type=lint
mixin _$ExpenseTagDaoMixin on DatabaseAccessor<AppDatabase> {
  $GroupsTable get groups => attachedDatabase.groups;
  $ExpenseTagsTable get expenseTags => attachedDatabase.expenseTags;
  ExpenseTagDaoManager get managers => ExpenseTagDaoManager(this);
}

class ExpenseTagDaoManager {
  final _$ExpenseTagDaoMixin _db;
  ExpenseTagDaoManager(this._db);
  $$GroupsTableTableManager get groups =>
      $$GroupsTableTableManager(_db.attachedDatabase, _db.groups);
  $$ExpenseTagsTableTableManager get expenseTags =>
      $$ExpenseTagsTableTableManager(_db.attachedDatabase, _db.expenseTags);
}
