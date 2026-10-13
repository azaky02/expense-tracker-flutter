import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../installments/data/installment_reminders.dart';
import 'car_analytics.dart';
import 'car_repository.dart';

const _idBase = 7200;
const _perCar = 10;
const _maxCars = 10;

DateTime _noon(DateTime d) => DateTime(d.year, d.month, d.day, 12);

/// Oil change (by date and by km), licence and insurance reminders for every car.
Future<void> rescheduleCarReminders(List<CarWithStats> cars) async {
  final n = InstallmentReminders.instance;
  await n.cancelIds([for (var i = 0; i < _perCar * _maxCars; i++) _idBase + i]);
  final prefs = await SharedPreferences.getInstance();
  for (var ci = 0; ci < cars.length && ci < _maxCars; ci++) {
    final c = cars[ci];
    final a = CarAnalytics(c);
    final base = _idBase + ci * _perCar;
    final name = c.car.name;

    final oil = a.oil;
    if (oil.dueDate != null) {
      await n.scheduleAt(
        id: base,
        when: _noon(oil.dueDate!.subtract(const Duration(days: 7))),
        title: 'carAlerts.oilTitle'.tr(namedArgs: {'car': name}),
        body: 'carAlerts.oilWeek'.tr(namedArgs: {'car': name}),
      );
      await n.scheduleAt(
        id: base + 1,
        when: _noon(oil.dueDate!),
        title: 'carAlerts.oilTitle'.tr(namedArgs: {'car': name}),
        body: 'carAlerts.oilToday'.tr(namedArgs: {'car': name}),
      );
    }
    // Km-based: tell once per oil change when fewer than 1,000 km are left.
    if (oil.remainingKm != null && oil.remainingKm! <= 1000 && oil.dueKm != null) {
      final flag = 'carAlert.${c.car.id}.oilKm.${oil.dueKm}';
      if (!(prefs.getBool(flag) ?? false)) {
        await n.showNow(
          id: base + 2,
          title: 'carAlerts.oilTitle'.tr(namedArgs: {'car': name}),
          body: (oil.remainingKm! <= 0 ? 'carAlerts.oilKmOver' : 'carAlerts.oilKmSoon').tr(
            namedArgs: {'car': name, 'km': '${oil.remainingKm!.abs()}'},
          ),
        );
        await prefs.setBool(flag, true);
      }
    }
    for (final (offset, status, key) in [(3, a.license, 'license'), (6, a.insurance, 'insurance')]) {
      final due = status.dueDate;
      if (due == null) continue;
      for (final (i, days) in [(0, 30), (1, 7), (2, 0)]) {
        await n.scheduleAt(
          id: base + offset + i,
          when: _noon(due.subtract(Duration(days: days))),
          title: 'carAlerts.${key}Title'.tr(namedArgs: {'car': name}),
          body: (days == 0 ? 'carAlerts.expiresToday' : 'carAlerts.expiresIn').tr(namedArgs: {'car': name, 'days': '$days'}),
        );
      }
    }
  }
}

/// Keeps car reminders in step with the cars and their expenses (watched by the app root).
final carRemindersProvider = Provider<void>((ref) {
  ref.listen(carsProvider, (_, next) {
    final cars = next.value;
    if (cars != null) rescheduleCarReminders(cars);
  }, fireImmediately: true);
});
