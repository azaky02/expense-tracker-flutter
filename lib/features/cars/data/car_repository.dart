import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/database.dart';
import '../../../core/db/database_provider.dart';
import '../../../core/db/tables.dart';

class CarExpenseItem {
  const CarExpenseItem({
    required this.expense,
    required this.transaction,
    required this.categoryName,
    required this.categoryIcon,
    this.categorySyncId,
    this.parentCategoryName,
    this.accountName,
    this.fuelTypeName,
  });
  final CarExpense expense;
  final Transaction transaction;
  final String categoryName;
  final String categoryIcon;

  /// 'seed-cat-car-fuel', 'seed-cat-car-oil', ... for the built-in car categories.
  final String? categorySyncId;
  final String? parentCategoryName;
  final String? accountName;
  final String? fuelTypeName;

  String get categoryPath => parentCategoryName == null ? categoryName : '$parentCategoryName › $categoryName';
}

class CarWithStats {
  const CarWithStats(this.car, this.expenses);
  final Car car;

  /// Newest first.
  final List<CarExpenseItem> expenses;

  double get total => expenses.fold(0, (s, e) => s + e.transaction.amount);
  double get totalLiters => expenses.fold(0, (s, e) => s + (e.expense.liters ?? 0));
  int? get lastOdometer {
    for (final e in expenses) {
      if (e.expense.odometer != null) return e.expense.odometer;
    }
    return null;
  }

  /// Litres per 100 km between the first and last odometer readings of fuel fills.
  double? get litersPer100Km {
    final fills = expenses.where((e) => e.expense.odometer != null && (e.expense.liters ?? 0) > 0).toList();
    if (fills.length < 2) return null;
    final newest = fills.first.expense.odometer!;
    final oldest = fills.last.expense.odometer!;
    final km = newest - oldest;
    if (km <= 0) return null;
    // The oldest fill's litres were burnt before the first reading, so leave them out.
    final liters = fills.take(fills.length - 1).fold<double>(0, (s, e) => s + e.expense.liters!);
    return liters / km * 100;
  }
}

/// What the car-expense form saves.
class CarExpenseInput {
  const CarExpenseInput({
    required this.carId,
    required this.categoryId,
    required this.amount,
    required this.accountId,
    required this.date,
    this.odometer,
    this.liters,
    this.fuelTypeId,
    this.pricePerLiter,
    this.latitude,
    this.longitude,
    this.note,
    this.beneficiary,
  });
  final int carId;
  final int categoryId;
  final double amount;
  final int accountId;
  final DateTime date;
  final int? odometer;
  final double? liters;
  final int? fuelTypeId;
  final double? pricePerLiter;
  final double? latitude;
  final double? longitude;
  final String? note;
  final String? beneficiary;
}

class CarRepository {
  CarRepository(this._db);
  final AppDatabase _db;

  Stream<List<CarWithStats>> watchCars() {
    return _db
        .customSelect('SELECT 1', readsFrom: {_db.cars, _db.carExpenses, _db.transactions, _db.categories, _db.fuelTypes})
        .watch()
        .asyncMap((_) => loadCars());
  }

  Future<List<CarWithStats>> loadCars() async {
    final cars = await (_db.select(_db.cars)..orderBy([(c) => OrderingTerm.asc(c.createdAt)])).get();
    final parents = _db.alias(_db.categories, 'parent_cat');
    final rows = await (_db.select(_db.carExpenses).join([
      innerJoin(_db.transactions, _db.transactions.id.equalsExp(_db.carExpenses.transactionId)),
      innerJoin(_db.categories, _db.categories.id.equalsExp(_db.transactions.categoryId)),
      leftOuterJoin(parents, parents.id.equalsExp(_db.categories.parentCategoryId)),
      leftOuterJoin(_db.accounts, _db.accounts.id.equalsExp(_db.transactions.accountId)),
      leftOuterJoin(_db.fuelTypes, _db.fuelTypes.id.equalsExp(_db.carExpenses.fuelTypeId)),
    ])..orderBy([OrderingTerm.desc(_db.transactions.date), OrderingTerm.desc(_db.carExpenses.id)])).get();
    final items = [
      for (final r in rows)
        CarExpenseItem(
          expense: r.readTable(_db.carExpenses),
          transaction: r.readTable(_db.transactions),
          categoryName: r.readTable(_db.categories).name,
          categoryIcon: r.readTable(_db.categories).icon,
          categorySyncId: r.readTable(_db.categories).syncId,
          parentCategoryName: r.readTableOrNull(parents)?.name,
          accountName: r.readTableOrNull(_db.accounts)?.name,
          fuelTypeName: r.readTableOrNull(_db.fuelTypes)?.name,
        ),
    ];
    return [for (final c in cars) CarWithStats(c, items.where((i) => i.expense.carId == c.id).toList())];
  }

