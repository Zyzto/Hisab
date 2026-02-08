import 'split_type.dart';
import 'transaction_type.dart';

/// Domain entity: an expense/income/transfer in a group.
/// [transactionType]: expense (spend), income (received), transfer (from payer to toParticipantId).
/// [amountCents] is in smallest currency unit (e.g. cents) to avoid float errors.
/// [splitShares] maps participantId -> share:
/// - For [SplitType.equal]: not used; split is computed as amountCents / participantCount.
/// - For [SplitType.parts]: share = totalCents * (part / sumOfParts); parts from splitShares or ratio.
/// - For [SplitType.amounts]: share = amount in cents per participant (must sum to amountCents).
/// [toParticipantId]: for transfer, the participant who receives the money.
class Expense {
  final String id;
  final String groupId;
  final String payerParticipantId;
  final int amountCents;
  final String currencyCode;
  final String title;
  final DateTime date;
  final SplitType splitType;
  final Map<String, int> splitShares;
  final DateTime createdAt;
  final DateTime updatedAt;
  final TransactionType transactionType;
  final String? toParticipantId;

  const Expense({
    required this.id,
    required this.groupId,
    required this.payerParticipantId,
    required this.amountCents,
    required this.currencyCode,
    required this.title,
    required this.date,
    required this.splitType,
    required this.splitShares,
    required this.createdAt,
    required this.updatedAt,
    this.transactionType = TransactionType.expense,
    this.toParticipantId,
  });

  Expense copyWith({
    String? id,
    String? groupId,
    String? payerParticipantId,
    int? amountCents,
    String? currencyCode,
    String? title,
    DateTime? date,
    SplitType? splitType,
    Map<String, int>? splitShares,
    DateTime? createdAt,
    DateTime? updatedAt,
    TransactionType? transactionType,
    String? toParticipantId,
  }) {
    return Expense(
      id: id ?? this.id,
      groupId: groupId ?? this.groupId,
      payerParticipantId: payerParticipantId ?? this.payerParticipantId,
      amountCents: amountCents ?? this.amountCents,
      currencyCode: currencyCode ?? this.currencyCode,
      title: title ?? this.title,
      date: date ?? this.date,
      splitType: splitType ?? this.splitType,
      splitShares: splitShares ?? this.splitShares,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      transactionType: transactionType ?? this.transactionType,
      toParticipantId: toParticipantId ?? this.toParticipantId,
    );
  }
}
