import 'package:drift/drift.dart';

import '../../../core/db/database.dart';
import '../../../core/db/tables.dart';
import '../../../core/theme/app_semantic_colors.dart';
import '../../../core/utils/color_utils.dart';

class CardWithBank {
  const CardWithBank({required this.card, required this.bankName});
  // Named `Card` by drift (from the `Cards` table) — this clashes with Flutter's Material
  // `Card` widget, so UI code should reference fields via `cardWithBank.card.x` rather than
  // ever declaring a bare `Card`-typed variable (which would need disambiguating imports).
  final Card card;
  final String bankName;
}

class CardRepository {
  CardRepository(this._db);
  final AppDatabase _db;

  Stream<List<CardWithBank>> watchActive() {
    final query = _db.select(_db.cards).join([
      innerJoin(_db.banks, _db.banks.id.equalsExp(_db.cards.bankId)),
    ])
      ..where(_db.cards.isActive.equals(true));
    return query.watch().map(
          (rows) => rows
              .map(
                (row) => CardWithBank(
                  card: row.readTable(_db.cards),
                  bankName: row.readTable(_db.banks).name,
                ),
              )
              .toList(),
        );
  }

  Future<CardWithBank?> getById(int id) async {
    final query = _db.select(_db.cards).join([
      innerJoin(_db.banks, _db.banks.id.equalsExp(_db.cards.bankId)),
    ])
      ..where(_db.cards.id.equals(id));
    final row = await query.getSingleOrNull();
    if (row == null) return null;
    return CardWithBank(card: row.readTable(_db.cards), bankName: row.readTable(_db.banks).name);
  }

  Future<int> create({
    required int bankId,
    required CardType cardType,
    required CardCategory cardCategory,
    required String nickname,
    required String last4Digits,
    int? dueDateDay,
    int? statementDateDay,
    double? creditLimit,
  }) async {
    final existingCount = await (_db.select(_db.cards)).get().then((rows) => rows.length);
    final color = AppSemanticColors.light.cardColorRotation[
        existingCount % AppSemanticColors.light.cardColorRotation.length];
    return _db.into(_db.cards).insert(
          CardsCompanion.insert(
            bankId: bankId,
            cardType: cardType,
            cardCategory: cardCategory,
            nickname: nickname,
            last4Digits: last4Digits,
            dueDateDay: Value(cardCategory == CardCategory.credit ? dueDateDay : null),
            statementDateDay: Value(cardCategory == CardCategory.credit ? statementDateDay : null),
            creditLimit: Value(creditLimit),
            color: colorToHex(color),
          ),
        );
  }

  Future<void> update(
    int id, {
    required int bankId,
    required CardType cardType,
    required CardCategory cardCategory,
    required String nickname,
    required String last4Digits,
    int? dueDateDay,
    int? statementDateDay,
    double? creditLimit,
  }) {
    return (_db.update(_db.cards)..where((c) => c.id.equals(id))).write(
      CardsCompanion(
        bankId: Value(bankId),
        cardType: Value(cardType),
        cardCategory: Value(cardCategory),
        nickname: Value(nickname),
        last4Digits: Value(last4Digits),
        dueDateDay: Value(cardCategory == CardCategory.credit ? dueDateDay : null),
        statementDateDay: Value(cardCategory == CardCategory.credit ? statementDateDay : null),
        creditLimit: Value(creditLimit),
      ),
    );
  }

  Future<void> deactivate(int id) {
    return (_db.update(_db.cards)..where((c) => c.id.equals(id)))
        .write(const CardsCompanion(isActive: Value(false)));
  }
}
