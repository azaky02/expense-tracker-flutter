import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/settings/settings_provider.dart';
import '../../../core/settings/settings_state.dart';
import '../../../core/theme/ds_tokens.dart';
import '../../../core/utils/color_utils.dart';
import '../../../core/widgets/ds_widgets.dart';
import '../../cars/presentation/cars_screens.dart';
import '../../people/presentation/people_screen.dart';
import '../../transactions/data/transaction_models.dart';
import '../../transactions/presentation/widgets/transaction_tile.dart';

/// Hides the amounts on the balance card (eye button).
class BalanceHiddenNotifier extends Notifier<bool> {
  @override
  bool build() => false;
  void toggle() => state = !state;
}

final balanceHiddenProvider = NotifierProvider<BalanceHiddenNotifier, bool>(BalanceHiddenNotifier.new);

/// Thin gold arcs drawn over the green header (decoration only).
class _GoldSwoosh extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..shader = const LinearGradient(colors: [Color(0x00C9A13B), Color(0xCCE9CB73), Color(0x00C9A13B)]).createShader(Offset.zero & size);
    for (var i = 0; i < 3; i++) {
      final path = Path()
        ..moveTo(size.width * 0.15, size.height * (0.15 + i * 0.07))
        ..quadraticBezierTo(size.width * 0.75, size.height * (0.05 + i * 0.06), size.width * 1.05, size.height * (0.45 + i * 0.08));
      canvas.drawPath(path, paint..strokeWidth = 1.4 - i * 0.35);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Green header with avatar, greeting and today's date, plus the balance card overlapping it.
class HomeHeader extends ConsumerWidget {
  const HomeHeader({super.key, required this.total});
  final double total;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final hidden = ref.watch(balanceHiddenProvider);
    final lang = context.locale.languageCode;
    final now = DateTime.now();
    final name = settings.userName;
    final top = MediaQuery.of(context).padding.top;
    Widget circleButton(IconData icon, VoidCallback onTap) => Material(
      color: Colors.white.withValues(alpha: 0.12),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(9),
          child: Icon(icon, color: Colors.white, size: 21),
        ),
      ),
    );
    return Stack(
      children: [
        Container(
          height: top + 200,
          decoration: const BoxDecoration(
            gradient: DS.navyGradient,
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(30)),
          ),
          child: CustomPaint(painter: _GoldSwoosh(), size: Size.infinite),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(16, top + 10, 16, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(2),
                    decoration: const BoxDecoration(shape: BoxShape.circle, gradient: DS.goldGradient),
                    child: PersonAvatar(name: name.isEmpty ? '؟' : name, color: DS.primary, size: 46),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name.isEmpty ? 'dashboard.greetingGeneric'.tr() : 'home.hello'.tr(namedArgs: {'name': name}),
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w800),
                        ),
                        Text(DateFormat.yMMMMEEEEd(lang).format(now), style: const TextStyle(color: Colors.white70, fontSize: 12)),
                      ],
                    ),
                  ),
                  circleButton(Icons.search, () => context.go('/transactions')),
                  const SizedBox(width: 8),
                  const IconTheme(
                    data: IconThemeData(color: Colors.white),
                    child: NotificationsBell(),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Balance card.
              Container(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                decoration: BoxDecoration(
                  gradient: DS.heroGradient,
                  borderRadius: BorderRadius.circular(DS.radiusLg),
                  border: Border.all(color: DS.gold.withValues(alpha: 0.7), width: 1.2),
                  boxShadow: const [BoxShadow(color: Color(0x330A3B28), blurRadius: 20, offset: Offset(0, 8))],
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'dashboard.totalBalance'.tr(),
                                style: const TextStyle(color: DS.goldLight, fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 4),
                              hidden
                                  ? const Text(
                                      '••••••',
                                      style: TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w800, letterSpacing: 4),
                                    )
                                  : AmountText(total, color: Colors.white, size: 30, weight: FontWeight.w800),
                            ],
                          ),
                        ),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Image.asset('assets/icon/app_icon.png', width: 76, height: 76, fit: BoxFit.cover),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        InkWell(
                          onTap: () => ref.read(balanceHiddenProvider.notifier).toggle(),
                          borderRadius: BorderRadius.circular(20),
                          child: Padding(
                            padding: const EdgeInsets.all(4),
                            child: Icon(
                              hidden ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                              color: Colors.white70,
                              size: 20,
                            ),
                          ),
                        ),
                        const Spacer(),
                        const Icon(Icons.refresh, color: Colors.white54, size: 14),
                        const SizedBox(width: 4),
                        Text(
                          'home.lastUpdate'.tr(namedArgs: {'time': DateFormat.yMMMd(lang).add_Hm().format(now)}),
                          style: const TextStyle(color: Colors.white60, fontSize: 11),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Main actions: expense, income, transfer / car, loan, installments, and "more".
class HomeActions extends ConsumerWidget {
  const HomeActions({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Widget tile(IconData icon, String label, Color bg, Color fg, VoidCallback onTap) => Expanded(
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Material(
          color: bg,
          borderRadius: BorderRadius.circular(16),
          elevation: 2,
          shadowColor: bg.withValues(alpha: 0.4),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: onTap,
            child: SizedBox(
              height: 78,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, color: fg, size: 28),
                  const SizedBox(height: 4),
                  Text(
                    label,
                    maxLines: 2,
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: fg, fontWeight: FontWeight.w700, fontSize: 12, height: 1.1),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    final settings = ref.watch(settingsProvider);
    final surface = Theme.of(context).colorScheme.surface;
    final onSurface = Theme.of(context).colorScheme.primary;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            flex: 3,
            child: Column(
              children: [
                Row(
                  children: [
                    tile(
                      Icons.south_rounded,
                      'add.expense'.tr(),
                      const Color(0xFFE5484D),
                      Colors.white,
                      () => context.push('/transactions/add'),
                    ),
                    tile(
                      Icons.north_rounded,
                      'add.income'.tr(),
                      DS.primary,
                      Colors.white,
                      () => context.push('/transactions/add?type=income'),
                    ),
                    tile(
                      Icons.swap_horiz_rounded,
                      'add.transfer'.tr(),
                      const Color(0xFF2563EB),
                      Colors.white,
                      () => context.push('/transactions/add?type=transfer'),
                    ),
                  ],
                ),
                Row(
                  children: [
                    if (settings.moduleShown(AppModule.cars.key))
                      tile(
                        Icons.directions_car_filled_rounded,
                        'cars.car'.tr(),
                        const Color(0xFFF6E7C4),
                        const Color(0xFF7A5A12),
                        () => startCarExpense(context, ref),
                      ),
                    if (settings.moduleShown(AppModule.installments.key))
                      tile(
                        Icons.account_balance_rounded,
                        'home.loansAndInstallments'.tr(),
                        const Color(0xFFE9DDF8),
                        const Color(0xFF6D28D9),
                        () => context.push('/installments'),
                      ),
                    if (settings.moduleShown(AppModule.associations.key))
                      tile(
                        Icons.groups_2_rounded,
                        'home.association'.tr(),
                        const Color(0xFFF59E0B),
                        Colors.white,
                        () => context.push('/associations'),
                      ),
                    if (!settings.moduleShown(AppModule.cars.key) &&
                        !settings.moduleShown(AppModule.installments.key) &&
                        !settings.moduleShown(AppModule.associations.key))
                      tile(Icons.insights_rounded, 'stats.title'.tr(), const Color(0xFFDDEFE6), DS.primary, () => context.push('/stats')),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(4),
            child: Material(
              color: surface,
              borderRadius: BorderRadius.circular(16),
              elevation: 2,
              shadowColor: Colors.black26,
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => showHomeMoreSheet(context),
                child: SizedBox(
                  width: 74,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.grid_view_rounded, color: onSurface, size: 28),
                      const SizedBox(height: 4),
                      Text(
                        'home.more'.tr(),
                        style: TextStyle(color: onSurface, fontWeight: FontWeight.w700, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Every other section, from the "more" tile.
void showHomeMoreSheet(BuildContext context) {
  final container = ProviderScope.containerOf(context, listen: false);
  final st = container.read(settingsProvider);
  bool on(AppModule m) => st.moduleEnabled(m.key);
  final items = <(IconData, String, String)>[
    if (on(AppModule.stats)) (Icons.insights_rounded, 'stats.title', '/stats'),
    if (on(AppModule.installments)) (Icons.account_balance_rounded, 'home.loansAndInstallments', '/installments'),
    if (on(AppModule.associations)) (Icons.groups_2_outlined, 'associations.title', '/associations'),
    if (on(AppModule.custody)) (Icons.handshake_outlined, 'home.loan', '/ledger/new'),
    if (on(AppModule.custody)) (Icons.people_alt_outlined, 'nav.people', '/people'),
    if (on(AppModule.cars)) (Icons.directions_car_filled_outlined, 'home.myCars', '/cars'),
    if (on(AppModule.cars)) (Icons.local_gas_station_outlined, 'fuel.title', '/fuel-prices'),
    if (on(AppModule.accounts)) (Icons.account_balance_wallet_outlined, 'accounts.title', '/accounts'),
    if (on(AppModule.budgets)) (Icons.pie_chart_outline_rounded, 'home.budgets', '/budgets'),
    if (on(AppModule.reports)) (Icons.bar_chart_rounded, 'reports.title', '/reports'),
    (Icons.dashboard_customize_outlined, 'modules.title', '/modules'),
  ];
  showModalBottomSheet<void>(
    context: context,
    builder: (ctx) {
      final theme = Theme.of(ctx);
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          child: GridView.count(
            crossAxisCount: 4,
            shrinkWrap: true,
            childAspectRatio: 0.9,
            children: [
              for (final (icon, label, route) in items)
                InkWell(
                  borderRadius: BorderRadius.circular(DS.radius),
                  onTap: () {
                    Navigator.pop(ctx);
                    if (route == '/people') {
                      context.go(route);
                    } else {
                      context.push(route);
                    }
                  },
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(15),
                          border: Border.all(color: DS.gold.withValues(alpha: 0.4)),
                        ),
                        child: Icon(icon, color: theme.colorScheme.primary),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        label.tr(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      );
    },
  );
}

/// "This month": income, expenses and net in three cards.
class MonthSummaryRow extends StatelessWidget {
  const MonthSummaryRow({super.key, required this.income, required this.expense});
  final double income;
  final double expense;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    Widget card(IconData icon, String label, double value, Color color) => Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(DS.radius),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 2),
            FittedBox(
              child: AmountText(value, size: 17, color: color, weight: FontWeight.w800),
            ),
          ],
        ),
      ),
    );
    return Row(
      children: [
        card(Icons.bar_chart_rounded, 'dashboard.income'.tr(), income, scheme.secondary),
        card(Icons.pie_chart_rounded, 'dashboard.expenses'.tr(), expense, scheme.error),
        card(Icons.trending_up_rounded, 'home.net'.tr(), income - expense, const Color(0xFF2563EB)),
      ],
    );
  }
}

/// Recent transactions with a coloured category square, time and date, amount and a chevron.
class HomeTransactionRow extends StatelessWidget {
  const HomeTransactionRow({super.key, required this.item, required this.onTap});
  final TransactionWithDetails item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = item.transaction;
    final theme = Theme.of(context);
    final (amount, color) = signedAmount(context, item);
    final lang = context.locale.languageCode;
    final title = (t.beneficiaryName?.isNotEmpty ?? false) ? t.beneficiaryName! : item.categoryName;
    final when = DateFormat.yMd(lang).format(t.date);
    final created = DateFormat.Hm(lang).format(t.createdAt.toLocal());
    final catColor = colorFromHex(item.categoryColor);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(DS.radius),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(color: catColor.withValues(alpha: 0.9), borderRadius: BorderRadius.circular(12)),
              alignment: Alignment.center,
              child: Text(item.categoryIcon, style: const TextStyle(fontSize: 20)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.titleSmall),
                  Text(
                    '$created - $when · ${item.categoryPath}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            AmountText(amount, color: color, size: 15, signed: true),
            Icon(Icons.chevron_right, color: theme.colorScheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}
