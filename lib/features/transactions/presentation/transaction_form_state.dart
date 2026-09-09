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
  });

  final double amount;
  final TransactionType type;
  final int categoryId;
  final PaymentMethodType paymentMethodType;
  final int? cardId;
  final DateTime date;
  final String? note;
  final String? attachmentUri;
  final String? beneficiaryName;

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
      beneficiaryName: beneficiaryName ?? this.beneficiaryName,
    );
  }

  bool get isValid =>
      amount > 0 &&
      categoryId != 0 &&
      (paymentMethodType == PaymentMethodType.cash || cardId != null);

  TransactionInput toInput() => TransactionInput(
        amount: amount,
        type: type,
        categoryId: categoryId,
        paymentMethodType: paymentMethodType,
        cardId: cardId,
        date: date,
        note: note,
        attachmentUri: attachmentUri,
        beneficiaryName: beneficiaryName,
      );
}