  Future<int> createCar({
    required String name,
    required String brand,
    required int modelYear,
    String? plate,
    int oilIntervalKm = 10000,
    int oilIntervalMonths = 6,
    DateTime? licenseExpiry,
    DateTime? insuranceExpiry,
  }) => _db
      .into(_db.cars)
      .insert(
        CarsCompanion.insert(
          name: name,
          brand: brand,
          modelYear: modelYear,
          plate: Value(plate),
          oilIntervalKm: Value(oilIntervalKm),
          oilIntervalMonths: Value(oilIntervalMonths),
          licenseExpiry: Value(licenseExpiry),
          insuranceExpiry: Value(insuranceExpiry),
        ),
      );

  Future<void> updateCar(
    int id, {
    required String name,
    required String brand,
    required int modelYear,
    String? plate,
    required int oilIntervalKm,
    required int oilIntervalMonths,
    DateTime? licenseExpiry,
    DateTime? insuranceExpiry,
  }) => (_db.update(_db.cars)..where((c) => c.id.equals(id))).write(
    CarsCompanion(
      name: Value(name),
      brand: Value(brand),
      modelYear: Value(modelYear),
      plate: Value(plate),
      oilIntervalKm: Value(oilIntervalKm),
      oilIntervalMonths: Value(oilIntervalMonths),
      licenseExpiry: Value(licenseExpiry),
      insuranceExpiry: Value(insuranceExpiry),
    ),
  );

  /// Deletes the car, its expense rows and their transactions.
  Future<void> deleteCar(int id) async {
    await _db.transaction(() async {
      final expenses = await (_db.select(_db.carExpenses)..where((e) => e.carId.equals(id))).get();
      for (final e in expenses) {
        await _deleteExpenseRow(e);
      }
      await (_db.delete(_db.cars)..where((c) => c.id.equals(id))).go();
    });
  }

  /// Records the expense as an ordinary transaction plus the car details.
  Future<int> addExpense(CarExpenseInput input) async {
    return _db.transaction(() async {
      final account = await (_db.select(_db.accounts)..where((a) => a.id.equals(input.accountId))).getSingle();
      final car = await (_db.select(_db.cars)..where((c) => c.id.equals(input.carId))).getSingle();
      final note = [car.name, if (input.note != null && input.note!.trim().isNotEmpty) input.note!.trim()].join(' – ');
      final txId = await _db
          .into(_db.transactions)
          .insert(
            TransactionsCompanion.insert(
              amount: input.amount,
              type: TransactionType.expense,
              categoryId: input.categoryId,
              paymentMethodType: account.cardId != null ? PaymentMethodType.card : PaymentMethodType.cash,
              cardId: Value(account.cardId),
              date: input.date,
              note: Value(note),
              beneficiaryName: Value(input.beneficiary?.trim().isEmpty ?? true ? null : input.beneficiary!.trim()),
              accountId: Value(input.accountId),
            ),
          );
      return _db
          .into(_db.carExpenses)
          .insert(
            CarExpensesCompanion.insert(
              carId: input.carId,
              transactionId: txId,
              odometer: Value(input.odometer),
              liters: Value(input.liters),
              fuelTypeId: Value(input.fuelTypeId),
              pricePerLiter: Value(input.pricePerLiter),
              latitude: Value(input.latitude),
              longitude: Value(input.longitude),
            ),
          );
    });
  }

