import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/tables.dart';
import 'card_form_state.dart';
import 'payment_method_providers.dart';

class CardForm extends ConsumerStatefulWidget {
  const CardForm({
    super.key,
    required this.initialValues,
    required this.onSubmit,
    required this.submitLabel,
    this.isSubmitting = false,
  });

  final CardFormValues initialValues;
  final Future<void> Function(CardFormValues values) onSubmit;
  final String submitLabel;
  final bool isSubmitting;

  @override
  ConsumerState<CardForm> createState() => _CardFormState();
}

class _CardFormState extends ConsumerState<CardForm> {
  late CardFormValues _values;
  final _nicknameController = TextEditingController();
  final _last4Controller = TextEditingController();
  final _dueDateController = TextEditingController();
  final _creditLimitController = TextEditingController();
  final _newBankController = TextEditingController();
  bool _showAddBank = false;

  @override
  void initState() {
    super.initState();
    _values = widget.initialValues;
    _nicknameController.text = _values.nickname;
    _last4Controller.text = _values.last4Digits;
    _dueDateController.text = _values.dueDateDay?.toString() ?? '';
    _creditLimitController.text = _values.creditLimit?.toString() ?? '';
  }

  @override
  void dispose() {
    _nicknameController.dispose();
    _last4Controller.dispose();
    _dueDateController.dispose();
    _creditLimitController.dispose();
    _newBankController.dispose();
    super.dispose();
  }

  void _update(CardFormValues Function(CardFormValues) updater) {
    setState(() => _values = updater(_values));
  }

  Future<void> _addBank() async {
    final name = _newBankController.text.trim();
    if (name.isEmpty) return;
    final id = await ref.read(bankRepositoryProvider).createCustom(name);
    _newBankController.clear();
    setState(() => _showAddBank = false);
    _update((v) => v.copyWith(bankId: id));
  }

  @override
  Widget build(BuildContext context) {
    final banksAsync = ref.watch(bankListProvider);
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('cards.bank'.tr(), style: theme.textTheme.labelLarge),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final bank in banksAsync.value ?? const [])
              ChoiceChip(
                label: Text(bank.name),
                selected: _values.bankId == bank.id,
                onSelected: (_) => _update((v) => v.copyWith(bankId: bank.id)),
              ),
            ActionChip(
              label: Text('+ ${'cards.bank'.tr()}'),
              onPressed: () => setState(() => _showAddBank = !_showAddBank),
            ),
          ],
        ),
        if (_showAddBank)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              children: [
                Expanded(child: TextField(controller: _newBankController)),
                const SizedBox(width: 8),
                FilledButton(onPressed: _addBank, child: Text('common.add'.tr())),
              ],
            ),
          ),
        const SizedBox(height: 16),
        Text('cards.cardType'.tr(), style: theme.textTheme.labelLarge),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            for (final type in CardType.values)
              ChoiceChip(
                label: Text(type.name),
                selected: _values.cardType == type,
                onSelected: (_) => _update((v) => v.copyWith(cardType: type)),
              ),
          ],
        ),
        const SizedBox(height: 16),
        Text('cards.cardCategory'.tr(), style: theme.textTheme.labelLarge),
        const SizedBox(height: 8),
        SegmentedButton<CardCategory>(
          segments: [
            ButtonSegment(value: CardCategory.credit, label: Text('cards.credit'.tr())),
            ButtonSegment(value: CardCategory.debit, label: Text('cards.debit'.tr())),
          ],
          selected: {_values.cardCategory},
          onSelectionChanged: (s) => _update((v) => v.copyWith(cardCategory: s.first)),
        ),
        const SizedBox(height: 16),
        Text('cards.nickname'.tr(), style: theme.textTheme.labelLarge),
        TextField(
          controller: _nicknameController,
          onChanged: (text) => _update((v) => v.copyWith(nickname: text)),
        ),
        const SizedBox(height: 16),
        Text('cards.last4Digits'.tr(), style: theme.textTheme.labelLarge),
        TextField(
          controller: _last4Controller,
          keyboardType: TextInputType.number,
          maxLength: 4,
          onChanged: (text) => _update((v) => v.copyWith(last4Digits: text)),
        ),
        if (_values.cardCategory == CardCategory.credit) ...[
          Text('${'cards.dueDate'.tr()} (1-31)', style: theme.textTheme.labelLarge),
          TextField(
            controller: _dueDateController,
            keyboardType: TextInputType.number,
            onChanged: (text) => _update((v) => v.copyWith(dueDateDay: int.tryParse(text))),
          ),
          const SizedBox(height: 16),
          Text('${'cards.creditLimit'.tr()} (${'common.optional'.tr()})', style: theme.textTheme.labelLarge),
          TextField(
            controller: _creditLimitController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (text) => _update((v) => v.copyWith(creditLimit: double.tryParse(text))),
          ),
        ],
        const SizedBox(height: 24),
        FilledButton(
          onPressed: widget.isSubmitting || !_values.isValid ? null : () => widget.onSubmit(_values),
          child: widget.isSubmitting
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator())
              : Text(widget.submitLabel),
        ),
      ],
    );
  }
}
