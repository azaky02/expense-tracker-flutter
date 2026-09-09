import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

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
        onPressed: () => context.push('/transactions/add'),
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
              label: 'nav.home'.tr(),
              selected: navigationShell.currentIndex == 0,
              onTap: () => navigationShell.goBranch(0),
            ),
            _NavItem(
              icon: Icons.receipt_long,
              label: 'nav.transactions'.tr(),
              selected: navigationShell.currentIndex == 1,
              onTap: () => navigationShell.goBranch(1),
            ),
            const SizedBox(width: 48), // room for the docked FAB
            _NavItem(
              icon: Icons.credit_card,
              label: 'nav.cards'.tr(),
              selected: navigationShell.currentIndex == 2,
              onTap: () => navigationShell.goBranch(2),
            ),
            _NavItem(
              icon: Icons.settings,
              label: 'nav.settings'.tr(),
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
