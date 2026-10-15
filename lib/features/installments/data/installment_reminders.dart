import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../../../core/settings/settings_provider.dart';
import '../../../core/settings/settings_state.dart';
import '../../../core/utils/currency.dart';
import 'installment_repository.dart';

/// Reminder rule: from 5 days before an installment's due date until the due day itself, twice a
/// day at 12:00 and 22:00, while it is unpaid.
const reminderDaysBefore = 5;
const reminderHours = [12, 22];

/// iOS keeps at most 64 pending local notifications per app; stay below that.
const _maxScheduled = 60;
const _idBase = 7100;

class ReminderSlot {
  const ReminderSlot(this.when, this.item, this.due);
  final DateTime when;
  final InstallmentWithSchedule item;
  final InstallmentDue due;
}

/// The next reminder times for every unpaid installment (pure, for tests).
List<ReminderSlot> upcomingReminderSlots(List<InstallmentWithSchedule> plans, DateTime now, {int limit = _maxScheduled}) {
  final slots = <ReminderSlot>[];
  for (final item in plans) {
    if (!item.plan.remindersEnabled) continue;
    // The next two unpaid installments are enough: the list is rebuilt every time the app opens.
    final unpaid = item.schedule.where((d) => !d.isPaid && !d.dueDate.isBefore(DateTime(now.year, now.month, now.day))).take(2);
    for (final due in unpaid) {
      for (var back = reminderDaysBefore; back >= 0; back--) {
        final day = DateTime(due.dueDate.year, due.dueDate.month, due.dueDate.day - back);
        for (final h in reminderHours) {
          final when = DateTime(day.year, day.month, day.day, h);
          if (when.isAfter(now)) slots.add(ReminderSlot(when, item, due));
        }
      }
    }
  }
  slots.sort((a, b) => a.when.compareTo(b.when));
  return slots.take(limit).toList();
}

class InstallmentReminders {
  InstallmentReminders._();
  static final instance = InstallmentReminders._();

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  bool get _supported => !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  Future<void> _init() async {
    if (_ready) return;
    tzdata.initializeTimeZones();
    try {
      final info = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(info.identifier));
    } catch (_) {
      tz.setLocalLocation(tz.getLocation('Africa/Cairo'));
    }
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(requestAlertPermission: false, requestBadgePermission: false, requestSoundPermission: false),
      ),
    );
    _ready = true;
  }

  /// Asks for notification permission (Android 13+ / iOS). Safe to call repeatedly.
  Future<void> requestPermission() async {
    if (!_supported) return;
    try {
      await _init();
      await _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()?.requestNotificationsPermission();
      await _plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()?.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
    } catch (e) {
      debugPrint('notification permission: $e');
    }
  }

  static const _carDetails = NotificationDetails(
    android: AndroidNotificationDetails(
      'car',
      'Car reminders',
      channelDescription: 'Oil change, licence and insurance reminders',
      importance: Importance.high,
      priority: Priority.high,
    ),
    iOS: DarwinNotificationDetails(),
  );

  /// One-off reminder at [when] (ignored if it is in the past). Used by the car reminders.
  Future<void> scheduleAt({required int id, required DateTime when, required String title, required String body}) async {
    if (!_supported || !when.isAfter(DateTime.now())) return;
    try {
      await _init();
      await _plugin.zonedSchedule(
        id: id,
        scheduledDate: tz.TZDateTime.from(when, tz.local),
        notificationDetails: _carDetails,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        title: title,
        body: body,
      );
    } catch (e) {
      debugPrint('schedule reminder: $e');
    }
  }

  /// Repeats every day at [hour]:[minute].
  Future<void> scheduleDaily({required int id, required int hour, required int minute, required String title, required String body}) async {
    if (!_supported) return;
    try {
      await _init();
      final now = tz.TZDateTime.now(tz.local);
      var first = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
      if (!first.isAfter(now)) first = first.add(const Duration(days: 1));
      await _plugin.zonedSchedule(
        id: id,
        scheduledDate: first,
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails('daily', 'Daily reminder', channelDescription: 'Reminder to record the expenses of the day'),
          iOS: DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
        title: title,
        body: body,
      );
    } catch (e) {
      debugPrint('daily reminder: $e');
    }
  }

  Future<void> showNow({required int id, required String title, required String body}) async {
    if (!_supported) return;
    try {
      await _init();
      await _plugin.show(id: id, title: title, body: body, notificationDetails: _carDetails);
    } catch (e) {
      debugPrint('show reminder: $e');
    }
  }

  Future<void> cancelIds(Iterable<int> ids) async {
    if (!_supported) return;
    try {
      await _init();
      for (final id in ids) {
        await _plugin.cancel(id: id);
      }
    } catch (e) {
      debugPrint('cancel reminders: $e');
    }
  }

  /// Cancels the previous reminders and schedules the current ones.
  Future<void> reschedule(List<InstallmentWithSchedule> plans) async {
    if (!_supported) return;
    try {
      await _init();
      for (var i = 0; i < _maxScheduled; i++) {
        await _plugin.cancel(id: _idBase + i);
      }
      final slots = upcomingReminderSlots(plans, DateTime.now());
      const details = NotificationDetails(
        android: AndroidNotificationDetails(
          'installments',
          'Installment reminders',
          channelDescription: 'Reminders before an installment is due',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      );
      for (var i = 0; i < slots.length; i++) {
        final s = slots[i];
        final daysLeft = DateTime(
          s.due.dueDate.year,
          s.due.dueDate.month,
          s.due.dueDate.day,
        ).difference(DateTime(s.when.year, s.when.month, s.when.day)).inDays;
        final amount = s.item.plan.installmentAmount;
        await _plugin.zonedSchedule(
          id: _idBase + i,
          scheduledDate: tz.TZDateTime.from(s.when, tz.local),
          notificationDetails: details,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          title: 'installments.reminderTitle'.tr(namedArgs: {'title': s.item.plan.title}),
          body: (daysLeft == 0 ? 'installments.reminderToday' : 'installments.reminderBody').tr(
            namedArgs: {
              'amount': formatAmount(amount),
              'provider': s.item.plan.provider,
              'days': '$daysLeft',
              'date': DateFormat.yMMMd('ar').format(s.due.dueDate),
              'number': '${s.due.number}/${s.item.plan.months}',
            },
          ),
        );
      }
    } catch (e) {
      debugPrint('installment reminders: $e');
    }
  }
}

/// Keeps the scheduled reminders in step with the installments (watched by the app root).
final installmentRemindersProvider = Provider<void>((ref) {
  void run() {
    final plans = ref.read(installmentsProvider).value;
    if (plans == null) return;
    InstallmentReminders.instance.reschedule(ref.read(settingsProvider).moduleEnabled(AppModule.installments.key) ? plans : const []);
  }

  ref.listen(installmentsProvider, (_, _) => run(), fireImmediately: true);
  ref.listen(settingsProvider.select((s) => s.moduleEnabled(AppModule.installments.key)), (_, _) => run());
});
