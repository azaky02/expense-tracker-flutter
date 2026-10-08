import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/tables.dart';
import '../../../core/utils/color_utils.dart';
import '../../../core/widgets/ds_widgets.dart';
import '../data/account_repository.dart';
import 'account_providers.dart';

IconData accountIcon(AccountType t) => switch (t) {
      AccountType.cash => Icons.payments_outlined,
      AccountType.bank => Icons.account_balance_outlined,
      AccountType.creditCard => Icons.credit_card,
      AccountType.debitCard => Icons.credit_card_outlined,
      AccountType.wallet => Icons.account_balance_wallet_outlined,
      AccountType.savings => Icons.savings_outlined,
      AccountType.other => Icons.folder_outlined,
    };

String accountTypeLabel(BuildContext context, AccountType t) => 'accounts.type.${t.name}'.tr(context: context);

class AccountBubble extends StatelessWidget {
  const AccountBubble(this.account, {super.key, this.size = 42});
  final AccountWithBalance account;
  final double size;

  @override
  Widget build(BuildContext context) =>
      IconBubble(icon: accountIcon(account.account.type), color: colorFromHex(account.account.color), size: size);
}

/// Bottom sheet listing active accounts with balances. Returns the chosen account id.
Future<int?> showAccountPicker(BuildContext context, {int? selectedId, int? excludeId, String? title}) {
  return showModalBottomSheet<int>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => Consumer(builder: (ctx, ref, _) {
      final accounts = (ref.watch(accountsProvider).value ?? const <AccountWithBalance>[])
          .where((a) => a.account.id != excludeId)
          .toList();
      return SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.7),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Text(title ?? 'accounts.choose'.tr(context: ctx), style: Theme.of(ctx).textTheme.titleMedium),
              ),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  children: [
                    for (final a in accounts)
                      ListTile(
                        leading: AccountBubble(a, size: 38),
                        title: Text(a.account.name),
                        subtitle: Text(accountTypeLabel(ctx, a.account.type)),
                        trailing: a.account.id == selectedId
                            ? Icon(Icons.check_circle, color: Theme.of(ctx).colorScheme.primary)
                            : AmountText(a.balance, size: 13),
                        onTap: () => Navigator.pop(ctx, a.account.id),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }),
  );
}
