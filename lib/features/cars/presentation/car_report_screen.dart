import 'package:easy_localization/easy_localization.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/ds_tokens.dart';
import '../../../core/utils/currency.dart';
import '../../../core/widgets/ds_widgets.dart';
import '../data/car_analytics.dart';
import '../data/car_repository.dart';

String _n1(double v) => NumberFormat('#,##0.0', 'en').format(v);
String _km(int v) => NumberFormat.decimalPattern('en').format(v);

Color maintenanceColor(BuildContext context, MaintenanceLevel l) => switch (l) {
  MaintenanceLevel.overdue => Theme.of(context).colorScheme.error,
  MaintenanceLevel.soon => DS.warning,
  MaintenanceLevel.ok => DS.success,
  MaintenanceLevel.unknown => Theme.of(context).colorScheme.onSurfaceVariant,
};

IconData _maintenanceIcon(MaintenanceKind k) => switch (k) {
  MaintenanceKind.oil => Icons.oil_barrel_outlined,
  MaintenanceKind.license => Icons.badge_outlined,
  MaintenanceKind.insurance => Icons.shield_outlined,
};

/// One-line status, e.g. "تغيير الزيت بعد 800 كم أو 12 يوم".
String maintenanceText(MaintenanceStatus m) {
  final title = 'carMaint.${m.kind.name}'.tr();
  if (m.level == MaintenanceLevel.unknown) {
    return m.kind == MaintenanceKind.oil ? 'carMaint.oilUnknown'.tr() : 'carMaint.noDate'.tr(namedArgs: {'title': title});
  }
  final parts = <String>[];
  if (m.remainingKm != null) {
    parts.add(
      m.remainingKm! <= 0
          ? 'carMaint.kmOver'.tr(namedArgs: {'km': _km(-m.remainingKm!)})
          : 'carMaint.kmLeft'.tr(namedArgs: {'km': _km(m.remainingKm!)}),
    );
  }
  if (m.remainingDays != null) {
    parts.add(
      m.remainingDays! < 0
          ? 'carMaint.daysOver'.tr(namedArgs: {'days': '${-m.remainingDays!}'})
          : 'carMaint.daysLeft'.tr(namedArgs: {'days': '${m.remainingDays}'}),
    );
  }
  return '$title: ${parts.join(' · ')}';
}

class MaintenancePill extends StatelessWidget {
  const MaintenancePill(this.m, {super.key});
  final MaintenanceStatus m;

  @override
  Widget build(BuildContext context) =>
      StatusPill(maintenanceText(m), color: maintenanceColor(context, m.level), icon: _maintenanceIcon(m.kind));
}

