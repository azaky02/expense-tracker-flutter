import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/db/tables.dart';
import '../../../core/theme/ds_tokens.dart';
import '../../../core/widgets/ds_widgets.dart';
import '../../transactions/data/transaction_models.dart';
import '../../transactions/data/transaction_repository.dart';
import '../../transactions/presentation/transaction_providers.dart';
import '../../transactions/presentation/widgets/transaction_tile.dart';
import 'account_providers.dart';
import 'account_widgets.dart';

/// Accounts (UI/UX §13, mockup 14): total, each account with its balance, add a new one.
class AccountsScreen extends ConsumerWidget {
  const AccountsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(accountsProvider);
    final total = ref.watch(totalBalanceProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text('accounts.title'.tr()),
        actions: [IconButton(onPressed: () => context.push('/transactions/add?type=transfer'), icon: const Icon(Icons.swap_horiz))],
      ),
      body: async.when(
        loading: () => const Padding(padding: EdgeInsets.all(16), child: SkeletonList()),
        error: (e, _) => ErrorState(message: 'common.loadError'.tr(), onRetry: () => ref.invalidate(accountsProvider)),
        data: (accounts) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            AppCard(
              child: Column(children: [
                Text('accounts.total'.tr(), style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                const SizedBox(height: 4),
                AmountText(total, size: 28, weight: FontWeight.w800),
              ]),
            ),
            const SizedBox(height: 12),
            for (final a in accounts)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: AppCard(
                  onTap: () => context.push(a.account.cardId != null ? '/cards/${a.account.cardId}' : '/accounts/${a.account.id}'),
                  child: Row(children: [
                    AccountBubble(a, size: 46),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(a.account.name, style: Theme.of(context).textTheme.titleSmall),
                        Text(accountTypeLabel(context, a.account.type), style: Theme.of(context).textTheme.bodySmall),
                      ]),
                    ),
                    AmountText(a.balance, size: 16, color: a.balance < 0 ? Theme.of(context).colorScheme.error : null),
                  ]),
                ),
              ),
            const SizedBox(height: 4),
            OutlinedButton.icon(
              onPressed: () => _addAccount(context),
              icon: const Icon(Icons.add_circle_outline),
              label: Text('accounts.add'.tr()),
            ),
          ],
        ),
      ),
    );
  }

  /// Card types go through the card form (bank, last 4 digits, due date); others use the account form.
  Future<void> _addAccount(BuildContext context) async {
    final type = await showModalBottomSheet<AccountType>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          for (final t in AccountType.values)
            ListTile(
              leading: IconBubble(icon: accountIcon(t), color: DS.palette[t.index % DS.palette.length], size: 36),
              title: Text(accountTypeLabel(ctx, t)),
              onTap: () => Navigator.pop(ctx, t),
            ),
        ]),
      ),
    );
    if (type == null || !context.mounted) return;
    if (type == AccountType.creditCard || type == AccountType.debitCard) {
      context.push('/cards/add');
    } else {
      context.push('/accounts/new?type=${type.name}');
    }
  }
}

/// One non-card account: balance, details, recent transactions (UI/UX §13).
class AccountDetailsScreen extends ConsumerWidget {
  const AccountDetailsScreen({super.key, required this.accountId});
  final int accountId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final a = ref.watch(accountProvider(accountId)).value;
    final items = ref.watch(transactionsListProvider(TransactionFilters(accountId: accountId))).value ?? const <TransactionWithDetails>[];
    if (a == null) return Scaffold(appBar: AppBar());
    return Scaffold(
      appBar: AppBar(
        title: Text(a.account.name),
        actions: [IconButton(onPressed: () => context.push('/accounts/$accountId/edit'), icon: const Icon(Icons.edit_outlined))],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          AppCard(
            child: Row(children: [
              AccountBubble(a, size: 52),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('accounts.currentBalance'.tr(), style: Theme.of(context).textTheme.bodySmall),
                  AmountText(a.balance, size: 26, weight: FontWeight.w800, color: a.balance < 0 ? Theme.of(context).colorScheme.error : null),
                  Text('${accountTypeLabel(context, a.account.type)} · ${'accounts.opening'.tr()}: ${a.account.openingBalance.toStringAsFixed(0)}',
                      style: Theme.of(context).textTheme.bodySmall),
                ]),
              ),
            ]),
          ),
          SectionHeader('dashboard.recentTransactions'.tr()),
          if (items.isEmpty)
            AppCard(child: EmptyState(icon: Icons.receipt_long_outlined, title: 'accounts.noTransactions'.tr()))
          else
            AppCard(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: Column(children: [
                for (final t in items.take(50))
                  TransactionTile(item: t, showDate: true, onTap: () => context.push('/transactions/${t.transaction.id}/edit')),
              ]),
            ),
        ],
      ),
    );
  }
}

/// Add / edit a non-card account.
class AccountFormScreen extends ConsumerStatefulWidget {
  const AccountFormScreen({super.key, this.accountId, this.type = AccountType.bank});
  final int? accountId;
  final AccountType type;

  @override
  ConsumerState<AccountFormScreen> createState() => _AccountFormScreenState();
}

class _AccountFormScreenState extends ConsumerState<AccountFormScreen> {
  final _name = TextEditingController();
  final _opening = TextEditingController();
  late AccountType _type = widget.type;
  bool _loaded = false;
  bool _active = true;

  @override
  void dispose() {
    _name.dispose();
    _opening.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) return;
    final opening = double.tryParse(_opening.text.replaceAll(',', '')) ?? 0;
    final repo = ref.read(accountRepositoryProvider);
    if (widget.accountId == null) {
      await repo.create(name: name, type: _type, openingBalance: opening);
    } else {
      await repo.update(widget.accountId!, name: name, openingBalance: opening);
    }
    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.accountId != null && !_loaded) {
      final a = ref.watch(accountProvider(widget.accountId!)).value;
      if (a != null) {
        _name.text = a.account.name;
        _opening.text = a.account.openingBalance == 0 ? '' : a.account.openingBalance.toString();
        _type = a.account.type;
        _active = a.account.isActive;
        _loaded = true;
      }
    }
    return Scaffold(
      appBar: AppBar(title: Text((widget.accountId == null ? 'accounts.add' : 'accounts.edit').tr())),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Center(child: IconBubble(icon: accountIcon(_type), color: DS.palette[_type.index % DS.palette.length], size: 64)),
          const SizedBox(height: 8),
          Center(child: Text(accountTypeLabel(context, _type), style: Theme.of(context).textTheme.titleSmall)),
          FieldLabel('accounts.name'.tr()),
          TextField(controller: _name, autofocus: widget.accountId == null, decoration: InputDecoration(hintText: 'accounts.nameHint'.tr())),
          FieldLabel('accounts.opening'.tr()),
          AmountField(controller: _opening),
          const SizedBox(height: 24),
          FilledButton(onPressed: _save, child: Text('common.save'.tr())),
          if (widget.accountId != null && _type != AccountType.cash) ...[
            const SizedBox(height: 8),
            TextButton(
              onPressed: () async {
                await ref.read(accountRepositoryProvider).setActive(widget.accountId!, !_active);
                if (context.mounted) context.go('/accounts');
              },
              child: Text((_active ? 'accounts.archive' : 'accounts.unarchive').tr()),
            ),
          ],
        ],
      ),
    );
  }
}
