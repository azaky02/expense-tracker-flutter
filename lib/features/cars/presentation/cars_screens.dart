import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/db/database.dart';
import '../../../core/db/database_provider.dart';
import '../../../core/db/seed.dart';
import '../../../core/db/tables.dart';
import '../../../core/security/lock_provider.dart';
import '../../../core/theme/ds_tokens.dart';
import '../../../core/utils/currency.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/widgets/ds_widgets.dart';
import '../../accounts/data/account_repository.dart';
import '../../accounts/presentation/account_providers.dart';
import '../../accounts/presentation/account_widgets.dart';
import '../../categories/data/category_repository.dart';
import '../../categories/presentation/category_picker_sheet.dart';
import '../../categories/presentation/category_providers.dart';
import '../data/car_analytics.dart';
import '../data/car_repository.dart';
import 'car_report_screen.dart';

double _parse(String s) => parseAmount(s);

Future<void> openMap(double lat, double lng) =>
    LockNotifier.runWithoutLock(() => launchUrl(Uri.parse('https://maps.google.com/?q=$lat,$lng'), mode: LaunchMode.externalApplication));

/// "Main › Sub" for a category id.
final categoryPathProvider = FutureProvider.family<String, int>((ref, id) async {
  final db = ref.watch(databaseProvider);
  final c = await (db.select(db.categories)..where((x) => x.id.equals(id))).getSingleOrNull();
  if (c == null) return '';
  if (c.parentCategoryId == null) return '${c.icon} ${c.name}';
  final p = await (db.select(db.categories)..where((x) => x.id.equals(c.parentCategoryId!))).getSingleOrNull();
  return '${c.icon} ${p?.name ?? ''} › ${c.name}';
});

/// My cars.
class CarsScreen extends ConsumerWidget {
  const CarsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(carsProvider);
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text('cars.title'.tr()),
        actions: [
          IconButton(
            tooltip: 'fuel.title'.tr(),
            onPressed: () => context.push('/fuel-prices'),
            icon: const Icon(Icons.local_gas_station_outlined),
          ),
          IconButton(tooltip: 'cars.add'.tr(), onPressed: () => showCarForm(context, ref), icon: const Icon(Icons.add_circle_outline)),
        ],
      ),
      floatingActionButton: (async.value ?? const []).isEmpty
          ? null
          : FloatingActionButton.extended(
              shape: const StadiumBorder(),
              onPressed: () => startCarExpense(context, ref),
              icon: const Icon(Icons.add),
              label: Text('cars.addExpense'.tr()),
            ),
      body: async.when(
        loading: () => const SkeletonList(),
        error: (e, _) => ErrorState(message: 'common.loadError'.tr(), onRetry: () => ref.invalidate(carsProvider)),
        data: (cars) => cars.isEmpty
            ? EmptyState(
                icon: Icons.directions_car_outlined,
                title: 'cars.emptyTitle'.tr(),
                message: 'cars.emptyMessage'.tr(),
                actionLabel: 'cars.add'.tr(),
                onAction: () => showCarForm(context, ref),
              )
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                children: [
                  for (final c in cars)
                    AppCard(
                      margin: const EdgeInsets.only(bottom: 10),
                      onTap: () => context.push('/cars/${c.car.id}'),
                      child: Row(
                        children: [
                          const IconBubble(icon: Icons.directions_car_filled_outlined, color: DS.primary, size: 48),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(c.car.name, style: theme.textTheme.titleSmall),
                                Text(
                                  '${c.car.brand} · ${c.car.modelYear}',
                                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                                ),
                                if (c.lastOdometer != null)
                                  Text(
                                    'cars.odometerValue'.tr(namedArgs: {'km': NumberFormat.decimalPattern().format(c.lastOdometer)}),
                                    style: theme.textTheme.bodySmall,
                                  ),
                                for (final m in CarAnalytics(c).maintenance.where((m) => m.needsAttention))
                                  Padding(padding: const EdgeInsets.only(top: 4), child: MaintenancePill(m)),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              AmountText(c.total, size: 15),
                              Text('cars.expensesCount'.tr(namedArgs: {'n': '${c.expenses.length}'}), style: theme.textTheme.labelSmall),
                            ],
                          ),
                        ],
                      ),
                    ),
                ],
              ),
      ),
    );
  }
}

