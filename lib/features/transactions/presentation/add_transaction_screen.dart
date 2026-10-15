import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/db/tables.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/widgets/ds_widgets.dart';
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
        onSave: () => _form.currentState?.submit(),
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
          if (!values.isValid) return;
          setState(() => _isSubmitting = true);
          try {
            await ref.read(transactionRepositoryProvider).create(values.toInput());
            if (context.mounted) context.pop();
          } finally {
            if (mounted) setState(() => _isSubmitting = false);
          }
        },
      ),
    );
  }
}
