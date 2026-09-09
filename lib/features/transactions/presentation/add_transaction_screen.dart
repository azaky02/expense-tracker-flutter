import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/db/tables.dart';
import '../../../core/utils/date_utils.dart';
import 'transaction_form.dart';
import 'transaction_form_state.dart';
import 'transaction_providers.dart';

class AddTransactionScreen extends ConsumerStatefulWidget {
  const AddTransactionScreen({super.key});

  @override
  ConsumerState<AddTransactionScreen> createState() => _AddTransactionScreenState();
}

class _AddTransactionScreenState extends ConsumerState<AddTransactionScreen> {
  bool _isSubmitting = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('transactions.addTitle'.tr())),
      body: TransactionForm(
        initialValues: TransactionFormValues(
          amount: 0,
          type: TransactionType.expense,
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
