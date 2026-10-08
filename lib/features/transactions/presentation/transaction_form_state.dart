import '../../../core/db/tables.dart';
import '../data/transaction_repository.dart';

class TransactionFormValues {
  const TransactionFormValues({
    required this.amount,
    required this.type,
    required this.categoryId,
    required this.paymentMethodType,
    this.cardId,
    required this.date,
    this.note,
    this.attachmentUri,
    this.beneficiaryName,
    this.accountId,
    this.toAccountId,
  });

  final double amount;
  final TransactionType type;
  final int categoryId;
  /// Derived from the account (card accounts = card) and kept for older reports/filters.
  final PaymentMethodType paymentMethodType;
  final int? cardId;
  final DateTime date;
  final String? note;
  final String? attachmentUri;
  final String? beneficiaryName;
  final int? accountId;
  final int? toAccountId;

  TransactionFormValues copyWith({
    double? amount,
    TransactionType? type,
    int? categoryId,
    PaymentMethodType? paymentMethodType,
    int? cardId,
    bool clearCardId = false,
    DateTime? date,
    String? note,
    String? attachmentUri,
    bool clearAttachment = false,
    String? beneficiaryName,
    bool clearBeneficiary = false,
    int? accountId,
    int? toAccountId,
    bool clearToAccount = false,
  }) {
    return TransactionFormValues(
      amount: amount ?? this.amount,
      type: type ?? this.type,
      categoryId: categoryId ?? this.categoryId,
      paymentMethodType: paymentMethodType ?? this.paymentMethodType,
      cardId: clearCardId ? null : (cardId ?? this.cardId),
      date: date ?? this.date,
      note: note ?? this.note,
      attachmentUri: clearAttachment ? null : (attachmentUri ?? this.attachmentUri),
      beneficiaryName: clearBeneficiary ? null : (beneficiaryName ?? this.beneficiaryName),
      accountId: accountId ?? this.accountId,
      toAccountId: clearToAccount ? null : (toAccountId ?? this.toAccountId),
    );
  }

  bool get isTrust => type == TransactionType.trustIn || type == TransactionType.trustOut;
  bool get isTransfer => type == TransactionType.transfer;

  bool get isValid {
    if (amount <= 0 || categoryId == 0) return false;
    if (isTransfer) return accountId != null && toAccountId != null && accountId != toAccountId;
    if (isTrust) return beneficiaryName?.trim().isNotEmpty ?? false;
    return accountId != null;
  }

  TransactionInput toInput() => TransactionInput(
        amount: amount,
        type: type,
        categoryId: categoryId,
        paymentMethodType: paymentMethodType,
        cardId: paymentMethodType == PaymentMethodType.card ? cardId : null,
        date: date,
        note: note,
        attachmentUri: attachmentUri,
        beneficiaryName: beneficiaryName,
        accountId: accountId,
        toAccountId: isTransfer ? toAccountId : null,
      );
}