/// "Add expense" from the cars list: pick the car first (skipped when there is only one).
Future<void> startCarExpense(BuildContext context, WidgetRef ref) async {
  final cars = ref.read(carsProvider).value ?? const <CarWithStats>[];
  if (cars.isEmpty) return showCarForm(context, ref);
  int? id = cars.length == 1 ? cars.single.car.id : null;
  id ??= await showModalBottomSheet<int>(
    context: context,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text('cars.chooseCar'.tr(), style: Theme.of(ctx).textTheme.titleMedium),
          ),
          for (final c in cars)
            ListTile(
              leading: const Icon(Icons.directions_car_filled_outlined),
              title: Text(c.car.name),
              subtitle: Text('${c.car.brand} · ${c.car.modelYear}'),
              onTap: () => Navigator.pop(ctx, c.car.id),
            ),
        ],
      ),
    ),
  );
  if (id != null && context.mounted) await context.push('/cars/$id/expense');
}

Future<void> showCarForm(BuildContext context, WidgetRef ref, {Car? car}) async {
  final name = TextEditingController(text: car?.name);
  final brand = TextEditingController(text: car?.brand);
  final year = TextEditingController(text: car == null ? '' : '${car.modelYear}');
  final plate = TextEditingController(text: car?.plate);
  final oilKm = TextEditingController(text: '${car?.oilIntervalKm ?? 10000}');
  final oilMonths = TextEditingController(text: '${car?.oilIntervalMonths ?? 6}');
  DateTime? license = car?.licenseExpiry;
  DateTime? insurance = car?.insuranceExpiry;
  final ok = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) {
        final y = int.tryParse(asciiDigits(year.text)) ?? 0;
        final valid = name.text.trim().isNotEmpty && brand.text.trim().isNotEmpty && y >= 1950 && y <= DateTime.now().year + 1;
        return Padding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + MediaQuery.of(ctx).viewInsets.bottom),
          child: SafeArea(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.85),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text((car == null ? 'cars.add' : 'cars.edit').tr(), style: Theme.of(ctx).textTheme.titleMedium),
                    FieldLabel('cars.name'.tr()),
                    TextField(
                      controller: name,
                      decoration: InputDecoration(hintText: 'cars.nameHint'.tr()),
                      onChanged: (_) => setState(() {}),
                    ),
                    FieldRow(
                      flex: const [5, 3],
                      [
                        (
                          'cars.brand'.tr(),
                          TextField(
                            controller: brand,
                            decoration: InputDecoration(hintText: 'cars.brandHint'.tr()),
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                        (
                          'cars.modelYear'.tr(),
                          TextField(
                            controller: year,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              const AsciiDigitsFormatter(),
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(4),
                            ],
                            decoration: const InputDecoration(hintText: '2022'),
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                      ],
                    ),
                    FieldLabel('${'cars.plate'.tr()} (${'common.optional'.tr()})'),
                    TextField(controller: plate),
                    FieldLabel('cars.oilEvery'.tr()),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: oilKm,
                            keyboardType: TextInputType.number,
                            inputFormatters: [const AsciiDigitsFormatter(), FilteringTextInputFormatter.digitsOnly],
                            decoration: InputDecoration(suffixText: 'cars.km'.tr()),
                          ),
                        ),
                        Padding(padding: const EdgeInsets.symmetric(horizontal: 8), child: Text('cars.or'.tr())),
                        Expanded(
                          child: TextField(
                            controller: oilMonths,
                            keyboardType: TextInputType.number,
                            inputFormatters: [const AsciiDigitsFormatter(), FilteringTextInputFormatter.digitsOnly],
                            decoration: InputDecoration(suffixText: 'cars.monthsUnit'.tr()),
                          ),
                        ),
                      ],
                    ),
                    FieldLabel('${'cars.licenseExpiry'.tr()} (${'common.optional'.tr()})'),
                    PickerField(
                      text: license == null ? 'cars.chooseDate'.tr() : DateFormat.yMMMd(ctx.locale.languageCode).format(license!),
                      placeholder: license == null,
                      trailingIcon: Icons.event_outlined,
                      onTap: () async {
                        final d = await showDatePicker(
                          context: ctx,
                          initialDate: license ?? DateTime.now().add(const Duration(days: 365)),
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2100),
                        );
                        if (d != null) setState(() => license = d);
                      },
                    ),
                    FieldLabel('${'cars.insuranceExpiry'.tr()} (${'common.optional'.tr()})'),
                    PickerField(
                      text: insurance == null ? 'cars.chooseDate'.tr() : DateFormat.yMMMd(ctx.locale.languageCode).format(insurance!),
                      placeholder: insurance == null,
                      trailingIcon: Icons.event_outlined,
                      onTap: () async {
                        final d = await showDatePicker(
                          context: ctx,
                          initialDate: insurance ?? DateTime.now().add(const Duration(days: 365)),
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2100),
                        );
                        if (d != null) setState(() => insurance = d);
                      },
                    ),
                    const SizedBox(height: 16),
                    FilledButton(onPressed: valid ? () => Navigator.pop(ctx, true) : null, child: Text('common.save'.tr())),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    ),
  );
  if (ok == true) {
    final repo = ref.read(carRepositoryProvider);
    final p = plate.text.trim().isEmpty ? null : plate.text.trim();
    final km = int.tryParse(asciiDigits(oilKm.text)) ?? 10000;
    final months = int.tryParse(asciiDigits(oilMonths.text)) ?? 6;
    if (car == null) {
      await repo.createCar(
        name: name.text.trim(),
        brand: brand.text.trim(),
        modelYear: int.parse(asciiDigits(year.text)),
        plate: p,
        oilIntervalKm: km > 0 ? km : 10000,
        oilIntervalMonths: months > 0 ? months : 6,
        licenseExpiry: license,
        insuranceExpiry: insurance,
      );
    } else {
      await repo.updateCar(
        car.id,
        name: name.text.trim(),
        brand: brand.text.trim(),
        modelYear: int.parse(asciiDigits(year.text)),
        plate: p,
        oilIntervalKm: km > 0 ? km : 10000,
        oilIntervalMonths: months > 0 ? months : 6,
        licenseExpiry: license,
        insuranceExpiry: insurance,
      );
    }
  }
}

