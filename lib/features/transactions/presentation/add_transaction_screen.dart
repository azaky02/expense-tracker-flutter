import 'dart:math';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/db/tables.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/widgets/ds_widgets.dart';
import '../data/transaction_repository.dart';
import 'transaction_form.dart';
import 'transaction_form_state.dart';
import 'transaction_providers.dart';

class AddTransactionScreen extends ConsumerStatefulWidget {
  const AddTransactionScreen({super.key, this.type = TransactionType.expense});
  final TransactionType type;

  @override
  ConsumerState<AddTransactionScreen> createState() => _AddTransactionScreenState();
}

class _AddTransactionScreenState extends ConsumerState<AddTransactionScreen> {
  bool _isSubmitting = false;
  late final String _submissionKey = List<int>.generate(16, (_) => Random.secure().nextInt(256))
      .map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
  final _form = GlobalKey<TransactionFormState>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: BrandFormAppBar(
        title: switch (widget.type) {
          TransactionType.income => 'transactions.addIncome',
          TransactionType.transfer => 'transactions.addTransfer',
          _ => 'transactions.addExpense',
        }.tr(),
        onSave: () {
          if (!_isSubmitting) _form.currentState?.submit();
        },
      ),
      body: TransactionForm(
        key: _form,
        initialValues: TransactionFormValues(
          amount: 0,
          type: widget.type,
          categoryId: 0,
          paymentMethodType: PaymentMethodType.cash,
          date: todayDateOnly(),
        ),
        submitLabel: 'transactions.saveTransaction'.tr(),
        isSubmitting: _isSubmitting,
        onSubmit: (values) async {
          if (!values.isValid || _isSubmitting) return;
          setState(() => _isSubmitting = true);
          try {
            final input = values.toInput();
            await ref.read(transactionRepositoryProvider).create(TransactionInput(
              amount: input.amount,
              type: input.type,
              categoryId: input.categoryId,
              paymentMethodType: input.paymentMethodType,
              cardId: input.cardId,
              date: input.date,
              note: input.note,
              attachmentUri: input.attachmentUri,
              beneficiaryName: input.beneficiaryName,
              accountId: input.accountId,
              toAccountId: input.toAccountId,
              idempotencyKey: _submissionKey,
            ));
            if (context.mounted) context.pop();
          } on Object {
            if (mounted) {
              ScaffoldMessenger.of(this.context).showSnackBar(
                const SnackBar(content: Text('Could not save transaction. Please retry.')),
              );
            }
          } finally {
            if (mounted) setState(() => _isSubmitting = false);
          }
        },
      ),
    );
  }
}
