import 'car_repository.dart';

const fuelCategorySyncId = 'seed-cat-car-fuel';
const oilCategorySyncId = 'seed-cat-car-oil';

/// Distance driven between two fill-ups and the fuel it took (full-tank method: the litres put
/// in at a fill-up are what was burnt since the previous one). The fuel burnt came from the
/// previous fill-up, so the segment is credited to that fill's station and fuel type.
class FuelSegment {
  const FuelSegment({required this.from, required this.to});
  final CarExpenseItem from;
  final CarExpenseItem to;

  int get km => to.expense.odometer! - from.expense.odometer!;
  double get liters => to.expense.liters!;
  double get litersPer100Km => liters / km * 100;
  double get kmPerLiter => km / liters;

  /// Fuel cost of this distance per km.
  double get costPerKm => to.transaction.amount / km;
  String get station => stationName(from);
  String? get fuelType => from.fuelTypeName;
}

String stationName(CarExpenseItem e) {
  final n = e.transaction.beneficiaryName?.trim();
  return n == null || n.isEmpty ? '' : n;
}

/// Average consumption per station (or per fuel type), best first.
class ConsumptionStat {
  const ConsumptionStat({required this.name, required this.segments, required this.litersPer100Km, required this.avgPricePerLiter});
  final String name;
  final int segments;
  final double litersPer100Km;
  final double? avgPricePerLiter;
}

enum MaintenanceKind { oil, license, insurance }

enum MaintenanceLevel { unknown, ok, soon, overdue }

class MaintenanceStatus {
  const MaintenanceStatus({
    required this.kind,
    required this.level,
    this.dueDate,
    this.dueKm,
    this.remainingKm,
    this.remainingDays,
    this.progress,
  });
  final MaintenanceKind kind;
  final MaintenanceLevel level;
  final DateTime? dueDate;
  final int? dueKm;
  final int? remainingKm;
  final int? remainingDays;

  /// 0..1 of the oil interval already used (by km or time, whichever is further along).
  final double? progress;

  bool get needsAttention => level == MaintenanceLevel.soon || level == MaintenanceLevel.overdue;
}

class CategoryShare {
  const CategoryShare(this.name, this.icon, this.total);
  final String name;
  final String icon;
  final double total;
}

/// Everything the car report shows, computed from the car's expenses.
class CarAnalytics {
  CarAnalytics(this.car, {DateTime? now}) : now = now ?? DateTime.now() {
    final withOdo = car.expenses.where((e) => e.expense.odometer != null).toList()
      ..sort((a, b) => a.expense.odometer!.compareTo(b.expense.odometer!));
    firstOdometer = withOdo.isEmpty ? null : withOdo.first.expense.odometer;
    lastOdometer = withOdo.isEmpty ? null : withOdo.last.expense.odometer;
    fills = car.expenses.where((e) => e.expense.odometer != null && (e.expense.liters ?? 0) > 0).toList()
      ..sort((a, b) => a.expense.odometer!.compareTo(b.expense.odometer!));
    for (var i = 1; i < fills.length; i++) {
      final s = FuelSegment(from: fills[i - 1], to: fills[i]);
      if (s.km > 0) segments.add(s);
    }
  }

  final CarWithStats car;
  final DateTime now;
  int? firstOdometer;
  int? lastOdometer;

  /// Fill-ups with an odometer reading, oldest first.
  late final List<CarExpenseItem> fills;
  final segments = <FuelSegment>[];

  static bool isFuel(CarExpenseItem e) => (e.expense.liters ?? 0) > 0 || e.categorySyncId == fuelCategorySyncId;

  double get totalSpent => car.total;
  double get fuelSpent => car.expenses.where(isFuel).fold(0.0, (s, e) => s + e.transaction.amount);
  double get otherSpent => totalSpent - fuelSpent;
  double get totalLiters => car.totalLiters;

  int? get kmDriven =>
      firstOdometer == null || lastOdometer == null || lastOdometer == firstOdometer ? null : lastOdometer! - firstOdometer!;
  double? get costPerKm => kmDriven == null ? null : totalSpent / kmDriven!;

  /// Overall L/100km over all measured segments.
  double? get avgLitersPer100Km {
    if (segments.isEmpty) return null;
    final km = segments.fold<int>(0, (s, x) => s + x.km);
    final liters = segments.fold<double>(0, (s, x) => s + x.liters);
    return liters / km * 100;
  }

  double? get kmPerLiter => avgLitersPer100Km == null ? null : 100 / avgLitersPer100Km!;
  double? get fuelCostPerKm {
    if (segments.isEmpty) return null;
    final km = segments.fold<int>(0, (s, x) => s + x.km);
    return segments.fold<double>(0, (s, x) => s + x.to.transaction.amount) / km;
  }

  FuelSegment? get bestSegment =>
      segments.isEmpty ? null : (segments.toList()..sort((a, b) => a.litersPer100Km.compareTo(b.litersPer100Km))).first;
  FuelSegment? get worstSegment =>
      segments.isEmpty ? null : (segments.toList()..sort((a, b) => b.litersPer100Km.compareTo(a.litersPer100Km))).first;
  FuelSegment? get lastSegment => segments.isEmpty ? null : segments.last;

  /// How the last fill compares with the average, in percent (+ = used more fuel).
  double? get lastVsAveragePercent {
    final last = lastSegment, avg = avgLitersPer100Km;
    if (last == null || avg == null || segments.length < 2) return null;
    return (last.litersPer100Km - avg) / avg * 100;
  }

  double? get avgPricePerLiter {
    final priced = car.expenses.where((e) => (e.expense.liters ?? 0) > 0).toList();
    final liters = priced.fold<double>(0, (s, e) => s + e.expense.liters!);
    if (liters == 0) return null;
    // Tips are not part of the fuel price.
    return priced.fold<double>(0, (s, e) => s + e.transaction.amount - (e.expense.tips ?? 0)) / liters;
  }

