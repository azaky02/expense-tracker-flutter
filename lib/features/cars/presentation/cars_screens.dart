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
import '../../categories/presentation/category_picker_sheet.dart';
import '../data/car_repository.dart';

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
          TextButton.icon(
            onPressed: () => context.push('/fuel-prices'),
            icon: const Icon(Icons.local_gas_station_outlined),
            label: Text('fuel.title'.tr()),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        shape: const StadiumBorder(),
        onPressed: () => showCarForm(context, ref),
        icon: const Icon(Icons.add),
        label: Text('cars.add'.tr()),
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

Future<void> showCarForm(BuildContext context, WidgetRef ref, {Car? car}) async {
  final name = TextEditingController(text: car?.name);
  final brand = TextEditingController(text: car?.brand);
  final year = TextEditingController(text: car == null ? '' : '${car.modelYear}');
  final plate = TextEditingController(text: car?.plate);
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
                FieldLabel('cars.brand'.tr()),
                TextField(
                  controller: brand,
                  decoration: InputDecoration(hintText: 'cars.brandHint'.tr()),
                  onChanged: (_) => setState(() {}),
                ),
                FieldLabel('cars.modelYear'.tr()),
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
                FieldLabel('${'cars.plate'.tr()} (${'common.optional'.tr()})'),
                TextField(controller: plate),
                const SizedBox(height: 16),
                FilledButton(onPressed: valid ? () => Navigator.pop(ctx, true) : null, child: Text('common.save'.tr())),
              ],
            ),
          ),
        );
      },
    ),
  );
  if (ok == true) {
    final repo = ref.read(carRepositoryProvider);
    final p = plate.text.trim().isEmpty ? null : plate.text.trim();
    if (car == null) {
      await repo.createCar(name: name.text.trim(), brand: brand.text.trim(), modelYear: int.parse(asciiDigits(year.text)), plate: p);
    } else {
      await repo.updateCar(
        car.id,
        name: name.text.trim(),
        brand: brand.text.trim(),
        modelYear: int.parse(asciiDigits(year.text)),
        plate: p,
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
  const CarExpenseFormScreen({super.key, required this.carId});
  final int carId;

  @override
  ConsumerState<CarExpenseFormScreen> createState() => _CarExpenseFormScreenState();
}

class _CarExpenseFormScreenState extends ConsumerState<CarExpenseFormScreen> {
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
      if (mounted) setState(() => _categoryId ??= _fuelCategoryId = id);
    });
    _locate();
  }

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
      await ref
          .read(carRepositoryProvider)
          .addExpense(
            CarExpenseInput(
              carId: widget.carId,
              categoryId: _categoryId!,
              amount: _parse(_amount.text),
              accountId: _accountId!,
              date: _date,
              odometer: int.tryParse(asciiDigits(_odometer.text).trim()),
              liters: liters > 0 ? liters : null,
              fuelTypeId: liters > 0 ? fuel?.id : null,
              pricePerLiter: liters > 0 ? fuel?.pricePerLiter : null,
              latitude: _position?.latitude,
              longitude: _position?.longitude,
              note: _note.text,
              beneficiary: _station.text,
            ),
          );
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
    final car = cars.where((c) => c.car.id == widget.carId).firstOrNull;
    final types = ref.watch(fuelTypesProvider).value ?? const <FuelType>[];
    final accounts = ref.watch(accountsProvider).value ?? const <AccountWithBalance>[];
    if (_fuelTypeId == null && types.isNotEmpty) _fuelTypeId = (types.length > 1 ? types[1] : types.first).id;
    _accountId ??= accounts.where((a) => a.account.type == AccountType.cash).firstOrNull?.account.id ?? accounts.firstOrNull?.account.id;
    final account = accounts.where((a) => a.account.id == _accountId).firstOrNull;
    final categoryPath = _categoryId == null ? null : ref.watch(categoryPathProvider(_categoryId!)).value;
    final lastOdo = car?.lastOdometer;

    return Scaffold(
      appBar: AppBar(title: Text('cars.addExpenseFor'.tr(namedArgs: {'car': car?.car.name ?? ''}))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
        children: [
          FieldLabel('transactions.category'.tr()),
          PickerField(
            text: categoryPath ?? 'transactions.chooseCategory'.tr(),
            placeholder: categoryPath == null,
            onTap: () async {
              final id = await showCategoryPicker(context, type: CategoryType.expense, selectedId: _categoryId);
              if (id != null) setState(() => _categoryId = id);
            },
          ),
          FieldLabel('transactions.date'.tr()),
          PickerField(
            text: DateFormat.yMMMMd(context.locale.languageCode).format(_date),
            trailingIcon: Icons.calendar_today_outlined,
            onTap: () async {
              final d = await showDatePicker(context: context, initialDate: _date, firstDate: DateTime(2000), lastDate: DateTime(2100));
              if (d != null) setState(() => _date = d);
            },
          ),
          FieldLabel('cars.odometer'.tr()),
          TextField(
            controller: _odometer,
            keyboardType: TextInputType.number,
            inputFormatters: [const AsciiDigitsFormatter(), FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(
              hintText: lastOdo == null
                  ? 'cars.odometerHint'.tr()
                  : 'cars.lastOdometer'.tr(namedArgs: {'km': NumberFormat.decimalPattern().format(lastOdo)}),
              suffixText: 'cars.km'.tr(),
            ),
          ),
          if (_isFuel || _liters.text.isNotEmpty) ...[
            FieldLabel('fuel.type'.tr()),
            DropdownButtonFormField<int>(
              isExpanded: true,
              initialValue: _fuelTypeId,
              items: [
                for (final f in types)
                  DropdownMenuItem(value: f.id, child: Text('${f.name} — ${formatAmount(f.pricePerLiter)} ${'fuel.perLiter'.tr()}')),
              ],
              onChanged: (v) => setState(() {
                _fuelTypeId = v;
                _recalc(types);
              }),
            ),
            FieldLabel('cars.liters'.tr()),
            TextField(
              controller: _liters,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: const [AsciiDigitsFormatter()],
              decoration: InputDecoration(suffixText: 'cars.litersUnit'.tr()),
              onChanged: (_) => setState(() => _recalc(types)),
            ),
          ],
          FieldLabel('cars.amountPaid'.tr()),
          AmountField(controller: _amount, onChanged: (_) => setState(() => _amountEdited = true)),
          if (_isFuel && _fuel(types) != null && _parse(_amount.text) > 0 && _parse(_liters.text) == 0)
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton(
                onPressed: () => setState(() => _liters.text = (_parse(_amount.text) / _fuel(types)!.pricePerLiter).toStringAsFixed(2)),
                child: Text('cars.calcLiters'.tr()),
              ),
            ),
          FieldLabel('cars.paymentMethod'.tr()),
          PickerField(
            text: account?.account.name ?? 'accounts.choose'.tr(),
            placeholder: account == null,
            leading: account == null ? null : AccountBubble(account, size: 28),
            onTap: () async {
              final id = await showAccountPicker(context, selectedId: _accountId);
              if (id != null) setState(() => _accountId = id);
            },
          ),
          FieldLabel('${'cars.station'.tr()} (${'common.optional'.tr()})'),
          TextField(
            controller: _station,
            decoration: InputDecoration(hintText: 'cars.stationHint'.tr()),
          ),
          FieldLabel('${'transactions.notes'.tr()} (${'common.optional'.tr()})'),
          TextField(controller: _note, maxLines: 2),
          const SizedBox(height: 12),
          AppCard(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                      namedArgs: {'lat': _position!.latitude.toStringAsFixed(5), 'lng': _position!.longitude.toStringAsFixed(5)},
                    ),
                    _LocationState.denied => 'cars.locationDenied'.tr(),
                    _LocationState.off => 'cars.locationOff'.tr(),
                    _LocationState.failed => 'cars.locationFailed'.tr(),
                  }, style: theme.textTheme.bodySmall),
                ),
                if (_location == _LocationState.locating)
                  const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                else if (_location == _LocationState.found)
                  IconButton(icon: const Icon(Icons.map_outlined), onPressed: () => openMap(_position!.latitude, _position!.longitude))
                else
                  IconButton(icon: const Icon(Icons.refresh), onPressed: _locate),
              ],
            ),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _saving ? null : () => _save(types),
            child: _saving
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : Text('common.save'.tr()),
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
                    trailing: Text('${formatAmount(f.pricePerLiter)} ${'fuel.perLiter'.tr()}', style: theme.textTheme.titleSmall),
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
