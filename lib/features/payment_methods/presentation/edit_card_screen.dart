import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'card_form.dart';
import 'card_form_state.dart';
import 'payment_method_providers.dart';

class EditCardScreen extends ConsumerStatefulWidget {
  const EditCardScreen({super.key, required this.cardId});
  final int cardId;

  @override
  ConsumerState<EditCardScreen> createState() => _EditCardScreenState();
}

class _EditCardScreenState extends ConsumerState<EditCardScreen> {
  bool _isSubmitting = false;

  @override
  Widget build(BuildContext context) {
    final cardAsync = ref.watch(cardByIdProvider(widget.cardId));

    return Scaffold(
      appBar: AppBar(title: Text('cards.editCard'.tr())),
      body: cardAsync.when(
        data: (c) {
          if (c == null) return const SizedBox.shrink();
          return CardForm(
            initialValues: CardFormValues(
              bankId: c.card.bankId,
              cardType: c.card.cardType,
              cardCategory: c.card.cardCategory,
              nickname: c.card.nickname,
              last4Digits: c.card.last4Digits,
              dueDateDay: c.card.dueDateDay,
              statementDateDay: c.card.statementDateDay,
              creditLimit: c.card.creditLimit,
            ),
            submitLabel: 'common.save'.tr(),
            isSubmitting: _isSubmitting,
            onSubmit: (values) async {
              setState(() => _isSubmitting = true);
              try {
                await ref.read(cardRepositoryProvider).update(
                      widget.cardId,
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
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('$e')),
      ),
    );
  }
}
