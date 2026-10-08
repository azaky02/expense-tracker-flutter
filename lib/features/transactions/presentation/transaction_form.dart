import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/db/tables.dart';
import '../../../core/utils/attachments.dart';
import '../../categories/data/category_repository.dart';
import '../../categories/presentation/category_picker_sheet.dart';
import '../../categories/presentation/category_providers.dart';
import '../../payment_methods/presentation/payment_method_providers.dart';
import 'person_picker_sheet.dart';
import 'transaction_form_state.dart';
import 'transaction_providers.dart';

/// The three kinds the user chooses between; amanat then has a direction (in / out).
enum _Kind { expense, income, trust }

_Kind _kindOf(TransactionType t) => switch (t) {
      TransactionType.expense => _Kind.expense,
      TransactionType.income => _Kind.income,
      TransactionType.trustIn || TransactionType.trustOut => _Kind.trust,
    };

class TransactionForm extends ConsumerStatefulWidget {
  const TransactionForm({
    super.key,
    required this.initialValues,
    required this.onSubmit,
    required this.submitLabel,
    this.isSubmitting = false,
  });

  final TransactionFormValues initialValues;
  final Future<void> Function(TransactionFormValues values) onSubmit;
  final String submitLabel;
  final bool isSubmitting;

  @override
  ConsumerState<TransactionForm> createState() => _TransactionFormState();
}

class _TransactionFormState extends ConsumerState<TransactionForm> {
  late TransactionFormValues _values;
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _values = widget.initialValues;
    _amountController.text = _values.amount == 0 ? '' : _values.amount.toString();
    _noteController.text = _values.note ?? '';
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _update(TransactionFormValues Function(TransactionFormValues) updater) {
    setState(() => _values = updater(_values));
  }

  Future<void> _setKind(_Kind kind) async {
    switch (kind) {
      case _Kind.expense:
        _update((v) => v.copyWith(type: TransactionType.expense, categoryId: 0));
      case _Kind.income:
        _update((v) => v.copyWith(type: TransactionType.income, categoryId: 0));
      case _Kind.trust:
        final id = await ref.read(trustCategoryIdProvider.future);
        _update((v) => v.copyWith(
              type: _kindOf(v.type) == _Kind.trust ? v.type : TransactionType.trustIn,
              categoryId: id,
            ));
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: source, imageQuality: 70);
    if (picked == null) return;
    if (_values.attachmentUri != null) {
      await deleteAttachment(_values.attachmentUri);
    }
    final persisted = await persistAttachment(picked.path);
    _update((v) => v.copyWith(attachmentUri: persisted));
  }

