import 'receipt_line_item.dart';
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
/// [lineItems]: optional bill/receipt breakdown (description + amount per line).
class Expense {
  final String id;
  final String groupId;
  final String payerParticipantId;
  final int amountCents;
  final String currencyCode;
  final String title;

  /// Optional longer description (e.g. full OCR text from receipt).
  final String? description;
  final DateTime date;
  final SplitType splitType;
  final Map<String, int> splitShares;
  final DateTime createdAt;
  final DateTime updatedAt;
  final TransactionType transactionType;
  final String? toParticipantId;

  /// Optional category/tag (preset key or custom label). Used for display and filtering.
  final String? tag;

  /// Optional detailed breakdown of the cost (bill/receipt line items).
  final List<ReceiptLineItem>? lineItems;

  /// Optional path to attached receipt image (local file path).
  final String? receiptImagePath;

  const Expense({
    required this.id,
    required this.groupId,
    required this.payerParticipantId,
    required this.amountCents,
    required this.currencyCode,
    required this.title,
    this.description,
    required this.date,
    required this.splitType,
    required this.splitShares,
    required this.createdAt,
    required this.updatedAt,
    this.transactionType = TransactionType.expense,
    this.toParticipantId,
    this.tag,
    this.lineItems,
    this.receiptImagePath,
  });

  Expense copyWith({
    String? id,
    String? groupId,
    String? payerParticipantId,
    int? amountCents,
    String? currencyCode,
    String? title,
    String? description,
    DateTime? date,
    SplitType? splitType,
    Map<String, int>? splitShares,
    DateTime? createdAt,
    DateTime? updatedAt,
    TransactionType? transactionType,
    String? toParticipantId,
    String? tag,
    List<ReceiptLineItem>? lineItems,
    String? receiptImagePath,
  }) {
    return Expense(
      id: id ?? this.id,
      groupId: groupId ?? this.groupId,
      payerParticipantId: payerParticipantId ?? this.payerParticipantId,
      amountCents: amountCents ?? this.amountCents,
      currencyCode: currencyCode ?? this.currencyCode,
      title: title ?? this.title,
      description: description ?? this.description,
      date: date ?? this.date,
      splitType: splitType ?? this.splitType,
      splitShares: splitShares ?? this.splitShares,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      transactionType: transactionType ?? this.transactionType,
      toParticipantId: toParticipantId ?? this.toParticipantId,
      tag: tag ?? this.tag,
      lineItems: lineItems ?? this.lineItems,
      receiptImagePath: receiptImagePath ?? this.receiptImagePath,
    );
  }
}
