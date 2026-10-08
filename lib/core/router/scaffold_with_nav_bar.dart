import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme/ds_tokens.dart';
import '../widgets/ds_widgets.dart';

/// Bottom nav shell for the 4 real tabs (Home/Transactions/Cards/Settings). The center "+"
/// is a floating action button, not a 5th shell branch — it pushes the add-transaction modal.
class ScaffoldWithNavBar extends StatelessWidget {
  const ScaffoldWithNavBar({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddMenu(context),
        child: const Icon(Icons.add),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 8,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _NavItem(
              icon: Icons.home,
              label: 'nav.home'.tr(context: context),
              selected: navigationShell.currentIndex == 0,
              onTap: () => navigationShell.goBranch(0),
            ),
            _NavItem(
              icon: Icons.receipt_long,
              label: 'nav.transactions'.tr(context: context),
              selected: navigationShell.currentIndex == 1,
              onTap: () => navigationShell.goBranch(1),
            ),
            const SizedBox(width: 48), // room for the docked FAB
            _NavItem(
              icon: Icons.people_alt_outlined,
              label: 'nav.people'.tr(context: context),
              selected: navigationShell.currentIndex == 2,
              onTap: () => navigationShell.goBranch(2),
            ),
            _NavItem(
              icon: Icons.more_horiz,
              label: 'nav.more'.tr(context: context),
              selected: navigationShell.currentIndex == 3,
              onTap: () => navigationShell.goBranch(3),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected
        ? Theme.of(context).colorScheme.secondary
        : Theme.of(context).colorScheme.onSurfaceVariant;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 24),
            Text(label, style: TextStyle(color: color, fontSize: 11)),
          ],
        ),
      ),
    );
  }
}

/// The "+" button (UI/UX §4, mockup 7): Expense / Income / Transfer / Transaction with a person /
/// Settlement.
void _showAddMenu(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    builder: (ctx) {
      Widget item(IconData icon, Color color, String label, String hint, String route) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: ListTile(
              leading: IconBubble(icon: icon, color: color, size: 46),
              title: Text(label.tr(context: ctx), style: Theme.of(ctx).textTheme.titleSmall),
              subtitle: Text(hint.tr(context: ctx)),
              onTap: () {
                Navigator.pop(ctx);
                context.push(route);
              },
            ),
          );
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('add.title'.tr(context: ctx), textAlign: TextAlign.center, style: Theme.of(ctx).textTheme.titleMedium),
              const SizedBox(height: 8),
              item(Icons.remove_circle_outline, DS.danger, 'add.expense', 'add.expenseHint', '/transactions/add'),
              item(Icons.add_circle_outline, DS.success, 'add.income', 'add.incomeHint', '/transactions/add?type=income'),
              item(Icons.swap_horiz, const Color(0xFF8B5CF6), 'add.transfer', 'add.transferHint', '/transactions/add?type=transfer'),
              item(Icons.handshake_outlined, DS.warning, 'add.ledger', 'add.ledgerHint', '/ledger/new'),
              item(Icons.payments_outlined, DS.primary, 'add.settlement', 'add.settlementHint', '/ledger/new?kind=settlement'),
              const SizedBox(height: 8),
              OutlinedButton(onPressed: () => Navigator.pop(ctx), child: Text('common.cancel'.tr(context: ctx))),
            ],
          ),
        ),
      );
    },
  );
}
