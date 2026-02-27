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

  /// Exchange rate from expense currency to group's base currency.
  /// e.g. if expense is 5000 JPY and group is SAR with rate 39.5 JPY per SAR,
  /// [exchangeRate] = 39.5 (meaning 1 SAR = 39.5 JPY).
  /// Defaults to 1.0 when expense currency matches group currency.
  final double exchangeRate;

  /// The amount in the group's base currency (smallest unit, e.g. cents).
  /// Pre-computed on save: amountCents / exchangeRate (adjusted for decimal differences).
  /// `null` when expense currency matches group currency (same as amountCents).
  final int? baseAmountCents;

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

  /// Optional path or URL to the first receipt image (backward compatibility).
  final String? receiptImagePath;

  /// Optional ordered list of receipt image URLs (or paths). When non-null, [receiptImagePath] is the first element.
  final List<String>? receiptImagePaths;

  const Expense({
    required this.id,
    required this.groupId,
    required this.payerParticipantId,
    required this.amountCents,
    required this.currencyCode,
    this.exchangeRate = 1.0,
    this.baseAmountCents,
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
    this.receiptImagePaths,
  });

  /// Effective list of receipt image URLs: [receiptImagePaths] if non-empty, else single [receiptImagePath] if set.
  List<String> get effectiveReceiptImageUrls =>
      (receiptImagePaths != null && receiptImagePaths!.isNotEmpty)
          ? receiptImagePaths!
          : (receiptImagePath != null && receiptImagePath!.isNotEmpty)
              ? [receiptImagePath!]
              : [];

  /// Returns the effective amount in the group's base currency (in cents).
  /// Uses [baseAmountCents] if available, otherwise falls back to [amountCents].
  int get effectiveBaseAmountCents => baseAmountCents ?? amountCents;

  Expense copyWith({
    String? id,
    String? groupId,
    String? payerParticipantId,
    int? amountCents,
    String? currencyCode,
    double? exchangeRate,
    int? baseAmountCents,
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
    List<String>? receiptImagePaths,
  }) {
    return Expense(
      id: id ?? this.id,
      groupId: groupId ?? this.groupId,
      payerParticipantId: payerParticipantId ?? this.payerParticipantId,
      amountCents: amountCents ?? this.amountCents,
      currencyCode: currencyCode ?? this.currencyCode,
      exchangeRate: exchangeRate ?? this.exchangeRate,
      baseAmountCents: baseAmountCents ?? this.baseAmountCents,
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
      receiptImagePaths: receiptImagePaths ?? this.receiptImagePaths,
    );
  }
}
