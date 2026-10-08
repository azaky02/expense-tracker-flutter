import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/db/tables.dart';
import '../../../core/security/lock_provider.dart';
import '../../../core/theme/ds_tokens.dart';
import '../../../core/utils/attachments.dart';
import '../../../core/utils/color_utils.dart';
import '../../../core/widgets/ds_widgets.dart';
import '../../accounts/data/account_repository.dart';
import '../../accounts/presentation/account_providers.dart';
import '../../accounts/presentation/account_widgets.dart';
import '../../categories/data/category_repository.dart';
import '../../categories/presentation/category_picker_sheet.dart';
import '../../categories/presentation/category_providers.dart';
import 'person_picker_sheet.dart';
import 'transaction_form_state.dart';
import 'transaction_providers.dart';

/// Add / edit form for expenses, income and transfers (UI/UX document §8, TRX-04..06):
/// amount first, then date, category and account, then description and attachment.
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
  bool _defaultsApplied = false;

  @override
  void initState() {
    super.initState();
    _values = widget.initialValues;
    _amountController.text = _values.amount == 0 ? '' : _trimAmount(_values.amount);
    _noteController.text = _values.note ?? '';
    if (_values.isTransfer && _values.categoryId == 0) {
      Future.microtask(() async {
        final id = await ref.read(systemCategoryIdProvider(CategoryType.transfer).future);
        if (mounted) _update((v) => v.copyWith(categoryId: id));
      });
    }
  }

  String _trimAmount(double a) => a == a.roundToDouble() ? a.toStringAsFixed(0) : a.toString();

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _update(TransactionFormValues Function(TransactionFormValues) updater) {
    setState(() => _values = updater(_values));
  }

  /// New entries start on the Cash account.
  void _applyDefaults(List<AccountWithBalance> accounts) {
    if (_defaultsApplied || accounts.isEmpty) return;
    _defaultsApplied = true;
    if (_values.accountId == null) {
      final cash = accounts.firstWhere((a) => a.account.type == AccountType.cash, orElse: () => accounts.first);
      WidgetsBinding.instance.addPostFrameCallback((_) => _setAccount(cash));
    }
  }

  void _setAccount(AccountWithBalance a) {
    final isCard = a.account.cardId != null;
    _update((v) => v.copyWith(
          accountId: a.account.id,
          paymentMethodType: isCard ? PaymentMethodType.card : PaymentMethodType.cash,
          cardId: a.account.cardId,
          clearCardId: !isCard,
        ));
  }

  Future<void> _pickImage(ImageSource source) async {
    final picked = await LockNotifier.runWithoutLock(() => ImagePicker().pickImage(source: source, imageQuality: 70));
    if (picked == null) return;
    if (_values.attachmentUri != null) await deleteAttachment(_values.attachmentUri);
    final persisted = await persistAttachment(picked.path);
    _update((v) => v.copyWith(attachmentUri: persisted));
  }

  void _showAttachmentPicker() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Wrap(children: [
          ListTile(
            leading: const Icon(Icons.photo_camera_outlined),
            title: Text('transactions.camera'.tr()),
            onTap: () {
              Navigator.pop(ctx);
              _pickImage(ImageSource.camera);
            },
          ),
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: Text('transactions.gallery'.tr()),
            onTap: () {
              Navigator.pop(ctx);
              _pickImage(ImageSource.gallery);
            },
          ),
        ]),
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
    final id = await showCategoryPicker(context, type: type, selectedId: _values.categoryId == 0 ? null : _values.categoryId);
    if (id != null) _update((v) => v.copyWith(categoryId: id));
  }

  Future<void> _pickAccount({required bool destination}) async {
    final accounts = ref.read(accountsProvider).value ?? const <AccountWithBalance>[];
    final id = await showAccountPicker(
      context,
      selectedId: destination ? _values.toAccountId : _values.accountId,
      excludeId: _values.isTransfer ? (destination ? _values.accountId : _values.toAccountId) : null,
      title: destination ? 'transactions.toAccount'.tr() : (_values.isTransfer ? 'transactions.fromAccount'.tr() : null),
    );
    if (id == null) return;
    if (destination) {
      _update((v) => v.copyWith(toAccountId: id));
    } else {
      _setAccount(accounts.firstWhere((a) => a.account.id == id));
    }
  }

  Future<void> _pickPerson() async {
    final name = await showPersonPicker(
      context,
      title: 'transactions.beneficiary'.tr(),
      selected: _values.beneficiaryName,
      allowNone: true,
    );
    if (name == null) return;
    _update((v) => v.copyWith(beneficiaryName: name, clearBeneficiary: name.isEmpty));
  }

  Widget _accountField(List<AccountWithBalance> accounts, int? id, {required bool destination}) {
    AccountWithBalance? a;
    for (final x in accounts) {
      if (x.account.id == id) a = x;
    }
    return PickerField(
      text: a?.account.name ?? 'accounts.choose'.tr(),
      placeholder: a == null,
      leading: a == null ? null : AccountBubble(a, size: 28),
      onTap: () => _pickAccount(destination: destination),
    );
  }

  @override
  Widget build(BuildContext context) {
    final type = _values.type;
    final isTransfer = _values.isTransfer;
    final categoryType = type == TransactionType.income ? CategoryType.income : CategoryType.expense;
    final categoryTree = ref.watch(categoryTreeProvider(categoryType)).value ?? const <CategoryTreeNode>[];
    final accounts = ref.watch(accountsProvider).value ?? const <AccountWithBalance>[];
    _applyDefaults(accounts);
    final theme = Theme.of(context);

    String? categoryLabel;
    String? categoryIcon;
    Color? categoryColor;
    for (final node in categoryTree) {
      if (node.main.id == _values.categoryId) {
        categoryLabel = node.main.name;
        categoryIcon = node.main.icon;
        categoryColor = colorFromHex(node.main.color);
      }
      for (final c in node.children) {
        if (c.id == _values.categoryId) {
          categoryLabel = '${node.main.name} / ${c.name}';
          categoryIcon = c.icon;
          categoryColor = colorFromHex(node.main.color);
        }
      }
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        FieldLabel('transactions.amount'.tr()),
        AmountField(
          controller: _amountController,
          autofocus: widget.initialValues.amount == 0,
          onChanged: (text) => _update((v) => v.copyWith(amount: double.tryParse(text.replaceAll(',', '')) ?? 0)),
        ),
        FieldLabel('transactions.date'.tr()),
        PickerField(
          text: DateFormat.yMMMMd(context.locale.languageCode).format(_values.date),
          trailingIcon: Icons.calendar_today_outlined,
          onTap: _pickDate,
        ),
        if (isTransfer) ...[
          FieldLabel('transactions.fromAccount'.tr()),
          _accountField(accounts, _values.accountId, destination: false),
          Center(
            child: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: IconBubble(icon: Icons.south, color: theme.colorScheme.primary, size: 32),
            ),
          ),
          FieldLabel('transactions.toAccount'.tr()),
          _accountField(accounts, _values.toAccountId, destination: true),
        ] else ...[
          FieldLabel('transactions.category'.tr()),
          PickerField(
            text: categoryLabel ?? 'transactions.chooseCategory'.tr(),
            placeholder: categoryLabel == null,
            leading: categoryLabel == null ? null : IconBubble(emoji: categoryIcon, color: categoryColor ?? DS.primary, size: 28),
            onTap: () => _pickCategory(categoryType),
          ),
          FieldLabel('transactions.account'.tr()),
          _accountField(accounts, _values.accountId, destination: false),
        ],
        FieldLabel('transactions.notes'.tr()),
        TextField(
          controller: _noteController,
          maxLines: 3,
          minLines: 2,
          decoration: InputDecoration(hintText: 'transactions.notesHint'.tr()),
          onChanged: (text) => _update((v) => v.copyWith(note: text)),
        ),
        if (!isTransfer) ...[
          FieldLabel('${'transactions.beneficiary'.tr()} (${'common.optional'.tr()})'),
          PickerField(
            text: _values.beneficiaryName ?? 'transactions.beneficiaryPlaceholder'.tr(),
            placeholder: _values.beneficiaryName == null,
            leading: const Icon(Icons.person_outline, size: 20),
            onTap: _pickPerson,
          ),
          FieldLabel('${'transactions.attachment'.tr()} (${'common.optional'.tr()})'),
          _attachment(theme),
        ],
        const SizedBox(height: 24),
        FilledButton(
          onPressed: widget.isSubmitting || !_values.isValid ? null : () => widget.onSubmit(_values),
          child: widget.isSubmitting
              ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : Text(widget.submitLabel),
        ),
      ],
    );
  }

  Widget _attachment(ThemeData theme) {
    if (_values.attachmentUri != null) {
      return Align(
        alignment: AlignmentDirectional.centerStart,
        child: Stack(children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(DS.radius),
            child: Image.file(File(_values.attachmentUri!), width: 110, height: 110, fit: BoxFit.cover),
          ),
          PositionedDirectional(
            top: 4,
            end: 4,
            child: InkWell(
              onTap: () async {
                await deleteAttachment(_values.attachmentUri);
                _update((v) => v.copyWith(clearAttachment: true));
              },
              child: const CircleAvatar(radius: 12, child: Icon(Icons.close, size: 14)),
            ),
          ),
        ]),
      );
    }
    return InkWell(
      onTap: _showAttachmentPicker,
      borderRadius: BorderRadius.circular(DS.radius),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(DS.radius),
          border: Border.all(color: theme.colorScheme.outline),
          color: theme.colorScheme.surface,
        ),
        child: Column(children: [
          Icon(Icons.add_a_photo_outlined, color: theme.colorScheme.primary),
          const SizedBox(height: 6),
          Text('transactions.attachInvoice'.tr(), style: theme.textTheme.bodySmall, textAlign: TextAlign.center),
        ]),
      ),
    );
  }
}
