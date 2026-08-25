import '../../../domain/group.dart';

/// Picks the destination group for a scanner draft.
///
/// Order: explicit UI choice → sender override → draft → default → first
/// personal group.
String? resolveScannerDestination({
  String? explicitGroupId,
  required String? senderTargetGroupId,
  required String? draftTargetGroupId,
  required String? defaultGroupId,
  required List<Group> groups,
}) {
  final usable = groups.where((g) => !g.isArchived).toList();
  for (final id in [
    explicitGroupId,
    senderTargetGroupId,
    draftTargetGroupId,
    defaultGroupId,
  ]) {
    if (id == null || id.isEmpty) continue;
    final match = usable.where((g) => g.id == id).firstOrNull;
    if (match != null) return match.id;
  }
  return usable.where((g) => g.isPersonal).firstOrNull?.id;
}

/// Equal-split remainder loop matching the expense form.
Map<String, int> equalSplitShares(
  List<String> participantIds,
  int amountCents,
) {
  if (participantIds.isEmpty) return {};
  final n = participantIds.length;
  final each = amountCents ~/ n;
  final remainder = amountCents - each * n;
  final shares = <String, int>{};
  for (var i = 0; i < n; i++) {
    shares[participantIds[i]] = each + (i < remainder ? 1 : 0);
  }
  return shares;
}

/// Whether the current user can add an expense to [group].
bool canAddScannerExpense(Group group, {required bool isOwner}) {
  if (group.isArchived) return false;
  if (group.isPersonal) return true;
  return group.allowMemberAddExpense || isOwner;
}
