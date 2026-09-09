import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hisab/core/repository/expense_repository.dart';
import 'package:hisab/core/repository/repository_providers.dart';
import 'package:hisab/domain/domain.dart';
import 'package:hisab/features/expenses/providers/pending_expense_deletion_provider.dart';

void main() {
  test('undo cancels the delete before the delay expires', () async {
    final repository = _FakeExpenseRepository();
    final container = ProviderContainer(
      overrides: [expenseRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);

    final controller = container.read(pendingExpenseDeletionProvider.notifier);
    controller.schedule(
      expenseId: 'expense-1',
      groupId: 'group-1',
      delay: const Duration(milliseconds: 30),
    );
    expect(container.read(pendingExpenseDeletionProvider), {'expense-1'});

    expect(controller.undo('expense-1'), isTrue);
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(repository.deletedIds, isEmpty);
    expect(container.read(pendingExpenseDeletionProvider), isEmpty);
  });

  test('dismissal or navigation does not cancel the eventual delete', () async {
    final repository = _FakeExpenseRepository();
    final container = ProviderContainer(
      overrides: [expenseRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);

    final controller = container.read(pendingExpenseDeletionProvider.notifier);
    controller.schedule(
      expenseId: 'expense-2',
      groupId: 'group-1',
      delay: const Duration(milliseconds: 30),
    );
    // The toast can disappear and the originating route can be disposed; no
    // undo call means the controller must still commit the mutation.
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(repository.deletedIds, ['expense-2']);
    expect(container.read(pendingExpenseDeletionProvider), isEmpty);
  });
}

class _FakeExpenseRepository implements IExpenseRepository {
  final List<String> deletedIds = <String>[];

  @override
  Future<void> delete(String id) async => deletedIds.add(id);

  @override
  Future<String> create(Expense expense) async => expense.id;

  @override
  Future<List<Expense>> getAll() async => const [];

  @override
  Future<List<Expense>> getByGroupId(String groupId) async => const [];

  @override
  Future<Expense?> getById(String id) async => null;

  @override
  Future<void> update(Expense expense) async {}

  @override
  Stream<List<Expense>> watchAll() => const Stream.empty();

  @override
  Stream<List<Expense>> watchByGroupId(String groupId) => const Stream.empty();

  @override
  Stream<Expense?> watchById(String id) => const Stream.empty();
}