  void _showAttachmentPicker() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: Text('transactions.attachment'.tr()),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Gallery'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _values.date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) _update((v) => v.copyWith(date: picked));
  }

  Future<void> _pickCategory(CategoryType type) async {
    final id = await showCategoryPicker(
      context,
      type: type,
      selectedId: _values.categoryId == 0 ? null : _values.categoryId,
    );
    if (id != null) _update((v) => v.copyWith(categoryId: id));
  }

  Future<void> _pickPerson({required bool required}) async {
    final isTrust = _kindOf(_values.type) == _Kind.trust;
    final name = await showPersonPicker(
      context,
      title: (isTrust ? 'transactions.person' : 'transactions.beneficiary').tr(),
      selected: _values.beneficiaryName,
      allowNone: !required,
    );
    if (name == null) return;
    _update((v) => v.copyWith(beneficiaryName: name, clearBeneficiary: name.isEmpty));
  }

  /// A tappable box that looks like a dropdown.
  Widget _dropdownBox(ThemeData theme, {required String text, required bool placeholder, IconData? icon}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              text,
              overflow: TextOverflow.ellipsis,
              style: placeholder ? TextStyle(color: theme.colorScheme.onSurfaceVariant) : null,
            ),
          ),
          Icon(icon ?? Icons.arrow_drop_down),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final kind = _kindOf(_values.type);
    final isTrust = kind == _Kind.trust;
    final categoryType = kind == _Kind.income ? CategoryType.income : CategoryType.expense;
    final categoryTree = ref.watch(categoryTreeProvider(categoryType)).value ?? const <CategoryTreeNode>[];
    final cardsAsync = ref.watch(activeCardsProvider);
    final theme = Theme.of(context);

    String? categoryLabel;
    for (final node in categoryTree) {
      if (node.main.id == _values.categoryId) {
        categoryLabel = '${node.main.icon} ${node.main.name}';
      }
      for (final c in node.children) {
        if (c.id == _values.categoryId) categoryLabel = '${node.main.icon} ${node.main.name} / ${c.name}';
      }
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        SegmentedButton<_Kind>(
          segments: [
            ButtonSegment(value: _Kind.expense, label: Text('transactions.expense'.tr())),
            ButtonSegment(value: _Kind.income, label: Text('transactions.income'.tr())),
            ButtonSegment(value: _Kind.trust, label: Text('transactions.trust'.tr())),
          ],
          selected: {kind},
          onSelectionChanged: (s) => _setKind(s.first),
        ),
        if (isTrust) ...[
          const SizedBox(height: 8),
          SegmentedButton<TransactionType>(
            segments: [
              ButtonSegment(value: TransactionType.trustIn, label: Text('transactions.trustIn'.tr())),
              ButtonSegment(value: TransactionType.trustOut, label: Text('transactions.trustOut'.tr())),
            ],
            selected: {_values.type},
            onSelectionChanged: (s) => _update((v) => v.copyWith(type: s.first)),
          ),
        ],
        const SizedBox(height: 16),
        Text('transactions.amount'.tr(), style: theme.textTheme.labelLarge),
        TextField(
          controller: _amountController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineSmall,
          decoration: const InputDecoration(hintText: '0.00'),
          onChanged: (text) => _update((v) => v.copyWith(amount: double.tryParse(text) ?? 0)),
        ),
        const SizedBox(height: 16),
        if (isTrust) ...[
          Text('transactions.person'.tr(), style: theme.textTheme.labelLarge),
          const SizedBox(height: 4),
          InkWell(
            onTap: () => _pickPerson(required: true),
            borderRadius: BorderRadius.circular(12),
            child: _dropdownBox(
              theme,
              text: _values.beneficiaryName ?? 'transactions.choosePerson'.tr(),
              placeholder: _values.beneficiaryName == null,
            ),
          ),
          const SizedBox(height: 16),
        ],
        Text('transactions.date'.tr(), style: theme.textTheme.labelLarge),
        const SizedBox(height: 4),
        InkWell(
          onTap: _pickDate,
          borderRadius: BorderRadius.circular(12),
          child: _dropdownBox(theme,
              text: DateFormat.yMMMd().format(_values.date), placeholder: false, icon: Icons.calendar_today),
        ),
        const SizedBox(height: 16),
        if (!isTrust) ...[
          Text('transactions.category'.tr(), style: theme.textTheme.labelLarge),
          const SizedBox(height: 4),
          InkWell(
            onTap: () => _pickCategory(categoryType),
            borderRadius: BorderRadius.circular(12),
            child: _dropdownBox(
              theme,
              text: categoryLabel ?? 'transactions.chooseCategory'.tr(),
              placeholder: categoryLabel == null,
            ),
          ),
          const SizedBox(height: 16),
        ],
        Text('transactions.paymentMethod'.tr(), style: theme.textTheme.labelLarge),
        const SizedBox(height: 8),
        SegmentedButton<PaymentMethodType>(
          segments: [
            ButtonSegment(value: PaymentMethodType.cash, label: Text('common.cash'.tr())),
            ButtonSegment(value: PaymentMethodType.card, label: Text('common.card'.tr())),
          ],
          selected: {_values.paymentMethodType},
          onSelectionChanged: (s) => _update(
            (v) => v.copyWith(
              paymentMethodType: s.first,
              clearCardId: s.first == PaymentMethodType.cash,
            ),
          ),
        ),
        if (_values.paymentMethodType == PaymentMethodType.card) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final c in cardsAsync.value ?? const [])
                ChoiceChip(
                  label: Text('${c.card.nickname} •${c.card.last4Digits}'),
                  selected: _values.cardId == c.card.id,
                  onSelected: (_) => _update((v) => v.copyWith(cardId: c.card.id)),
                ),
            ],
          ),
        ],
        const SizedBox(height: 16),
        if (!isTrust) ...[
          Text('${'transactions.beneficiary'.tr()} (${'common.optional'.tr()})', style: theme.textTheme.labelLarge),
          const SizedBox(height: 4),
          InkWell(
            onTap: () => _pickPerson(required: false),
            borderRadius: BorderRadius.circular(12),
            child: _dropdownBox(
              theme,
              text: _values.beneficiaryName ?? 'transactions.beneficiaryPlaceholder'.tr(),
              placeholder: _values.beneficiaryName == null,
            ),
          ),
          const SizedBox(height: 16),
        ],
        Text('${'transactions.notes'.tr()} (${'common.optional'.tr()})', style: theme.textTheme.labelLarge),
        TextField(
          controller: _noteController,
          maxLines: 3,
          onChanged: (text) => _update((v) => v.copyWith(note: text)),
        ),
        const SizedBox(height: 16),
        Text('${'transactions.attachment'.tr()} (${'common.optional'.tr()})', style: theme.textTheme.labelLarge),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: _showAttachmentPicker,
          child: _values.attachmentUri != null
              ? Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.file(File(_values.attachmentUri!), width: 100, height: 100, fit: BoxFit.cover),
                    ),
                    Positioned(
                      top: -8,
                      right: -8,
                      child: IconButton(
                        icon: const CircleAvatar(radius: 12, child: Icon(Icons.close, size: 14)),
                        onPressed: () async {
                          await deleteAttachment(_values.attachmentUri);
                          _update((v) => v.copyWith(clearAttachment: true));
                        },
                      ),
                    ),
                  ],
                )
              : Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    border: Border.all(color: theme.colorScheme.outline, style: BorderStyle.solid),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.camera_alt_outlined),
                ),
        ),
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
