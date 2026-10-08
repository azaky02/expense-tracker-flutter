import '../../../core/db/database.dart';

class TransactionWithDetails {
  const TransactionWithDetails({
    required this.transaction,
    required this.categoryName,
    required this.categoryIcon,
    required this.categoryColor,
    this.cardNickname,
  });

  final Transaction transaction;
  final String categoryName;
  final String categoryIcon;
  final String categoryColor;
  final String? cardNickname;
}

class MonthSummary {
  const MonthSummary({required this.income, required this.expense});
  final double income;
  final double expense;
}

class CategoryBreakdownItem {
  const CategoryBreakdownItem({
    required this.categoryId,
    required this.categoryName,
    required this.categoryColor,
    required this.total,
  });
  final int categoryId;
  final String categoryName;
  final String categoryColor;
  final double total;
}

class PaymentMethodBreakdownItem {
  const PaymentMethodBreakdownItem({
    required this.label,
    required this.cardId,
    required this.color,
    required this.total,
  });
  final String label;
  final int? cardId;
  final String color;
  final double total;
}

class MonthTotal {
  const MonthTotal({required this.month, required this.expense, required this.income});
  final String month; // 'YYYY-MM'
  final double expense;
  final double income;
}

class BeneficiaryBreakdownItem {
  const BeneficiaryBreakdownItem({required this.beneficiaryName, required this.total});
  final String beneficiaryName;
  final double total;
}

/// What one person's amanat add up to: money received to hold, and money paid out to them.
class TrustBalance {
  const TrustBalance({required this.name, required this.received, required this.paid, required this.lastDate});
  final String name;
  final double received;
  final double paid;
  final DateTime lastDate;

  /// > 0: you are holding this much for them. < 0: you paid out more than you received (they owe you).
  double get balance => received - paid;
}