/// Maintenance status with a progress bar for the oil interval.
class MaintenanceCard extends StatelessWidget {
  const MaintenanceCard(this.m, {super.key});
  final MaintenanceStatus m;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = maintenanceColor(context, m.level);
    final lang = context.locale.languageCode;
    return AppCard(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconBubble(icon: _maintenanceIcon(m.kind), color: color, size: 36),
              const SizedBox(width: 10),
              Expanded(
                child: Text(maintenanceText(m), style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          if (m.dueDate != null || m.dueKm != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                [
                  if (m.dueKm != null) 'carMaint.atKm'.tr(namedArgs: {'km': _km(m.dueKm!)}),
                  if (m.dueDate != null) 'carMaint.onDate'.tr(namedArgs: {'date': DateFormat.yMMMd(lang).format(m.dueDate!)}),
                ].join(' · '),
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ),
          if (m.progress != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: m.progress,
                  minHeight: 7,
                  color: color,
                  backgroundColor: color.withValues(alpha: 0.15),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Detailed car report: costs, consumption, best station / fuel, monthly spending, fill-up log,
/// maintenance and insights.
class CarReportScreen extends ConsumerWidget {
  const CarReportScreen({super.key, required this.carId});
  final int carId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cars = ref.watch(carsProvider).value ?? const <CarWithStats>[];
    final c = cars.where((x) => x.car.id == carId).firstOrNull;
    if (c == null) return Scaffold(appBar: AppBar(), body: const SizedBox());
    final a = CarAnalytics(c);
    final theme = Theme.of(context);
    final egp = 'common.egp'.tr();

    Widget kpi(String label, String value, {Color? color, IconData? icon}) => Expanded(
      child: AppCard(
        margin: const EdgeInsets.all(4),
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (icon != null) Icon(icon, size: 16, color: theme.colorScheme.onSurfaceVariant),
                if (icon != null) const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800, color: color),
            ),
          ],
        ),
      ),
    );
    String money(double? v) => v == null ? '—' : '${formatAmount(double.parse(v.toStringAsFixed(2)))} $egp';

    final insights = _insights(a);

    return Scaffold(
      appBar: AppBar(title: Text('carReport.titleFor'.tr(namedArgs: {'car': c.car.name}))),
      body: c.expenses.isEmpty
          ? EmptyState(icon: Icons.analytics_outlined, title: 'carReport.empty'.tr(), message: 'carReport.emptyHint'.tr())
          : ListView(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 32),
              children: [
                Row(
                  children: [
                    kpi('cars.totalSpent'.tr(), money(a.totalSpent), icon: Icons.payments_outlined),
                    kpi(
                      'carReport.kmDriven'.tr(),
                      a.kmDriven == null ? '—' : '${_km(a.kmDriven!)} ${'cars.km'.tr()}',
                      icon: Icons.route_outlined,
                    ),
                  ],
                ),
                Row(
                  children: [
                    kpi(
                      'carReport.avgConsumption'.tr(),
                      a.avgLitersPer100Km == null ? '—' : 'cars.per100'.tr(namedArgs: {'l': _n1(a.avgLitersPer100Km!)}),
                      icon: Icons.local_gas_station_outlined,
                      color: DS.primary,
                    ),
                    kpi(
                      'carReport.kmPerLiter'.tr(),
                      a.kmPerLiter == null ? '—' : 'carReport.kmPerLiterValue'.tr(namedArgs: {'v': _n1(a.kmPerLiter!)}),
                      icon: Icons.speed,
                    ),
                  ],
                ),
                Row(
                  children: [
                    kpi('carReport.costPerKm'.tr(), money(a.costPerKm), icon: Icons.price_change_outlined),
                    kpi('carReport.fuelCostPerKm'.tr(), money(a.fuelCostPerKm), icon: Icons.ev_station_outlined),
                  ],
                ),
                Row(
                  children: [
                    kpi('carReport.avgPrice'.tr(), money(a.avgPricePerLiter), icon: Icons.sell_outlined),
                    kpi('carReport.monthlyAvg'.tr(), money(a.avgMonthlySpend), icon: Icons.calendar_month_outlined),
                  ],
                ),
                Row(
                  children: [
                    kpi('cars.totalLiters'.tr(), '${_n1(a.totalLiters)} ${'cars.litersUnit'.tr()}', icon: Icons.water_drop_outlined),
                    kpi(
                      'carReport.kmPerMonth'.tr(),
                      a.avgKmPerMonth == null ? '—' : '${_km(a.avgKmPerMonth!.round())} ${'cars.km'.tr()}',
                      icon: Icons.timeline,
                    ),
                  ],
                ),
                if (insights.isNotEmpty) ...[
                  SectionHeader('carReport.insights'.tr()),
                  AppCard(
                    color: theme.colorScheme.primaryContainer,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final i in insights)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('💡 '),
                                Expanded(child: Text(i, style: theme.textTheme.bodyMedium)),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
                SectionHeader('carReport.maintenance'.tr()),
                for (final m in a.maintenance) MaintenanceCard(m),
                SectionHeader('carReport.monthly'.tr()),
                AppCard(child: _MonthlyBars(a.monthly())),
                if (a.segments.length >= 2) ...[SectionHeader('carReport.trend'.tr()), AppCard(child: _ConsumptionLine(a))],
                if (a.stations.isNotEmpty) ...[SectionHeader('carReport.bestStations'.tr()), _RankCard(stats: a.stations)],
                if (a.fuelTypes.length > 1) ...[SectionHeader('carReport.byFuelType'.tr()), _RankCard(stats: a.fuelTypes)],
                SectionHeader('carReport.byItem'.tr()),
                AppCard(
                  child: Column(
                    children: [
                      for (final s in a.byCategory)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 5),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Text('${s.icon} ${s.name}'),
                                  const Spacer(),
                                  AmountText(s.total, size: 13),
                                  const SizedBox(width: 8),
                                  SizedBox(
                                    width: 44,
                                    child: Text(
                                      '${(s.total / a.totalSpent * 100).round()}%',
                                      textAlign: TextAlign.end,
                                      style: theme.textTheme.labelMedium,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(value: s.total / a.totalSpent, minHeight: 5),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                if (a.fills.isNotEmpty) ...[SectionHeader('carReport.fillLog'.tr()), _FillLog(a)],
              ],
            ),
    );
  }

  /// Plain-language observations from the numbers.
  List<String> _insights(CarAnalytics a) {
    final out = <String>[];
    final stations = a.stations;
    if (stations.length >= 2) {
      final best = stations.first, worst = stations.last;
      final diff = (worst.litersPer100Km - best.litersPer100Km) / worst.litersPer100Km * 100;
      out.add(
        'carReport.insightBestStation'.tr(
          namedArgs: {'best': best.name, 'l': _n1(best.litersPer100Km), 'worst': worst.name, 'p': _n1(diff)},
        ),
      );
    } else if (stations.length == 1) {
      out.add('carReport.insightOneStation'.tr(namedArgs: {'name': stations.first.name}));
    }
    final last = a.lastVsAveragePercent;
    if (last != null && last.abs() >= 5) {
      out.add((last > 0 ? 'carReport.insightLastWorse' : 'carReport.insightLastBetter').tr(namedArgs: {'p': _n1(last.abs())}));
    }
    if (a.totalSpent > 0 && a.fuelSpent > 0) {
      out.add('carReport.insightFuelShare'.tr(namedArgs: {'p': '${(a.fuelSpent / a.totalSpent * 100).round()}'}));
    }
    final types = a.fuelTypes;
    if (types.length >= 2) {
      out.add('carReport.insightFuelType'.tr(namedArgs: {'name': types.first.name, 'l': _n1(types.first.litersPer100Km)}));
    }
    final oil = a.oil;
    if (oil.needsAttention) out.add(maintenanceText(oil));
    if (a.segments.isEmpty && a.fills.isNotEmpty) out.add('carReport.insightNeedTwoFills'.tr());
    if (a.fills.isEmpty) out.add('carReport.insightNoFills'.tr());
    return out;
  }
}

class _MonthlyBars extends StatelessWidget {
  const _MonthlyBars(this.data);
  final List<(DateTime, double, double)> data;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final maxY = data.fold<double>(0, (m, d) => d.$2 + d.$3 > m ? d.$2 + d.$3 : m);
    const fuelColor = DS.primary;
    const otherColor = DS.warning;
    return Column(
      children: [
        SizedBox(
          height: 180,
          child: BarChart(
            BarChartData(
              maxY: maxY == 0 ? 1 : maxY * 1.15,
              gridData: const FlGridData(show: false),
              borderData: FlBorderData(show: false),
              barTouchData: BarTouchData(
                touchTooltipData: BarTouchTooltipData(
                  getTooltipItem: (group, _, rod, _) =>
                      BarTooltipItem(formatAmount(rod.toY.roundToDouble()), const TextStyle(color: Colors.white, fontSize: 12)),
                ),
              ),
              titlesData: FlTitlesData(
                leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (v, _) {
                      final i = v.toInt();
                      if (i < 0 || i >= data.length || i.isOdd != (data.length - 1).isOdd) return const SizedBox.shrink();
                      return Text(DateFormat.MMM(context.locale.languageCode).format(data[i].$1), style: const TextStyle(fontSize: 9));
                    },
                  ),
                ),
              ),
              barGroups: [
                for (var i = 0; i < data.length; i++)
                  BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(
                        toY: data[i].$2 + data[i].$3,
                        width: 12,
                        borderRadius: BorderRadius.circular(3),
                        color: scheme.surfaceContainerHighest,
                        rodStackItems: [
                          BarChartRodStackItem(0, data[i].$2, fuelColor),
                          BarChartRodStackItem(data[i].$2, data[i].$2 + data[i].$3, otherColor),
                        ],
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _legend(fuelColor, 'carReport.fuel'.tr()),
            const SizedBox(width: 16),
            _legend(otherColor, 'carReport.otherCosts'.tr()),
          ],
        ),
      ],
    );
  }

  Widget _legend(Color c, String label) => Row(
    children: [
      Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(3)),
      ),
      const SizedBox(width: 4),
      Text(label, style: const TextStyle(fontSize: 12)),
    ],
  );
}

class _ConsumptionLine extends StatelessWidget {
  const _ConsumptionLine(this.a);
  final CarAnalytics a;

  @override
  Widget build(BuildContext context) {
    final seg = a.segments;
    final avg = a.avgLitersPer100Km!;
    final values = seg.map((s) => s.litersPer100Km).toList();
    final minY = values.reduce((x, y) => x < y ? x : y);
    final maxY = values.reduce((x, y) => x > y ? x : y);
    final pad = ((maxY - minY) * 0.3).clamp(0.5, 5.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 170,
          child: Directionality(
            textDirection: Directionality.of(context),
            child: LineChart(
              LineChartData(
                minY: (minY - pad).clamp(0, double.infinity).toDouble(),
                maxY: maxY + pad,
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 32,
                      getTitlesWidget: (v, _) => Text(v.toStringAsFixed(1), style: const TextStyle(fontSize: 9)),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: 1,
                      getTitlesWidget: (v, _) {
                        final i = v.toInt();
                        if (i < 0 || i >= seg.length || v != i.toDouble()) return const SizedBox.shrink();
                        return Text(DateFormat.Md('en').format(seg[i].to.transaction.date), style: const TextStyle(fontSize: 9));
                      },
                    ),
                  ),
                ),
                extraLinesData: ExtraLinesData(
                  horizontalLines: [
                    HorizontalLine(y: avg, color: DS.warning, strokeWidth: 1, dashArray: [4, 4]),
                  ],
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: [for (var i = 0; i < seg.length; i++) FlSpot(i.toDouble(), seg[i].litersPer100Km)],
                    isCurved: true,
                    color: DS.primary,
                    barWidth: 3,
                    dotData: const FlDotData(show: true),
                    belowBarData: BarAreaData(show: true, color: DS.primary.withValues(alpha: 0.08)),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text('carReport.trendHint'.tr(namedArgs: {'avg': _n1(avg)}), style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class _RankCard extends StatelessWidget {
  const _RankCard({required this.stats});
  final List<ConsumptionStat> stats;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        children: [
          for (var i = 0; i < stats.length; i++)
            ListTile(
              dense: true,
              leading: CircleAvatar(
                radius: 15,
                backgroundColor: i == 0 ? DS.success.withValues(alpha: 0.15) : theme.colorScheme.surfaceContainerHighest,
                child: i == 0 ? const Text('🏆') : Text('${i + 1}', style: theme.textTheme.labelMedium),
              ),
              title: Text(stats[i].name, style: theme.textTheme.titleSmall),
              subtitle: Text(
                [
                  'carReport.measured'.tr(namedArgs: {'n': '${stats[i].segments}'}),
                  if (stats[i].avgPricePerLiter != null) '${formatAmount(stats[i].avgPricePerLiter!)} ${'fuel.perLiter'.tr()}',
                ].join(' · '),
              ),
              trailing: Text(
                'cars.per100'.tr(namedArgs: {'l': _n1(stats[i].litersPer100Km)}),
                style: theme.textTheme.titleSmall?.copyWith(color: i == 0 ? DS.success : null, fontWeight: FontWeight.w700),
              ),
            ),
        ],
      ),
    );
  }
}

class _FillLog extends StatelessWidget {
  const _FillLog(this.a);
  final CarAnalytics a;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final lang = context.locale.languageCode;
    final bySegmentEnd = {for (final s in a.segments) s.to.expense.id: s};
    final avg = a.avgLitersPer100Km;
    return AppCard(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        children: [
          for (final f in a.fills.reversed)
            () {
              final s = bySegmentEnd[f.expense.id];
              final worse = s != null && avg != null && s.litersPer100Km > avg * 1.05;
              return ListTile(
                dense: true,
                title: Text(
                  '${DateFormat.yMMMd(lang).format(f.transaction.date)} · ${_km(f.expense.odometer!)} ${'cars.km'.tr()}',
                  style: theme.textTheme.bodyMedium,
                ),
                subtitle: Text(
                  [
                    'cars.litersValue'.tr(namedArgs: {'l': _n1(f.expense.liters!)}),
                    '${formatAmount(f.transaction.amount)} ${'common.egp'.tr()}',
                    if (stationName(f).isNotEmpty) stationName(f),
                    if (s != null) 'carReport.since'.tr(namedArgs: {'km': _km(s.km)}),
                  ].join(' · '),
                ),
                trailing: s == null
                    ? Text('—', style: theme.textTheme.bodySmall)
                    : Text(
                        'cars.per100'.tr(namedArgs: {'l': _n1(s.litersPer100Km)}),
                        style: theme.textTheme.labelLarge?.copyWith(color: worse ? theme.colorScheme.error : DS.success),
                      ),
              );
            }(),
        ],
      ),
    );
  }
}
