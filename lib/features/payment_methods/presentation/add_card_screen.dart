import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/db/tables.dart';
import 'card_form.dart';
import 'card_form_state.dart';
import 'payment_method_providers.dart';

class AddCardScreen extends ConsumerStatefulWidget {
  const AddCardScreen({super.key});

  @override
  ConsumerState<AddCardScreen> createState() => _AddCardScreenState();
}

class _AddCardScreenState extends ConsumerState<AddCardScreen> {
  bool _isSubmitting = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('cards.addNewCard'.tr())),
      body: CardForm(
        initialValues: const CardFormValues(
          bankId: null,
          cardType: CardType.visa,
          cardCategory: CardCategory.credit,
          nickname: '',
          last4Digits: '',
        ),
        submitLabel: 'common.save'.tr(),
        isSubmitting: _isSubmitting,
        onSubmit: (values) async {
          setState(() => _isSubmitting = true);
          try {
            await ref.read(cardRepositoryProvider).create(
                  bankId: values.bankId!,
                  cardType: values.cardType,
                  cardCategory: values.cardCategory,
                  nickname: values.nickname.trim(),
                  last4Digits: values.last4Digits,
                  dueDateDay: values.dueDateDay,
                  statementDateDay: values.statementDateDay,
                  creditLimit: values.creditLimit,
                );
            if (context.mounted) context.pop();
          } finally {
            if (mounted) setState(() => _isSubmitting = false);
          }
        },
      ),
    );
  }
}
