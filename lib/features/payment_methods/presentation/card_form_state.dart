import '../../../core/db/tables.dart';

class CardFormValues {
  const CardFormValues({
    required this.bankId,
    required this.cardType,
    required this.cardCategory,
    required this.nickname,
    required this.last4Digits,
    this.dueDateDay,
    this.statementDateDay,
    this.creditLimit,
  });

  final int? bankId;
  final CardType cardType;
  final CardCategory cardCategory;
  final String nickname;
  final String last4Digits;
  final int? dueDateDay;
  final int? statementDateDay;
  final double? creditLimit;

  CardFormValues copyWith({
    int? bankId,
    CardType? cardType,
    CardCategory? cardCategory,
    String? nickname,
    String? last4Digits,
    int? dueDateDay,
    int? statementDateDay,
    double? creditLimit,
  }) {
    return CardFormValues(
      bankId: bankId ?? this.bankId,
      cardType: cardType ?? this.cardType,
      cardCategory: cardCategory ?? this.cardCategory,
      nickname: nickname ?? this.nickname,
      last4Digits: last4Digits ?? this.last4Digits,
      dueDateDay: dueDateDay ?? this.dueDateDay,
      statementDateDay: statementDateDay ?? this.statementDateDay,
      creditLimit: creditLimit ?? this.creditLimit,
    );
  }

  bool get isValid =>
      bankId != null &&
      nickname.trim().isNotEmpty &&
      RegExp(r'^\d{4}$').hasMatch(last4Digits) &&
      (cardCategory != CardCategory.credit || dueDateDay != null);
}