  /// The expense with its transaction, for editing.
  Future<(CarExpense, Transaction)?> loadExpense(int expenseId) async {
    final e = await (_db.select(_db.carExpenses)..where((x) => x.id.equals(expenseId))).getSingleOrNull();
    if (e == null) return null;
    final t = await (_db.select(_db.transactions)..where((x) => x.id.equals(e.transactionId))).getSingleOrNull();
    return t == null ? null : (e, t);
  }

  /// The user's own note, without the "car name – " prefix [addExpense] stores.
  static String userNote(String? stored, String carName) {
    if (stored == null || stored == carName) return '';
    final prefix = '$carName – ';
    return stored.startsWith(prefix) ? stored.substring(prefix.length) : stored;
  }

  /// Saves changes to an existing car expense (and its transaction). The recorded location stays.
  Future<void> updateExpense(int expenseId, CarExpenseInput input) async {
    await _db.transaction(() async {
      final e = await (_db.select(_db.carExpenses)..where((x) => x.id.equals(expenseId))).getSingle();
      final account = await (_db.select(_db.accounts)..where((a) => a.id.equals(input.accountId))).getSingle();
      final car = await (_db.select(_db.cars)..where((c) => c.id.equals(input.carId))).getSingle();
      final note = [car.name, if (input.note != null && input.note!.trim().isNotEmpty) input.note!.trim()].join(' – ');
      await (_db.update(_db.transactions)..where((t) => t.id.equals(e.transactionId))).write(
        TransactionsCompanion(
          amount: Value(input.amount),
          categoryId: Value(input.categoryId),
          paymentMethodType: Value(account.cardId != null ? PaymentMethodType.card : PaymentMethodType.cash),
          cardId: Value(account.cardId),
          date: Value(input.date),
          note: Value(note),
          beneficiaryName: Value(input.beneficiary?.trim().isEmpty ?? true ? null : input.beneficiary!.trim()),
          accountId: Value(input.accountId),
        ),
      );
      await (_db.update(_db.carExpenses)..where((x) => x.id.equals(expenseId))).write(
        CarExpensesCompanion(
          carId: Value(input.carId),
          odometer: Value(input.odometer),
          liters: Value(input.liters),
          fuelTypeId: Value(input.fuelTypeId),
          pricePerLiter: Value(input.pricePerLiter),
          latitude: input.latitude == null ? const Value.absent() : Value(input.latitude),
          longitude: input.longitude == null ? const Value.absent() : Value(input.longitude),
        ),
      );
    });
  }

  Future<void> deleteExpense(CarExpense e) => _db.transaction(() => _deleteExpenseRow(e));

  Future<void> _deleteExpenseRow(CarExpense e) async {
    await (_db.delete(_db.carExpenses)..where((x) => x.id.equals(e.id))).go();
    await (_db.delete(_db.transactions)..where((t) => t.id.equals(e.transactionId))).go();
  }

  // Fuel prices (master data).
  Stream<List<FuelType>> watchFuelTypes() => (_db.select(_db.fuelTypes)..orderBy([(f) => OrderingTerm.asc(f.id)])).watch();

  Future<void> saveFuelType({int? id, required String name, required double price}) async {
    if (id == null) {
      await _db.into(_db.fuelTypes).insert(FuelTypesCompanion.insert(name: name, pricePerLiter: price));
    } else {
      await (_db.update(
        _db.fuelTypes,
      )..where((f) => f.id.equals(id))).write(FuelTypesCompanion(name: Value(name), pricePerLiter: Value(price)));
    }
  }

  Future<void> deleteFuelType(int id) => (_db.delete(_db.fuelTypes)..where((f) => f.id.equals(id))).go();
}

final carRepositoryProvider = Provider<CarRepository>((ref) => CarRepository(ref.watch(databaseProvider)));
final carsProvider = StreamProvider<List<CarWithStats>>((ref) => ref.watch(carRepositoryProvider).watchCars());
final fuelTypesProvider = StreamProvider<List<FuelType>>((ref) => ref.watch(carRepositoryProvider).watchFuelTypes());
