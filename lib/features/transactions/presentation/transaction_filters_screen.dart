import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/db/tables.dart';
import '../../../core/widgets/ds_widgets.dart';
import '../../accounts/data/account_repository.dart';
import '../../accounts/presentation/account_providers.dart';
import '../../accounts/presentation/account_widgets.dart';
import '../../categories/data/category_repository.dart';
import '../../categories/presentation/category_picker_sheet.dart';
import '../../categories/presentation/category_providers.dart';
import '../data/transaction_repository.dart';
import 'person_picker_sheet.dart';
import 'transactions_list_screen.dart';

/// Filters (UI/UX TRX-03 / §11, mockup 9): period, type, category, account, person, amount range,
/// attachment. Edits a copy and applies it on "Apply".
class TransactionFiltersScreen extends ConsumerStatefulWidget {
  const TransactionFiltersScreen({super.key});

  @override
  ConsumerState<TransactionFiltersScreen> createState() => _TransactionFiltersScreenState();
}

class _TransactionFiltersScreenState extends ConsumerState<TransactionFiltersScreen> {
  late TransactionFilters _f = ref.read(transactionFiltersProvider);
  late final _min = TextEditingController(text: _f.minAmount?.toStringAsFixed(0) ?? '');
  late final _max = TextEditingController(text: _f.maxAmount?.toStringAsFixed(0) ?? '');
  int? _categoryId;

  @override
  void initState() {
    super.initState();
    _categoryId = _f.categoryIds?.first;
  }

  @override
  void dispose() {
    _min.dispose();
    _max.dispose();
    super.dispose();
  }

  TransactionFilters _with({
    Object? from = _keep,
    Object? to = _keep,
    Object? types = _keep,
    Object? categoryIds = _keep,
    Object? accountId = _keep,
    Object? person = _keep,
    Object? hasAttachment = _keep,
  }) =>
      TransactionFilters(
        from: from == _keep ? _f.from : from as DateTime?,
        to: to == _keep ? _f.to : to as DateTime?,
        types: types == _keep ? _f.types : types as Set<TransactionType>?,
        categoryIds: categoryIds == _keep ? _f.categoryIds : categoryIds as List<int>?,
        accountId: accountId == _keep ? _f.accountId : accountId as int?,
        person: person == _keep ? _f.person : person as String?,
        hasAttachment: hasAttachment == _keep ? _f.hasAttachment : hasAttachment as bool?,
        minAmount: _f.minAmount,
        maxAmount: _f.maxAmount,
      );

  Future<DateTime?> _date(DateTime? initial) => showDatePicker(
        context: context,
        initialDate: initial ?? DateTime.now(),
        firstDate: DateTime(2000),
        lastDate: DateTime(2100),
      );