/// One car: totals, consumption and its expenses.
class CarDetailsScreen extends ConsumerWidget {
  const CarDetailsScreen({super.key, required this.carId});
  final int carId;

  Future<void> _deleteCar(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('cars.deleteTitle'.tr()),
        content: Text('cars.deleteMessage'.tr()),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('common.cancel'.tr())),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Theme.of(ctx).colorScheme.error, minimumSize: const Size(88, 44)),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('common.delete'.tr()),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(carRepositoryProvider).deleteCar(carId);
    if (context.mounted) context.pop();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cars = ref.watch(carsProvider).value ?? const <CarWithStats>[];
    final c = cars.where((x) => x.car.id == carId).firstOrNull;
    final theme = Theme.of(context);
    if (c == null) return Scaffold(appBar: AppBar(), body: const SizedBox());
    final lang = context.locale.languageCode;
    return Scaffold(
      appBar: AppBar(
        title: Text(c.car.name),
        actions: [
          IconButton(
            tooltip: 'carReport.title'.tr(),
            icon: const Icon(Icons.analytics_outlined),
            onPressed: () => context.push('/cars/$carId/report'),
          ),
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => showCarForm(context, ref, car: c.car),
          ),
          IconButton(icon: const Icon(Icons.delete_outline), onPressed: () => _deleteCar(context, ref)),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        shape: const StadiumBorder(),
        onPressed: () => context.push('/cars/$carId/expense'),
        icon: const Icon(Icons.add),
        label: Text('cars.addExpense'.tr()),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
        children: [
          AppCard(
            color: theme.colorScheme.primaryContainer,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${c.car.brand} · ${c.car.modelYear}${c.car.plate == null ? '' : ' · ${c.car.plate}'}',
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _stat(context, 'cars.totalSpent'.tr(), AmountText(c.total, size: 17, weight: FontWeight.w800)),
                    _stat(
                      context,
                      'cars.totalLiters'.tr(),
                      Text(NumberFormat('#,##0.#').format(c.totalLiters), style: theme.textTheme.titleMedium),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _stat(
                      context,
                      'cars.odometer'.tr(),
                      Text(
                        c.lastOdometer == null ? '—' : NumberFormat.decimalPattern().format(c.lastOdometer),
                        style: theme.textTheme.titleMedium,
                      ),
                    ),
                    _stat(
                      context,
                      'cars.consumption'.tr(),
                      Text(
                        c.litersPer100Km == null ? '—' : 'cars.per100'.tr(namedArgs: {'l': c.litersPer100Km!.toStringAsFixed(1)}),
                        style: theme.textTheme.titleMedium,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          for (final m in CarAnalytics(c).maintenance.where((m) => m.level != MaintenanceLevel.unknown || m.kind == MaintenanceKind.oil))
            MaintenanceCard(m),
          const SizedBox(height: 4),
          OutlinedButton.icon(
            onPressed: () => context.push('/cars/$carId/report'),
            icon: const Icon(Icons.analytics_outlined),
            label: Text('carReport.open'.tr()),
          ),
          SectionHeader('cars.expenses'.tr()),
          if (c.expenses.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Center(child: Text('cars.noExpenses'.tr())),
            )
          else
            for (final e in c.expenses)
              AppCard(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                onTap: () => _showExpense(context, ref, e),
                child: Row(
                  children: [
                    IconBubble(emoji: e.categoryIcon, color: DS.primary, size: 38),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(e.categoryPath, style: theme.textTheme.titleSmall),
                          Text(
                            [
                              DateFormat.yMMMd(lang).format(e.transaction.date),
                              if (e.expense.odometer != null)
                                'cars.odometerValue'.tr(namedArgs: {'km': NumberFormat.decimalPattern().format(e.expense.odometer)}),
                              if (e.expense.liters != null)
                                'cars.litersValue'.tr(namedArgs: {'l': NumberFormat('#,##0.##').format(e.expense.liters)}),
                            ].join(' · '),
                            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        AmountText(-e.transaction.amount, size: 14, signed: true, color: theme.colorScheme.error),
                        if (e.expense.latitude != null) Icon(Icons.place_outlined, size: 14, color: theme.colorScheme.onSurfaceVariant),
                      ],
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
  }

  Widget _stat(BuildContext context, String label, Widget value) => Expanded(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodySmall),
        value,
      ],
    ),
  );

  Future<void> _showExpense(BuildContext context, WidgetRef ref, CarExpenseItem e) async {
    final lang = context.locale.languageCode;
    await showModalBottomSheet<void>(
      context: context,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        Widget row(String k, String v) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Text(k, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
              const SizedBox(width: 12),
              Expanded(
                child: Text(v, textAlign: TextAlign.end, style: theme.textTheme.bodyMedium),
              ),
            ],
          ),
        );
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(e.categoryPath, style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                row('transactions.amount'.tr(), '${formatAmount(e.transaction.amount)} ${'common.egp'.tr()}'),
                row('transactions.date'.tr(), DateFormat.yMMMd(lang).format(e.transaction.date)),
                if (e.accountName != null) row('cars.paymentMethod'.tr(), e.accountName!),
                if (e.expense.odometer != null) row('cars.odometer'.tr(), NumberFormat.decimalPattern().format(e.expense.odometer)),
                if (e.fuelTypeName != null) row('fuel.type'.tr(), e.fuelTypeName!),
                if (e.expense.liters != null) row('cars.liters'.tr(), NumberFormat('#,##0.##').format(e.expense.liters)),
                if (e.expense.pricePerLiter != null) row('fuel.pricePerLiter'.tr(), formatAmount(e.expense.pricePerLiter!)),
                if (e.transaction.beneficiaryName != null) row('cars.station'.tr(), e.transaction.beneficiaryName!),
                if (e.expense.latitude != null)
                  row('cars.location'.tr(), '${e.expense.latitude!.toStringAsFixed(5)}, ${e.expense.longitude!.toStringAsFixed(5)}'),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    context.push('/cars/${e.expense.carId}/expense?edit=${e.expense.id}');
                  },
                  icon: const Icon(Icons.edit_outlined),
                  label: Text('common.edit'.tr()),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    if (e.expense.latitude != null)
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => openMap(e.expense.latitude!, e.expense.longitude!),
                          icon: const Icon(Icons.map_outlined),
                          label: Text('cars.openMap'.tr()),
                        ),
                      ),
                    if (e.expense.latitude != null) const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(foregroundColor: theme.colorScheme.error),
                        onPressed: () async {
                          await ref.read(carRepositoryProvider).deleteExpense(e.expense);
                          if (ctx.mounted) Navigator.pop(ctx);
                        },
                        icon: const Icon(Icons.delete_outline),
                        label: Text('common.delete'.tr()),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

enum _LocationState { locating, found, denied, off, failed }

/// Records a car expense: category/sub-category, odometer, litres × price, amount, how it was paid
/// and the GPS position where it was recorded.
class CarExpenseFormScreen extends ConsumerStatefulWidget {
  const CarExpenseFormScreen({super.key, required this.carId, this.expenseId});
  final int carId;

  /// Set when editing an existing car expense.
  final int? expenseId;

  @override
  ConsumerState<CarExpenseFormScreen> createState() => _CarExpenseFormScreenState();
}

class _CarExpenseFormScreenState extends ConsumerState<CarExpenseFormScreen> {
  late int _carId = widget.carId;
  final _amount = TextEditingController();
  final _liters = TextEditingController();
  final _odometer = TextEditingController();
  final _station = TextEditingController();
  final _note = TextEditingController();
  int? _categoryId;
  int? _fuelCategoryId;
  int? _accountId;
  int? _fuelTypeId;
  DateTime _date = todayDateOnly();
  bool _amountEdited = false;
  bool _saving = false;
  _LocationState _location = _LocationState.locating;
  Position? _position;

  @override
  void initState() {
    super.initState();
    final db = ref.read(databaseProvider);
    seededCategoryId(db, 'seed-cat-car-fuel').then((id) {
      if (!mounted) return;
      setState(() {
        _fuelCategoryId = id;
        if (widget.expenseId == null) _categoryId ??= id;
      });
    });
    if (widget.expenseId == null) {
      _locate();
    } else {
      _loadForEdit(widget.expenseId!);
    }
  }

  /// Editing: fill the form from the saved expense; its recorded location is kept.
  Future<void> _loadForEdit(int id) async {
    final repo = ref.read(carRepositoryProvider);
    final loaded = await repo.loadExpense(id);
    if (loaded == null || !mounted) return;
    final (e, t) = loaded;
    final cars = await repo.loadCars();
    final carName = cars.where((c) => c.car.id == e.carId).firstOrNull?.car.name ?? '';
    if (!mounted) return;
    setState(() {
      _carId = e.carId;
      _categoryId = t.categoryId;
      _accountId = t.accountId;
      _date = t.date;
      _amount.text = t.amount.toStringAsFixed(2);
      _amountEdited = true;
      _odometer.text = e.odometer?.toString() ?? '';
      _liters.text = e.liters == null ? '' : e.liters!.toString();
      _fuelTypeId = e.fuelTypeId ?? _fuelTypeId;
      _station.text = t.beneficiaryName ?? '';
      _note.text = CarRepository.userNote(t.note, carName);
      _location = e.latitude == null ? _LocationState.failed : _LocationState.found;
      _savedLat = e.latitude;
      _savedLng = e.longitude;
    });
  }

  double? _savedLat;
  double? _savedLng;
  double? get _lat => _position?.latitude ?? _savedLat;
  double? get _lng => _position?.longitude ?? _savedLng;

  @override
  void dispose() {
    for (final c in [_amount, _liters, _odometer, _station, _note]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _locate() async {
    setState(() => _location = _LocationState.locating);
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        if (mounted) setState(() => _location = _LocationState.off);
        return;
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await LockNotifier.runWithoutLock(Geolocator.requestPermission);
      }
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        if (mounted) setState(() => _location = _LocationState.denied);
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, timeLimit: Duration(seconds: 20)),
      );
      if (mounted) {
        setState(() {
          _position = pos;
          _location = _LocationState.found;
        });
      }
    } catch (_) {
      final last = await Geolocator.getLastKnownPosition().catchError((_) => null);
      if (mounted) {
        setState(() {
          _position = last;
          _location = last == null ? _LocationState.failed : _LocationState.found;
        });
      }
    }
  }

  FuelType? _fuel(List<FuelType> types) => types.where((f) => f.id == _fuelTypeId).firstOrNull;

  /// Litres × price of the chosen fuel (null when not a fuel fill).
  double? _fuelValue(List<FuelType> types) {
    final fuel = _fuel(types);
    final liters = _parse(_liters.text);
    if (fuel == null || liters <= 0) return null;
    return double.parse((liters * fuel.pricePerLiter).toStringAsFixed(2));
  }

  /// What was paid above the fuel value (e.g. 1,120 paid for 1,112.50 of fuel → 7.50).
  double _tips(List<FuelType> types) {
    final value = _fuelValue(types);
    if (value == null) return 0;
    final diff = _parse(_amount.text) - value;
    return diff > 0.004 ? double.parse(diff.toStringAsFixed(2)) : 0;
  }

  bool get _isFuel => _categoryId != null && _categoryId == _fuelCategoryId;

  /// Litres × price fills the amount until the user types an amount themselves.
  void _recalc(List<FuelType> types) {
    final fuel = _fuel(types);
    if (_amountEdited || fuel == null) return;
    final liters = _parse(_liters.text);
    _amount.text = liters > 0 ? (liters * fuel.pricePerLiter).toStringAsFixed(2) : '';
  }

  void _toast(String text) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));

  Future<void> _save(List<FuelType> types) async {
    // Say what is missing instead of leaving the button silently disabled.
    final missing = _categoryId == null
        ? 'cars.missingCategory'
        : _parse(_amount.text) <= 0
        ? 'cars.missingAmount'
        : _accountId == null
        ? 'cars.missingAccount'
        : null;
    if (missing != null) {
      _toast(missing.tr());
      return;
    }
    setState(() => _saving = true);
    final fuel = _fuel(types);
    final liters = _parse(_liters.text);
    try {
      final input = CarExpenseInput(
        carId: _carId,
        categoryId: _categoryId!,
        amount: _parse(_amount.text),
        accountId: _accountId!,
        date: _date,
        odometer: int.tryParse(asciiDigits(_odometer.text).trim()),
        liters: liters > 0 ? liters : null,
        fuelTypeId: liters > 0 ? fuel?.id : null,
        pricePerLiter: liters > 0 ? fuel?.pricePerLiter : null,
        latitude: _position?.latitude ?? _savedLat,
        longitude: _position?.longitude ?? _savedLng,
        tips: _tips(types) > 0 ? _tips(types) : null,
        note: _note.text,
        beneficiary: _station.text,
      );
      final repo = ref.read(carRepositoryProvider);
      if (widget.expenseId == null) {
        await repo.addExpense(input);
      } else {
        await repo.updateExpense(widget.expenseId!, input);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        _toast('${'cars.saveFailed'.tr()}: $e');
      }
      return;
    }
    if (mounted) {
      _toast('cars.saved'.tr());
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cars = ref.watch(carsProvider).value ?? const <CarWithStats>[];
    final car = cars.where((c) => c.car.id == _carId).firstOrNull;
    final types = ref.watch(fuelTypesProvider).value ?? const <FuelType>[];
    final accounts = ref.watch(accountsProvider).value ?? const <AccountWithBalance>[];
    if (_fuelTypeId == null && types.isNotEmpty) _fuelTypeId = (types.length > 1 ? types[1] : types.first).id;
    _accountId ??= accounts.where((a) => a.account.type == AccountType.cash).firstOrNull?.account.id ?? accounts.firstOrNull?.account.id;
    final account = accounts.where((a) => a.account.id == _accountId).firstOrNull;
    final categoryPath = _categoryId == null ? null : ref.watch(categoryPathProvider(_categoryId!)).value;
    final lastOdo = car?.lastOdometer;

    // The car category's sub-categories as big icon choices (fuel, service, ...).
    final tree = ref.watch(categoryTreeProvider(CategoryType.expense)).value ?? const <CategoryTreeNode>[];
    final carNode = tree.where((n) => n.main.syncId == 'seed-cat-car').firstOrNull;
    final carTypes = carNode?.children ?? const <Category>[];
    final otherSelected = _categoryId != null && !carTypes.any((c) => c.id == _categoryId);

    Widget typeChip(String emoji, String label, bool selected, VoidCallback onTap) => Padding(
      padding: const EdgeInsetsDirectional.only(end: 8),
      child: Material(
        color: selected ? DS.primary : theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Container(
            width: 70,
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: selected ? DS.gold : theme.colorScheme.outline),
            ),
            child: Column(
              children: [
                Text(emoji, style: const TextStyle(fontSize: 24)),
                const SizedBox(height: 4),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: selected ? Colors.white : theme.colorScheme.onSurface),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    return Scaffold(
      appBar: BrandFormAppBar(
        title: (widget.expenseId == null ? 'cars.addCarExpense' : 'cars.editExpenseFor').tr(namedArgs: {'car': car?.car.name ?? ''}),
        onSave: _saving ? null : () => _save(types),
      ),
      body: StickySaveLayout(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 24),
        button: BigSaveButton(label: 'common.save'.tr(), busy: _saving, onPressed: () => _save(types)),
        children: [
          // The car.
          if (car != null)
            Material(
              color: DS.goldSoft,
              borderRadius: BorderRadius.circular(DS.radiusLg),
              child: InkWell(
                borderRadius: BorderRadius.circular(DS.radiusLg),
                onTap: cars.length < 2
                    ? null
                    : () async {
                        final id = await showModalBottomSheet<int>(
                          context: context,
                          builder: (ctx) => SafeArea(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                for (final c in cars)
                                  ListTile(
                                    leading: const Icon(Icons.directions_car_filled_outlined),
                                    title: Text(c.car.name),
                                    subtitle: Text('${c.car.brand} · ${c.car.modelYear}'),
                                    onTap: () => Navigator.pop(ctx, c.car.id),
                                  ),
                              ],
                            ),
                          ),
                        );
                        if (id != null) setState(() => _carId = id);
                      },
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Container(
                        width: 78,
                        height: 52,
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                        child: const Icon(Icons.directions_car_filled_rounded, size: 40, color: DS.primary),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${car.car.brand} ${car.car.modelYear}',
                              style: theme.textTheme.titleMedium?.copyWith(color: DS.text, fontWeight: FontWeight.w800),
                            ),
                            Text(
                              [
                                car.car.name,
                                if (car.car.plate != null) 'cars.plateLine'.tr(namedArgs: {'plate': car.car.plate!}),
                              ].join(' · '),
                              style: theme.textTheme.bodySmall?.copyWith(color: DS.textMuted),
                            ),
                          ],
                        ),
                      ),
                      if (cars.length > 1) const Icon(Icons.keyboard_arrow_down, color: DS.textMuted),
                    ],
                  ),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.only(top: 14, bottom: 8),
            child: Text('cars.expenseType'.tr(), style: theme.textTheme.titleSmall),
          ),
          SizedBox(
            height: 82,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (final c in carTypes) typeChip(c.icon, c.name, _categoryId == c.id, () => setState(() => _categoryId = c.id)),
                typeChip(otherSelected ? '✔️' : '➕', 'cars.otherExpense'.tr(), otherSelected, () async {
                  final id = await showCategoryPicker(context, type: CategoryType.expense, selectedId: _categoryId);
                  if (id != null) setState(() => _categoryId = id);
                }),
              ],
            ),
          ),
          if (otherSelected && categoryPath != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(categoryPath, style: theme.textTheme.bodySmall),
            ),
          FormRowCard(
            icon: Icons.payments_outlined,
            iconColor: DS.gold,
            label: 'transactions.amount'.tr(),
            child: AmountField(controller: _amount, onChanged: (_) => setState(() => _amountEdited = true)),
          ),
          if (_fuelValue(types) != null)
            Container(
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(color: DS.goldSoft, borderRadius: BorderRadius.circular(DS.radius)),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('cars.fuelValue'.tr(), style: theme.textTheme.bodySmall?.copyWith(color: DS.textMuted)),
                        AmountText(_fuelValue(types)!, size: 15, color: DS.text),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('cars.tips'.tr(), style: theme.textTheme.bodySmall?.copyWith(color: DS.textMuted)),
                        AmountText(_tips(types), size: 15, color: _tips(types) > 0 ? DS.gold : DS.textMuted),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          if (_fuelValue(types) != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text('cars.tipsHint'.tr(), style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            ),
          if (_isFuel && _fuel(types) != null && _parse(_amount.text) > 0 && _parse(_liters.text) == 0)
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: TextButton(
                onPressed: () => setState(() => _liters.text = (_parse(_amount.text) / _fuel(types)!.pricePerLiter).toStringAsFixed(2)),
                child: Text('cars.calcLiters'.tr()),
              ),
            ),
          FormRowCard(
            icon: Icons.speed_rounded,
            label: 'cars.odometerReading'.tr(),
            child: TextField(
              controller: _odometer,
              keyboardType: TextInputType.number,
              inputFormatters: [const AsciiDigitsFormatter(), FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                hintText: lastOdo == null ? 'cars.km'.tr() : NumberFormat.decimalPattern().format(lastOdo),
                suffixText: 'cars.km'.tr(),
              ),
            ),
          ),
          if (_isFuel || _liters.text.isNotEmpty) ...[
            FormRowCard(
              icon: Icons.local_gas_station_outlined,
              label: 'fuel.type'.tr(),
              child: DropdownButtonFormField<int>(
                isExpanded: true,
                initialValue: _fuelTypeId,
                items: [
                  for (final f in types)
                    DropdownMenuItem(
                      value: f.id,
                      child: Text('${f.name} · ${formatAmount(f.pricePerLiter)}', overflow: TextOverflow.ellipsis),
                    ),
                ],
                onChanged: (v) => setState(() {
                  _fuelTypeId = v;
                  _recalc(types);
                }),
              ),
            ),
            FormRowCard(
              icon: Icons.water_drop_outlined,
              label: 'cars.liters'.tr(),
              child: TextField(
                controller: _liters,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: const [AsciiDigitsFormatter()],
                decoration: InputDecoration(suffixText: 'cars.litersUnit'.tr()),
                onChanged: (_) => setState(() => _recalc(types)),
              ),
            ),
          ],
          FormRowCard(
            icon: Icons.calendar_month_outlined,
            label: 'transactions.date'.tr(),
            child: PickerField(
              text: DateFormat.yMMMMd(context.locale.languageCode).format(_date),
              trailingIcon: Icons.calendar_today_outlined,
              onTap: () async {
                final d = await showDatePicker(context: context, initialDate: _date, firstDate: DateTime(2000), lastDate: DateTime(2100));
                if (d != null) setState(() => _date = d);
              },
            ),
          ),
          FormRowCard(
            icon: Icons.account_balance_wallet_outlined,
            label: 'transactions.account'.tr(),
            child: PickerField(
              text: account?.account.name ?? 'accounts.choose'.tr(),
              placeholder: account == null,
              subtitle: account == null ? null : 'transactions.currentBalance'.tr(namedArgs: {'amount': formatAmount(account.balance)}),
              trailingIcon: Icons.chevron_left,
              leading: account == null ? null : AccountBubble(account, size: 26),
              onTap: () async {
                final id = await showAccountPicker(context, selectedId: _accountId);
                if (id != null) setState(() => _accountId = id);
              },
            ),
          ),
          FormRowCard(
            icon: Icons.local_convenience_store_outlined,
            label: 'cars.station'.tr(),
            child: TextField(
              controller: _station,
              decoration: InputDecoration(hintText: 'cars.stationHintShort'.tr()),
            ),
          ),
          FormRowCard(
            icon: Icons.description_outlined,
            label: 'transactions.notes'.tr(),
            child: TextField(controller: _note, minLines: 2, maxLines: 3, maxLength: 500),
          ),
          const SizedBox(height: 10),
          AppCard(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Row(
              children: [
                Icon(
                  _location == _LocationState.found ? Icons.place : Icons.location_off_outlined,
                  color: _location == _LocationState.found ? DS.success : theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(switch (_location) {
                    _LocationState.locating => 'cars.locating'.tr(),
                    _LocationState.found => 'cars.locationFound'.tr(
                      namedArgs: {'lat': _lat!.toStringAsFixed(5), 'lng': _lng!.toStringAsFixed(5)},
                    ),
                    _LocationState.denied => 'cars.locationDenied'.tr(),
                    _LocationState.off => 'cars.locationOff'.tr(),
                    _LocationState.failed => 'cars.locationFailed'.tr(),
                  }, style: theme.textTheme.bodySmall),
                ),
                if (_location == _LocationState.locating)
                  const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                else if (_location == _LocationState.found)
                  IconButton(icon: const Icon(Icons.map_outlined), onPressed: () => openMap(_lat!, _lng!))
                else
                  IconButton(icon: const Icon(Icons.refresh), onPressed: _locate),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Master data: fuel grades and their price per litre.
class FuelPricesScreen extends ConsumerWidget {
  const FuelPricesScreen({super.key});

  Future<void> _edit(BuildContext context, WidgetRef ref, [FuelType? f]) async {
    final name = TextEditingController(text: f?.name);
    final price = TextEditingController(text: f?.pricePerLiter.toStringAsFixed(2));
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text((f == null ? 'fuel.add' : 'fuel.edit').tr()),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: name,
              decoration: InputDecoration(labelText: 'fuel.type'.tr()),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: price,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: const [AsciiDigitsFormatter()],
              decoration: InputDecoration(labelText: 'fuel.pricePerLiter'.tr(), suffixText: 'common.egp'.tr()),
            ),
          ],
        ),
        actions: [
          if (f != null)
            TextButton(
              onPressed: () async {
                await ref.read(carRepositoryProvider).deleteFuelType(f.id);
                if (ctx.mounted) Navigator.pop(ctx, false);
              },
              child: Text('common.delete'.tr(), style: TextStyle(color: Theme.of(ctx).colorScheme.error)),
            ),
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('common.cancel'.tr())),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(88, 44)),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('common.save'.tr()),
          ),
        ],
      ),
    );
    final p = _parse(price.text);
    if (ok == true && name.text.trim().isNotEmpty && p > 0) {
      await ref.read(carRepositoryProvider).saveFuelType(id: f?.id, name: name.text.trim(), price: p);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final types = ref.watch(fuelTypesProvider).value ?? const <FuelType>[];
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text('fuel.title'.tr())),
      floatingActionButton: FloatingActionButton(onPressed: () => _edit(context, ref), child: const Icon(Icons.add)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text('fuel.hint'.tr(), style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          ),
          AppCard(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              children: [
                for (final f in types)
                  ListTile(
                    leading: const Icon(Icons.local_gas_station_outlined),
                    title: Text(f.name),
                    subtitle: Text('${formatAmount(f.pricePerLiter)} ${'fuel.perLiter'.tr()}', style: theme.textTheme.titleSmall),
                    trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                      IconButton(tooltip: 'common.edit'.tr(), icon: const Icon(Icons.edit_outlined), onPressed: () => _edit(context, ref, f)),
                      IconButton(
                        tooltip: 'common.delete'.tr(),
                        icon: Icon(Icons.delete_outline, color: theme.colorScheme.error),
                        onPressed: () async {
                          final ok = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: Text('fuel.deleteTitle'.tr(namedArgs: {'name': f.name})),
                              content: Text('fuel.deleteHint'.tr()),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('common.cancel'.tr())),
                                FilledButton(
                                  style: FilledButton.styleFrom(backgroundColor: theme.colorScheme.error, minimumSize: const Size(88, 44)),
                                  onPressed: () => Navigator.pop(ctx, true),
                                  child: Text('common.delete'.tr()),
                                ),
                              ],
                            ),
                          );
                          if (ok == true) await ref.read(carRepositoryProvider).deleteFuelType(f.id);
                        },
                      ),
                    ]),
                    onTap: () => _edit(context, ref, f),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
