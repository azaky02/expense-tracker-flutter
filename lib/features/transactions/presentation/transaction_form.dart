import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/db/tables.dart';
import '../../../core/utils/attachments.dart';
import '../../categories/data/category_repository.dart';
import '../../categories/presentation/category_providers.dart';
import '../../payment_methods/presentation/payment_method_providers.dart';
import 'beneficiary_providers.dart';
import 'transaction_form_state.dart';

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
  final _beneficiaryController = TextEditingController();
  final _noteController = TextEditingController();
  int? _selectedMainCategoryId;
  bool _showBeneficiarySuggestions = false;

  @override
  void initState() {
    super.initState();
    _values = widget.initialValues;
    _amountController.text = _values.amount == 0 ? '' : _values.amount.toString();
    _beneficiaryController.text = _values.beneficiaryName ?? '';
    _noteController.text = _values.note ?? '';
  }

  @override
  void dispose() {
    _amountController.dispose();
    _beneficiaryController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _update(TransactionFormValues Function(TransactionFormValues) updater) {
    setState(() => _values = updater(_values));
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

  @override
  Widget build(BuildContext context) {
    final categoryTreeAsync = ref.watch(
      categoryTreeProvider(
        _values.type == TransactionType.income ? CategoryType.income : CategoryType.expense,
      ),
    );
    final categoryTree = categoryTreeAsync.value ?? const <CategoryTreeNode>[];
    final cardsAsync = ref.watch(activeCardsProvider);
    final beneficiariesAsync = ref.watch(recentBeneficiariesProvider);
    final theme = Theme.of(context);

    CategoryTreeNode? selectedMain;
    for (final node in categoryTree) {
      if (node.main.id == _selectedMainCategoryId ||
          node.main.id == _values.categoryId ||
          node.children.any((c) => c.id == _values.categoryId)) {
        selectedMain = node;
        if (node.main.id == _values.categoryId || node.children.any((c) => c.id == _values.categoryId)) {
          break;
        }
      }
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        SegmentedButton<TransactionType>(
          segments: [
            ButtonSegment(value: TransactionType.expense, label: Text('transactions.expense'.tr())),
            ButtonSegment(value: TransactionType.income, label: Text('transactions.income'.tr())),
          ],
          selected: {_values.type},
          onSelectionChanged: (s) {
            _update((v) => v.copyWith(type: s.first, categoryId: 0));
            _selectedMainCategoryId = null;
          },
        ),
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
        Text('transactions.date'.tr(), style: theme.textTheme.labelLarge),
        InkWell(
          onTap: _pickDate,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(DateFormat.yMMMd().format(_values.date)),
                const Icon(Icons.calendar_today, size: 18),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text('transactions.category'.tr(), style: theme.textTheme.labelLarge),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final node in categoryTree)
              ChoiceChip(
                avatar: Text(node.main.icon),
                label: Text(node.main.name),
                selected: selectedMain?.main.id == node.main.id,
                onSelected: (_) {
                  setState(() => _selectedMainCategoryId = node.main.id);
                  if (node.children.isEmpty) {
                    _update((v) => v.copyWith(categoryId: node.main.id));
                  } else if (!node.children.any((c) => c.id == _values.categoryId)) {
                    _update((v) => v.copyWith(categoryId: 0));
                  }
                },
              ),
          ],
        ),
        if (selectedMain != null && selectedMain.children.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final child in selectedMain.children)
                ChoiceChip(
                  avatar: Text(child.icon),
                  label: Text(child.name),
                  selected: _values.categoryId == child.id,
                  onSelected: (_) => _update((v) => v.copyWith(categoryId: child.id)),
                ),
            ],
          ),
        ],
        const SizedBox(height: 16),
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
        Text('${'transactions.beneficiary'.tr()} (${'common.optional'.tr()})',
            style: theme.textTheme.labelLarge),
        TextField(
          controller: _beneficiaryController,
          decoration: InputDecoration(hintText: 'transactions.beneficiaryPlaceholder'.tr()),
          onTap: () => setState(() => _showBeneficiarySuggestions = true),
          onChanged: (text) => _update((v) => v.copyWith(beneficiaryName: text)),
        ),
        if (_showBeneficiarySuggestions && (beneficiariesAsync.value ?? []).isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Wrap(
              spacing: 8,
              children: [
                for (final name in beneficiariesAsync.value ?? const [])
                  ActionChip(
                    label: Text(name),
                    onPressed: () {
                      _beneficiaryController.text = name;
                      _update((v) => v.copyWith(beneficiaryName: name));
                      setState(() => _showBeneficiarySuggestions = false);
                    },
                  ),
              ],
            ),
          ),
        const SizedBox(height: 16),
        Text('${'transactions.notes'.tr()} (${'common.optional'.tr()})',
            style: theme.textTheme.labelLarge),
        TextField(
          controller: _noteController,
          maxLines: 3,
          onChanged: (text) => _update((v) => v.copyWith(note: text)),
        ),
        const SizedBox(height: 16),
        Text('${'transactions.attachment'.tr()} (${'common.optional'.tr()})',
            style: theme.textTheme.labelLarge),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: _showAttachmentPicker,
          child: _values.attachmentUri != null
              ? Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.file(
                        File(_values.attachmentUri!),
                        width: 100,
                        height: 100,
                        fit: BoxFit.cover,
                      ),
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
          onPressed: widget.isSubmitting ? null : () => widget.onSubmit(_values),
          child: widget.isSubmitting
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator())
              : Text(widget.submitLabel),
        ),
      ],
    );
  }
}
