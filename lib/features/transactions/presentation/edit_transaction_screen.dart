import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/attachments.dart';
import 'transaction_form.dart';
import 'transaction_form_state.dart';
import 'transaction_providers.dart';

class EditTransactionScreen extends ConsumerStatefulWidget {
  const EditTransactionScreen({super.key, required this.transactionId});
  final int transactionId;

  @override
  ConsumerState<EditTransactionScreen> createState() => _EditTransactionScreenState();
}

class _EditTransactionScreenState extends ConsumerState<EditTransactionScreen> {
  bool _isSubmitting = false;

  Future<void> _handleDelete(String? attachmentUri) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        content: Text('common.delete'.tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('common.cancel'.tr()),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('common.delete'.tr(), style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await deleteAttachment(attachmentUri);
    await ref.read(transactionRepositoryProvider).delete(widget.transactionId);
    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final transactionAsync = ref.watch(transactionByIdProvider(widget.transactionId));

    return Scaffold(
      appBar: AppBar(
        title: Text('common.edit'.tr()),
        actions: [
          transactionAsync.maybeWhen(
            data: (t) => IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: () => _handleDelete(t?.transaction.attachmentUri),
            ),
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
      body: transactionAsync.when(
        data: (t) {
          if (t == null) return const SizedBox.shrink();
          return TransactionForm(
            initialValues: TransactionFormValues(
              amount: t.transaction.amount,
              type: t.transaction.type,
              categoryId: t.transaction.categoryId,
              paymentMethodType: t.transaction.paymentMethodType,
              cardId: t.transaction.cardId,
              date: t.transaction.date,
              note: t.transaction.note,
              attachmentUri: t.transaction.attachmentUri,
              beneficiaryName: t.transaction.beneficiaryName,
            ),
            submitLabel: 'common.save'.tr(),
            isSubmitting: _isSubmitting,
            onSubmit: (values) async {
              if (!values.isValid) return;
              setState(() => _isSubmitting = true);
              try {
                await ref
                    .read(transactionRepositoryProvider)
                    .update(widget.transactionId, values.toInput());
                if (context.mounted) context.pop();
              } finally {
                if (mounted) setState(() => _isSubmitting = false);
              }
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('$e')),
      ),
    );
  }
}