  void _apply() {
    final f = TransactionFilters(
      from: _f.from,
      to: _f.to,
      types: _f.types,
      categoryIds: _f.categoryIds,
      accountId: _f.accountId,
      person: _f.person,
      hasAttachment: _f.hasAttachment,
      minAmount: double.tryParse(_min.text.replaceAll(',', '')),
      maxAmount: double.tryParse(_max.text.replaceAll(',', '')),
    );
    ref.read(transactionFiltersProvider.notifier).set(f);
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat.yMd(context.locale.languageCode);
    final accounts = ref.watch(accountsProvider).value ?? const <AccountWithBalance>[];
    final tree = ref.watch(categoryTreeProvider(null)).value ?? const <CategoryTreeNode>[];
    String? categoryName;
    for (final n in tree) {
      if (n.main.id == _categoryId) categoryName = n.main.name;
      for (final c in n.children) {
        if (c.id == _categoryId) categoryName = '${n.main.name} / ${c.name}';
      }
    }
    String? accountName;
    for (final a in accounts) {
      if (a.account.id == _f.accountId) accountName = a.account.name;
    }
    final typeValue = _f.types?.length == 1 ? _f.types!.first : null;

    return Scaffold(
      appBar: AppBar(
        title: Text('transactions.filters'.tr()),
        actions: [
          TextButton(
            onPressed: () => setState(() {
              _f = const TransactionFilters();
              _categoryId = null;
              _min.clear();
              _max.clear();
            }),
            child: Text('transactions.reset'.tr()),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: [
          FieldLabel('transactions.period'.tr()),
          Row(children: [
            Expanded(
              child: PickerField(
                text: _f.from == null ? 'transactions.from'.tr() : fmt.format(_f.from!),
                placeholder: _f.from == null,
                trailingIcon: Icons.calendar_today_outlined,
                onTap: () async {
                  final d = await _date(_f.from);
                  if (d != null) setState(() => _f = _with(from: d));
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: PickerField(
                text: _f.to == null ? 'transactions.to'.tr() : fmt.format(_f.to!),
                placeholder: _f.to == null,
                trailingIcon: Icons.calendar_today_outlined,
                onTap: () async {
                  final d = await _date(_f.to);
                  if (d != null) setState(() => _f = _with(to: d));
                },
              ),
            ),
          ]),
          FieldLabel('transactions.type'.tr()),
          AppCard(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: RadioGroup<TransactionType?>(
              groupValue: typeValue,
              onChanged: (v) => setState(() => _f = _with(types: v == null ? null : {v})),
              child: Column(children: [
                RadioListTile<TransactionType?>(value: null, title: Text('transactions.tab.all'.tr())),
                RadioListTile<TransactionType?>(value: TransactionType.expense, title: Text('transactions.tab.expense'.tr())),
                RadioListTile<TransactionType?>(value: TransactionType.income, title: Text('transactions.tab.income'.tr())),
                RadioListTile<TransactionType?>(value: TransactionType.transfer, title: Text('transactions.tab.transfer'.tr())),
              ]),
            ),
          ),
          FieldLabel('transactions.category'.tr()),
          PickerField(
            text: categoryName ?? 'transactions.allCategories'.tr(),
            placeholder: categoryName == null,
            onTap: () async {
              final type = typeValue == TransactionType.income ? CategoryType.income : CategoryType.expense;
              final id = await showCategoryPicker(context, type: type, selectedId: _categoryId);
              if (id == null) return;
              // A main category includes its sub-categories.
              final ids = <int>[id];
              for (final n in tree) {
                if (n.main.id == id) ids.addAll(n.children.map((c) => c.id));
              }
              setState(() {
                _categoryId = id;
                _f = _with(categoryIds: ids);
              });
            },
          ),
          FieldLabel('transactions.account'.tr()),
          PickerField(
            text: accountName ?? 'transactions.allAccounts'.tr(),
            placeholder: accountName == null,
            onTap: () async {
              final id = await showAccountPicker(context, selectedId: _f.accountId);
              if (id != null) setState(() => _f = _with(accountId: id));
            },
          ),
          FieldLabel('transactions.person'.tr()),
          PickerField(
            text: _f.person ?? 'transactions.allPeople'.tr(),
            placeholder: _f.person == null,
            onTap: () async {
              final name = await showPersonPicker(context, title: 'transactions.person'.tr(), selected: _f.person, allowNone: true);
              if (name != null) setState(() => _f = _with(person: name.isEmpty ? null : name));
            },
          ),
          FieldLabel('transactions.amountRange'.tr()),
          Row(children: [
            Expanded(
              child: TextField(controller: _min, keyboardType: TextInputType.number, decoration: InputDecoration(hintText: 'transactions.from'.tr())),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(controller: _max, keyboardType: TextInputType.number, decoration: InputDecoration(hintText: 'transactions.to'.tr())),
            ),
          ]),
          const SizedBox(height: 8),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _f.hasAttachment == true,
            onChanged: (v) => setState(() => _f = _with(hasAttachment: v ? true : null)),
            title: Text('transactions.hasAttachment'.tr()),
          ),
          const SizedBox(height: 16),
          FilledButton(onPressed: _apply, child: Text('transactions.applyFilters'.tr())),
        ],
      ),
    );
  }
}

const _keep = Object();
