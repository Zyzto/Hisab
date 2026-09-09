import 'dart:async';

import 'package:flutter_logging_service/flutter_logging_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/confirmation_durations.dart';
import '../../../core/repository/repository_providers.dart';

/// Owns expense deletions that are waiting for their Undo window to expire.
///
/// The controller is app-scoped rather than page-scoped. A pending deletion
/// therefore survives a route change, while the repository mutation still
/// waits until the full delay has elapsed. Dismissing the toast is intentionally
/// not an undo action.
class PendingExpenseDeletionController extends Notifier<Set<String>> {
  final Map<String, _PendingExpenseDeletion> _pending = {};
  bool _disposed = false;

  @override
  Set<String> build() {
    ref.onDispose(_dispose);
    return const <String>{};
  }

  bool isPending(String expenseId) => state.contains(expenseId);

  /// Starts the delayed delete. The optional [delay] is only for focused tests;
  /// production callers use the shared destructive-confirmation duration.
  void schedule({
    required String expenseId,
    required String groupId,
    Duration delay = const Duration(seconds: destructiveConfirmationSeconds),
    void Function(Object error, StackTrace stackTrace)? onError,
  }) {
    if (_disposed) return;

    final previous = _pending.remove(expenseId);
    previous?.timer.cancel();

    final operation = _PendingExpenseDeletion(
      expenseId: expenseId,
      groupId: groupId,
      onError: onError,
    );
    _pending[expenseId] = operation;
    _publishPending(expenseId, true);
    operation.timer = Timer(delay, () => _commit(operation));
  }

  /// Cancels a pending delete. Returns false if it already committed or was
  /// already cancelled, which prevents a late toast callback from racing the
  /// repository mutation.
  bool undo(String expenseId) {
    final operation = _pending[expenseId];
    if (operation == null || operation.committing) return false;
    operation.timer.cancel();
    _pending.remove(expenseId);
    _publishPending(expenseId, false);
    return true;
  }

  Future<void> _commit(_PendingExpenseDeletion operation) async {
    if (_disposed || !identical(_pending[operation.expenseId], operation)) {
      return;
    }
    operation.committing = true;

    try {
      // Read the current repository at commit time. If the user changed
      // account mode or connectivity during the Undo window, the mutation
      // follows the mode that is active when it becomes irreversible.
      await ref.read(expenseRepositoryProvider).delete(operation.expenseId);
      if (!identical(_pending[operation.expenseId], operation)) return;
      _pending.remove(operation.expenseId);
      _publishPending(operation.expenseId, false);
    } catch (error, stackTrace) {
      Log.warning(
        'Delayed expense delete failed: expense=${operation.expenseId} '
        'group=${operation.groupId}',
        error: error,
        stackTrace: stackTrace,
      );
      if (identical(_pending[operation.expenseId], operation)) {
        _pending.remove(operation.expenseId);
        _publishPending(operation.expenseId, false);
      }
      operation.onError?.call(error, stackTrace);
    }
  }

  void _publishPending(String expenseId, bool pending) {
    final next = state.toSet();
    if (pending) {
      next.add(expenseId);
    } else {
      next.remove(expenseId);
    }
    state = next;
  }

  void _dispose() {
    _disposed = true;
    for (final operation in _pending.values) {
      operation.timer.cancel();
    }
    _pending.clear();
  }
}

class _PendingExpenseDeletion {
  _PendingExpenseDeletion({
    required this.expenseId,
    required this.groupId,
    this.onError,
  });

  final String expenseId;
  final String groupId;
  final void Function(Object error, StackTrace stackTrace)? onError;
  late Timer timer;
  bool committing = false;
}

final pendingExpenseDeletionProvider =
    NotifierProvider<PendingExpenseDeletionController, Set<String>>(
      PendingExpenseDeletionController.new,
    );