  double get totalTips => car.expenses.fold(0, (s, e) => s + (e.expense.tips ?? 0));

  /// Months covered by the expenses (at least 1).
  int get monthsCovered {
    if (car.expenses.isEmpty) return 1;
    final dates = car.expenses.map((e) => e.transaction.date).toList()..sort();
    final first = dates.first, last = dates.last;
    return (last.year - first.year) * 12 + last.month - first.month + 1;
  }

  double get avgMonthlySpend => totalSpent / monthsCovered;
  double? get avgKmPerMonth => kmDriven == null ? null : kmDriven! / monthsCovered;

  /// Spending per month for the last [months] months (oldest first): (month, fuel, other).
  List<(DateTime, double, double)> monthly({int months = 12}) {
    final out = <(DateTime, double, double)>[];
    for (var i = months - 1; i >= 0; i--) {
      final m = DateTime(now.year, now.month - i);
      var fuel = 0.0, other = 0.0;
      for (final e in car.expenses) {
        final d = e.transaction.date;
        if (d.year == m.year && d.month == m.month) {
          if (isFuel(e)) {
            fuel += e.transaction.amount;
          } else {
            other += e.transaction.amount;
          }
        }
      }
      out.add((m, fuel, other));
    }
    return out;
  }

  /// Spending per (sub-)category, largest first.
  List<CategoryShare> get byCategory {
    final map = <String, CategoryShare>{};
    for (final e in car.expenses) {
      final prev = map[e.categoryName];
      map[e.categoryName] = CategoryShare(e.categoryName, e.categoryIcon, (prev?.total ?? 0) + e.transaction.amount);
    }
    return map.values.toList()..sort((a, b) => b.total.compareTo(a.total));
  }

  List<ConsumptionStat> _rank(String Function(FuelSegment) key) {
    final groups = <String, List<FuelSegment>>{};
    for (final s in segments) {
      final k = key(s);
      if (k.isEmpty) continue;
      groups.putIfAbsent(k, () => []).add(s);
    }
    final out = [
      for (final g in groups.entries)
        ConsumptionStat(
          name: g.key,
          segments: g.value.length,
          litersPer100Km: g.value.fold<double>(0, (s, x) => s + x.liters) / g.value.fold<int>(0, (s, x) => s + x.km) * 100,
          avgPricePerLiter: () {
            final priced = g.value.where((x) => x.from.expense.pricePerLiter != null).toList();
            if (priced.isEmpty) return null;
            return priced.fold<double>(0, (s, x) => s + x.from.expense.pricePerLiter!) / priced.length;
          }(),
        ),
    ];
    return out..sort((a, b) => a.litersPer100Km.compareTo(b.litersPer100Km));
  }

  /// Stations ranked by the consumption of the fuel bought there (best first).
  List<ConsumptionStat> get stations => _rank((s) => s.station);
  List<ConsumptionStat> get fuelTypes => _rank((s) => s.fuelType ?? '');

  CarExpenseItem? get lastOilChange {
    final oil = car.expenses.where((e) => e.categorySyncId == oilCategorySyncId).toList()
      ..sort((a, b) => b.transaction.date.compareTo(a.transaction.date));
    return oil.isEmpty ? null : oil.first;
  }

  MaintenanceStatus get oil {
    final last = lastOilChange;
    if (last == null) return const MaintenanceStatus(kind: MaintenanceKind.oil, level: MaintenanceLevel.unknown);
    final c = car.car;
    final d = last.transaction.date;
    final dueDate = DateTime(d.year, d.month + c.oilIntervalMonths, d.day);
    final remainingDays = _days(dueDate);
    int? dueKm, remainingKm;
    double progress = 1 - remainingDays / (dueDate.difference(d).inDays.clamp(1, 100000));
    if (last.expense.odometer != null) {
      dueKm = last.expense.odometer! + c.oilIntervalKm;
      remainingKm = dueKm - (lastOdometer ?? last.expense.odometer!);
      final kmProgress = 1 - remainingKm / c.oilIntervalKm;
      if (kmProgress > progress) progress = kmProgress;
    }
    final overdue = remainingDays < 0 || (remainingKm != null && remainingKm <= 0);
    final soon = remainingDays <= 14 || (remainingKm != null && remainingKm <= 1000);
    return MaintenanceStatus(
      kind: MaintenanceKind.oil,
      level: overdue ? MaintenanceLevel.overdue : (soon ? MaintenanceLevel.soon : MaintenanceLevel.ok),
      dueDate: dueDate,
      dueKm: dueKm,
      remainingKm: remainingKm,
      remainingDays: remainingDays,
      progress: progress.clamp(0, 1).toDouble(),
    );
  }

  MaintenanceStatus _expiry(MaintenanceKind kind, DateTime? date) {
    if (date == null) return MaintenanceStatus(kind: kind, level: MaintenanceLevel.unknown);
    final days = _days(date);
    return MaintenanceStatus(
      kind: kind,
      level: days < 0 ? MaintenanceLevel.overdue : (days <= 30 ? MaintenanceLevel.soon : MaintenanceLevel.ok),
      dueDate: date,
      remainingDays: days,
    );
  }

  MaintenanceStatus get license => _expiry(MaintenanceKind.license, car.car.licenseExpiry);
  MaintenanceStatus get insurance => _expiry(MaintenanceKind.insurance, car.car.insuranceExpiry);
  List<MaintenanceStatus> get maintenance => [oil, license, insurance];

  int _days(DateTime d) => DateTime(d.year, d.month, d.day).difference(DateTime(now.year, now.month, now.day)).inDays;
}
