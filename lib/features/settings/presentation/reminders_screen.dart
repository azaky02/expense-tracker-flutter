import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/settings/settings_provider.dart';
import '../../../core/widgets/ds_widgets.dart';
import '../../installments/data/installment_reminders.dart';
import '../data/general_reminders.dart';

/// Daily "record your expenses" reminder (up to 3 times a day) and the salary day.
class RemindersScreen extends ConsumerWidget {
  const RemindersScreen({super.key});

  String _label(BuildContext context, String hhmm) {
    final t = parseTime(hhmm);
    if (t == null) return 'reminders.off'.tr();
    return TimeOfDay(hour: t.$1, minute: t.$2).format(context);
  }

  Future<void> _pickTime(BuildContext context, WidgetRef ref, int index) async {
    final s = ref.read(settingsProvider);
    final current = parseTime(s.reminderTimes.length > index ? s.reminderTimes[index] : '') ?? (9 + index * 6, 0);
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: current.$1, minute: current.$2),
    );
    if (picked == null) return;
    final times = [...s.reminderTimes];
    while (times.length < 3) {
      times.add('');
    }
    times[index] = '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
    await ref.read(settingsProvider.notifier).setReminderTimes(times);
  }

  Future<void> _clearTime(WidgetRef ref, int index) async {
    final times = [...ref.read(settingsProvider).reminderTimes];
    if (index < times.length) times[index] = '';
    await ref.read(settingsProvider.notifier).setReminderTimes(times);
  }

  Future<void> _pickSalaryDay(BuildContext context, WidgetRef ref, int current) async {
    final day = await showModalBottomSheet<int>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('reminders.salaryDay'.tr(), style: Theme.of(ctx).textTheme.titleMedium),
              const SizedBox(height: 12),
              GridView.count(
                crossAxisCount: 7,
                shrinkWrap: true,
                mainAxisSpacing: 6,
                crossAxisSpacing: 6,
                children: [
                  for (var d = 1; d <= 31; d++)
                    ChoiceChip(
                      padding: EdgeInsets.zero,
                      labelPadding: EdgeInsets.zero,
                      showCheckmark: false,
                      label: SizedBox(width: 32, child: Text('$d', textAlign: TextAlign.center)),
                      selected: d == current,
                      onSelected: (_) => Navigator.pop(ctx, d),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              TextButton(onPressed: () => Navigator.pop(ctx, 0), child: Text('reminders.noSalaryDay'.tr())),
            ],
          ),
        ),
      ),
    );
    if (day != null) await ref.read(settingsProvider.notifier).setSalaryDay(day);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(settingsProvider);
    final theme = Theme.of(context);
    final times = [...s.reminderTimes];
    while (times.length < 3) {
      times.add('');
    }
    return Scaffold(
      appBar: AppBar(title: Text('reminders.title'.tr())),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
        children: [
          SectionHeader('reminders.daily'.tr()),
          AppCard(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              children: [
                SwitchListTile(
                  value: s.dailyReminder,
                  onChanged: (v) async {
                    await ref.read(settingsProvider.notifier).setDailyReminder(v);
                    if (v) await InstallmentReminders.instance.requestPermission();
                  },
                  secondary: const Icon(Icons.alarm),
                  title: Text('reminders.dailyToggle'.tr()),
                  subtitle: Text('reminders.dailyHint'.tr()),
                ),
                if (s.dailyReminder)
                  for (var i = 0; i < 3; i++) ...[
                    const Divider(height: 1, indent: 56),
                    ListTile(
                      leading: CircleAvatar(radius: 14, child: Text('${i + 1}', style: theme.textTheme.labelMedium)),
                      title: Text('reminders.time'.tr(namedArgs: {'n': '${i + 1}'})),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(_label(context, times[i]), style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.primary)),
                          if (parseTime(times[i]) != null)
                            IconButton(
                              tooltip: 'reminders.off'.tr(),
                              icon: const Icon(Icons.close, size: 18),
                              onPressed: () => _clearTime(ref, i),
                            ),
                        ],
                      ),
                      onTap: () => _pickTime(context, ref, i),
                    ),
                  ],
              ],
            ),
          ),
          SectionHeader('reminders.salaryDay'.tr()),
          AppCard(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: ListTile(
              leading: const Icon(Icons.payments_outlined),
              title: Text('reminders.salaryDay'.tr()),
              subtitle: Text('reminders.salaryHint'.tr()),
              trailing: Text(
                s.salaryDay == 0 ? 'reminders.notSet'.tr() : 'installments.dayOfMonth'.tr(namedArgs: {'day': '${s.salaryDay}'}),
                style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.primary),
              ),
              onTap: () => _pickSalaryDay(context, ref, s.salaryDay),
            ),
          ),
        ],
      ),
    );
  }
}
