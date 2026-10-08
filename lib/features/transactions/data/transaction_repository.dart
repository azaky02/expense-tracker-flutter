import 'package:drift/drift.dart';

import '../../../core/db/database.dart';
import '../../../core/db/tables.dart';
import 'transaction_models.dart';

class TransactionInput {
  const TransactionInput({
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
  final PaymentMethodType paymentMethodType;
  final int? cardId;
  final DateTime date;
  final String? note;
  final String? attachmentUri;
  final String? beneficiaryName;
  final int? accountId;
  final int? toAccountId;
}

class TransactionFilters {
  const TransactionFilters({
    this.categoryIds,
    this.paymentMethodType,
    this.cardId,
    this.types,
    this.accountId,
    this.from,
    this.to,
    this.minAmount,
    this.maxAmount,
    this.person,
    this.search,
    this.hasAttachment,
  });
  /// Pass the main category's id plus all its children's ids to filter "this category or any
  /// of its sub-categories".
  final List<int>? categoryIds;
  final PaymentMethodType? paymentMethodType;
  final int? cardId;
  final Set<TransactionType>? types;
  final int? accountId;
  final DateTime? from;
  final DateTime? to;
  final double? minAmount;
  final double? maxAmount;
  final String? person;
  final String? search;
  final bool? hasAttachment;

  bool get isEmpty =>
      (categoryIds?.isEmpty ?? true) && paymentMethodType == null && cardId == null && types == null &&
      accountId == null && from == null && to == null && minAmount == null && maxAmount == null &&
      (person?.isEmpty ?? true) && (search?.isEmpty ?? true) && hasAttachment == null;

  TransactionFilters copyWith({String? search, Set<TransactionType>? types, bool clearTypes = false}) => TransactionFilters(
        categoryIds: categoryIds, paymentMethodType: paymentMethodType, cardId: cardId,
        types: clearTypes ? null : (types ?? this.types), accountId: accountId, from: from, to: to,
        minAmount: minAmount, maxAmount: maxAmount, person: person, search: search ?? this.search,
        hasAttachment: hasAttachment,
      );

  @override
  bool operator ==(Object other) =>
      other is TransactionFilters &&
      _listEq(other.categoryIds, categoryIds) && other.paymentMethodType == paymentMethodType && other.cardId == cardId &&
      _setEq(other.types, types) && other.accountId == accountId && other.from == from && other.to == to &&
      other.minAmount == minAmount && other.maxAmount == maxAmount && other.person == person &&
      other.search == search && other.hasAttachment == hasAttachment;

  @override
  int get hashCode => Object.hash(categoryIds?.length, paymentMethodType, cardId, types?.length, accountId, from, to,
      minAmount, maxAmount, person, search, hasAttachment);
}

bool _listEq(List<int>? a, List<int>? b) {
  if (a == null || b == null) return a == b;
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

bool _setEq<T>(Set<T>? a, Set<T>? b) => a == null || b == null ? a == b : (a.length == b.length && a.containsAll(b));

class TransactionRepository {
  TransactionRepository(this._db);
  final AppDatabase _db;

  late final _toAccounts = _db.alias(_db.accounts, 'to_acc');

  JoinedSelectStatement<HasResultSet, dynamic> _baseQuery() {
    return _db.select(_db.transactions).join([
      innerJoin(_db.categories, _db.categories.id.equalsExp(_db.transactions.categoryId)),
      leftOuterJoin(_db.cards, _db.cards.id.equalsExp(_db.transactions.cardId)),
      leftOuterJoin(_db.accounts, _db.accounts.id.equalsExp(_db.transactions.accountId)),
      leftOuterJoin(_toAccounts, _toAccounts.id.equalsExp(_db.transactions.toAccountId)),
    ]);
  }

  TransactionWithDetails _mapRow(TypedResult row) {
    final transaction = row.readTable(_db.transactions);
    final category = row.readTable(_db.categories);
    final card = row.readTableOrNull(_db.cards);
    return TransactionWithDetails(
      transaction: transaction,
      categoryName: category.name,
      categoryIcon: category.icon,
      categoryColor: category.color,
      cardNickname: card?.nickname,
      accountName: row.readTableOrNull(_db.accounts)?.name,
      toAccountName: row.readTableOrNull(_toAccounts)?.name,
      parentCategoryId: category.parentCategoryId,
    );
  }

  Future<int> create(TransactionInput input) async {
    final id = await _db.into(_db.transactions).insert(
          TransactionsCompanion.insert(
            amount: input.amount,
            type: input.type,
            categoryId: input.categoryId,
            paymentMethodType: input.paymentMethodType,
            cardId: Value(input.paymentMethodType == PaymentMethodType.card ? input.cardId : null),
            date: input.date,
            note: Value(input.note),
            attachmentUri: Value(input.attachmentUri),
            beneficiaryName: Value(input.beneficiaryName),
            accountId: Value(input.accountId),
            toAccountId: Value(input.type == TransactionType.transfer ? input.toAccountId : null),
          ),
        );
    await _upsertBeneficiary(input.beneficiaryName);
    return id;
  }

  Future<void> update(int id, TransactionInput input) async {
    await (_db.update(_db.transactions)..where((t) => t.id.equals(id))).write(
      TransactionsCompanion(
        amount: Value(input.amount),
        type: Value(input.type),
        categoryId: Value(input.categoryId),
        paymentMethodType: Value(input.paymentMethodType),
        cardId: Value(input.paymentMethodType == PaymentMethodType.card ? input.cardId : null),
        date: Value(input.date),
        note: Value(input.note),
        attachmentUri: Value(input.attachmentUri),
        beneficiaryName: Value(input.beneficiaryName),
        accountId: Value(input.accountId),
        toAccountId: Value(input.type == TransactionType.transfer ? input.toAccountId : null),
      ),
    );
    await _upsertBeneficiary(input.beneficiaryName);
  }

  Future<void> updateNote(int id, String note) {
    return (_db.update(_db.transactions)..where((t) => t.id.equals(id)))
        .write(TransactionsCompanion(note: Value(note)));
  }

  Future<void> delete(int id) {
    return (_db.delete(_db.transactions)..where((t) => t.id.equals(id))).go();
  }

  Future<TransactionWithDetails?> getById(int id) async {
    final query = _baseQuery()..where(_db.transactions.id.equals(id));
    final row = await query.getSingleOrNull();
    return row == null ? null : _mapRow(row);
  }

  Stream<List<TransactionWithDetails>> watchRecent(int limit) {
    final query = _baseQuery()
      ..orderBy([OrderingTerm.desc(_db.transactions.date), OrderingTerm.desc(_db.transactions.createdAt)])
      ..limit(limit);
    return query.watch().map((rows) => rows.map(_mapRow).toList());
  }

  Stream<List<TransactionWithDetails>> watchList(TransactionFilters filters) {
    final query = _baseQuery()
      ..orderBy([OrderingTerm.desc(_db.transactions.date), OrderingTerm.desc(_db.transactions.createdAt)]);
    if (filters.categoryIds != null && filters.categoryIds!.isNotEmpty) {
      query.where(_db.transactions.categoryId.isIn(filters.categoryIds!));
    }
    if (filters.paymentMethodType != null) {
      query.where(_db.transactions.paymentMethodType.equalsValue(filters.paymentMethodType!));
    }
    if (filters.cardId != null) {
      query.where(_db.transactions.cardId.equals(filters.cardId!));
    }
    final t = _db.transactions;
    if (filters.types != null && filters.types!.isNotEmpty) {
      query.where(t.type.isIn(filters.types!.map((x) => x.name)));
    }
    if (filters.accountId != null) {
      query.where(t.accountId.equals(filters.accountId!) | t.toAccountId.equals(filters.accountId!));
    }
    if (filters.from != null) query.where(t.date.isBiggerOrEqualValue(filters.from!));
    if (filters.to != null) query.where(t.date.isSmallerOrEqualValue(filters.to!));
    if (filters.minAmount != null) query.where(t.amount.isBiggerOrEqualValue(filters.minAmount!));
    if (filters.maxAmount != null) query.where(t.amount.isSmallerOrEqualValue(filters.maxAmount!));
    if (filters.person != null && filters.person!.isNotEmpty) query.where(t.beneficiaryName.equals(filters.person!));
    if (filters.hasAttachment == true) query.where(t.attachmentUri.isNotNull());
    final q = filters.search?.trim();
    if (q != null && q.isNotEmpty) {
      final like = '%$q%';
      query.where(t.note.like(like) | t.beneficiaryName.like(like) | _db.categories.name.like(like) | t.amount.cast<String>().like(like));
    }
    return query.watch().map((rows) => rows.map(_mapRow).toList());
  }

  Stream<List<TransactionWithDetails>> watchCardTransactions(int cardId) {
    final query = _baseQuery()
      ..where(_db.transactions.cardId.equals(cardId))
      ..orderBy([OrderingTerm.desc(_db.transactions.date)]);
    return query.watch().map((rows) => rows.map(_mapRow).toList());
  }

  Stream<MonthSummary> watchMonthSummary(DateTime start, DateTime end) {
    final query = _db.select(_db.transactions)
      ..where((t) => t.date.isBetweenValues(start, end));
    return query.watch().map((rows) {
      var income = 0.0;
      var expense = 0.0;
      for (final t in rows) {
        if (t.type == TransactionType.income) {
          income += t.amount;
        } else if (t.type == TransactionType.expense) {
          expense += t.amount;
        } // amanat (trustIn / trustOut) is neither
      }
      return MonthSummary(income: income, expense: expense);
    });
  }

  /// Rolls sub-category totals up into their main category (one level of nesting only).
  Stream<List<CategoryBreakdownItem>> watchExpenseCategoryBreakdown(DateTime start, DateTime end) {
    final query = _db.select(_db.transactions).join([
      innerJoin(_db.categories, _db.categories.id.equalsExp(_db.transactions.categoryId)),
    ])
      ..where(
        _db.transactions.type.equalsValue(TransactionType.expense) &
            _db.transactions.date.isBetweenValues(start, end),
      );
    return query.watch().map((rows) {
      final totals = <int, CategoryBreakdownItem>{};
      for (final row in rows) {
        final transaction = row.readTable(_db.transactions);
        final category = row.readTable(_db.categories);
        final rollupId = category.parentCategoryId ?? category.id;
        final existing = totals[rollupId];
        if (existing != null) {
          totals[rollupId] = CategoryBreakdownItem(
            categoryId: rollupId,
            categoryName: existing.categoryName,
            categoryColor: existing.categoryColor,
            total: existing.total + transaction.amount,
          );
        } else {
          totals[rollupId] = CategoryBreakdownItem(
            categoryId: rollupId,
            categoryName: category.parentCategoryId == null ? category.name : category.name,
            categoryColor: category.color,
            total: transaction.amount,
          );
        }
      }
      final list = totals.values.toList()..sort((a, b) => b.total.compareTo(a.total));
      return list;
    });
  }

  Future<double> getCategoryMonthTotal(int categoryId, DateTime start, DateTime end) async {
    final query = _db.select(_db.transactions)
      ..where((t) => t.categoryId.equals(categoryId) & t.date.isBetweenValues(start, end));
    final rows = await query.get();
    return rows.fold<double>(0, (sum, t) => sum + t.amount);
  }

  Stream<double> watchCardMonthSpend(int cardId, DateTime start, DateTime end) {
    final query = _db.select(_db.transactions)
      ..where(
        (t) =>
            t.cardId.equals(cardId) &
            t.type.equalsValue(TransactionType.expense) &
            t.date.isBetweenValues(start, end),
      );
    return query.watch().map((rows) => rows.fold<double>(0, (sum, t) => sum + t.amount));
  }

  Stream<double> watchCashMonthSpend(DateTime start, DateTime end) {
    final query = _db.select(_db.transactions)
      ..where(
        (t) =>
            t.paymentMethodType.equalsValue(PaymentMethodType.cash) &
            t.type.equalsValue(TransactionType.expense) &
            t.date.isBetweenValues(start, end),
      );
    return query.watch().map((rows) => rows.fold<double>(0, (sum, t) => sum + t.amount));
  }

  /// Cash vs. each card's spend for the month.
  Stream<List<PaymentMethodBreakdownItem>> watchExpenseByPaymentMethod(DateTime start, DateTime end) {
    final query = _db.select(_db.transactions).join([
      leftOuterJoin(_db.cards, _db.cards.id.equalsExp(_db.transactions.cardId)),
    ])
      ..where(
        _db.transactions.type.equalsValue(TransactionType.expense) &
            _db.transactions.date.isBetweenValues(start, end),
      );
    return query.watch().map((rows) {
      final totals = <String, PaymentMethodBreakdownItem>{};
      for (final row in rows) {
        final transaction = row.readTable(_db.transactions);
        final card = row.readTableOrNull(_db.cards);
        final key = card?.id.toString() ?? 'cash';
        final existing = totals[key];
        if (existing != null) {
          totals[key] = PaymentMethodBreakdownItem(
            label: existing.label,
            cardId: existing.cardId,
            color: existing.color,
            total: existing.total + transaction.amount,
          );
        } else {
          totals[key] = PaymentMethodBreakdownItem(
            label: card?.nickname ?? 'cash',
            cardId: card?.id,
            color: card?.color ?? '',
            total: transaction.amount,
          );
        }
      }
      return totals.values.toList()..sort((a, b) => b.total.compareTo(a.total));
    });
  }

  /// Last [monthsBack] months (oldest first) of expense/income totals.
  Future<List<MonthTotal>> getMonthOverMonthTotals(int monthsBack, [DateTime? reference]) async {
    final ref = reference ?? DateTime.now();
    final results = <MonthTotal>[];
    for (var i = monthsBack - 1; i >= 0; i--) {
      final monthStart = DateTime(ref.year, ref.month - i, 1);
      final monthEnd = DateTime(ref.year, ref.month - i + 1, 0);
      final rows = await (_db.select(_db.transactions)
            ..where((t) => t.date.isBetweenValues(monthStart, monthEnd)))
          .get();
      var income = 0.0;
      var expense = 0.0;
      for (final t in rows) {
        if (t.type == TransactionType.income) {
          income += t.amount;
        } else if (t.type == TransactionType.expense) {
          expense += t.amount;
        } // amanat (trustIn / trustOut) is neither
      }
      final monthKey = '${monthStart.year}-${monthStart.month.toString().padLeft(2, '0')}';
      results.add(MonthTotal(month: monthKey, expense: expense, income: income));
    }
    return results;
  }

  /// Groups expense spend by beneficiary for the month.
  Future<List<BeneficiaryBreakdownItem>> getBeneficiaryBreakdown(DateTime start, DateTime end) async {
    final rows = await (_db.select(_db.transactions)
          ..where(
            (t) =>
                t.type.equalsValue(TransactionType.expense) & t.date.isBetweenValues(start, end),
          ))
        .get();
    final totals = <String, double>{};
    for (final t in rows) {
      final name = t.beneficiaryName?.trim();
      if (name == null || name.isEmpty) continue;
      totals[name] = (totals[name] ?? 0) + t.amount;
    }
    final list = totals.entries
        .map((e) => BeneficiaryBreakdownItem(beneficiaryName: e.key, total: e.value))
        .toList()
      ..sort((a, b) => b.total.compareTo(a.total));
    return list;
  }

  /// The one system category (type 'trust') every amanat transaction is filed under.
  Future<int> trustCategoryId() => systemCategoryId(CategoryType.trust);

  /// The system category of a non-user type (trust, transfer).
  Future<int> systemCategoryId(CategoryType type) async {
    final row = await (_db.select(_db.categories)..where((c) => c.type.equalsValue(type))..limit(1)).getSingle();
    return row.id;
  }

  Stream<List<TrustBalance>> watchTrustBalances() {
    final query = _db.select(_db.transactions)
      ..where((t) => t.type.isIn([TransactionType.trustIn.name, TransactionType.trustOut.name]));
    return query.watch().map((rows) {
      final byName = <String, TrustBalance>{};
      for (final t in rows) {
        final name = t.beneficiaryName?.trim();
        if (name == null || name.isEmpty) continue;
        final old = byName[name];
        final received = (old?.received ?? 0) + (t.type == TransactionType.trustIn ? t.amount : 0);
        final paid = (old?.paid ?? 0) + (t.type == TransactionType.trustOut ? t.amount : 0);
        final last = old != null && old.lastDate.isAfter(t.date) ? old.lastDate : t.date;
        byName[name] = TrustBalance(name: name, received: received, paid: paid, lastDate: last);
      }
      return byName.values.toList()..sort((a, b) => b.lastDate.compareTo(a.lastDate));
    });
  }

  Stream<List<TransactionWithDetails>> watchTrustTransactions(String name) {
    final query = _baseQuery()
      ..where(_db.transactions.beneficiaryName.equals(name) &
          _db.transactions.type.isIn([TransactionType.trustIn.name, TransactionType.trustOut.name]))
      ..orderBy([OrderingTerm.desc(_db.transactions.date), OrderingTerm.desc(_db.transactions.createdAt)]);
    return query.watch().map((rows) => rows.map(_mapRow).toList());
  }

  Future<void> _upsertBeneficiary(String? name) async {
    final trimmed = name?.trim();
    if (trimmed == null || trimmed.isEmpty) return;
    final now = DateTime.now();
    final existing = await (_db.select(_db.beneficiaries)..where((b) => b.name.equals(trimmed)))
        .getSingleOrNull();
    if (existing != null) {
      await (_db.update(_db.beneficiaries)..where((b) => b.id.equals(existing.id)))
          .write(BeneficiariesCompanion(lastUsedAt: Value(now)));
    } else {
      await _db.into(_db.beneficiaries).insert(
            BeneficiariesCompanion.insert(name: trimmed, lastUsedAt: now),
          );
    }
  }
}
