import 'dart:ui' as ui;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/db/database.dart' show unreadableDbRecoveredKey;
import '../../../core/db/tables.dart';
import '../../../core/security/lock_provider.dart';
import '../../../core/security/secure_storage.dart';
import '../../../core/settings/settings_provider.dart';
import '../../../core/settings/settings_state.dart';
import '../../../core/theme/ds_tokens.dart';
import '../../../core/utils/currency.dart';
import '../../../core/widgets/ds_widgets.dart';
import '../../accounts/presentation/account_providers.dart';
import '../../cars/data/car_repository.dart';
import '../../installments/data/installment_reminders.dart';
import '../../lock/presentation/pin_entry_screen.dart';
import 'auth_screens.dart';

enum SetupLock { pin, biometrics }

final biometricsAvailableProvider = FutureProvider<bool>((ref) async {
  final auth = LocalAuthentication();
  try {
    return await auth.isDeviceSupported() && await auth.canCheckBiometrics;
  } catch (_) {
    return false;
  }
});

/// Egyptian mobile (01xxxxxxxxx) or an international number (+ and 8-15 digits).
bool isValidPhone(String raw) {
  final s = raw.replaceAll(RegExp(r'[\s\-()]'), '');
  return RegExp(r'^01[0125]\d{8}$').hasMatch(s) || RegExp(r'^\+?\d{8,15}$').hasMatch(s);
}

bool isValidEmail(String s) => RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]{2,}$').hasMatch(s.trim());

const recoveryQuestions = ['wizard.q.mother', 'wizard.q.school', 'wizard.q.friend', 'wizard.q.city', 'wizard.q.custom'];

/// An extra account added in the wizard.
class _NewAccount {
  _NewAccount(this.name, this.type, this.balance);
  final String name;
  final AccountType type;
  final double balance;
}

/// First-run wizard (after the welcome screen): language → your details → protection → recovery
/// question → accounts → salary → sections → car → reminders → done. Steps after protection can be
/// skipped and changed later in Settings.
class SetupScreen extends ConsumerStatefulWidget {
  const SetupScreen({super.key});

  @override
  ConsumerState<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends ConsumerState<SetupScreen> {
  static const _steps = 10;
  final _page = PageController();
  int _step = 0;
  bool _busy = false;
  String? _error;
  bool _recovered = false;
  bool _protected = false;

  // Details.
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  // Protection.
  SetupLock _lock = SetupLock.pin;
  // Recovery.
  String _questionKey = recoveryQuestions.first;
  final _customQuestion = TextEditingController();
  final _answer = TextEditingController();
  // Accounts.
  final _cash = TextEditingController();
  final _extra = <_NewAccount>[];
  // Salary.
  int _salaryDay = 0;
  final _salaryAmount = TextEditingController();
  // Car.
  final _carName = TextEditingController();
  final _carBrand = TextEditingController();
  final _carYear = TextEditingController();
  // Reminders.
  bool _daily = true;

  @override
  void initState() {
    super.initState();
    final s = ref.read(settingsProvider);
    _name.text = s.userName;
    _phone.text = s.userPhone;
    _email.text = s.userEmail;
    SharedPreferences.getInstance().then((p) {
      if (mounted && (p.getBool(unreadableDbRecoveredKey) ?? false)) setState(() => _recovered = true);
    });
  }

  @override
  void dispose() {
    for (final c in [_name, _phone, _email, _customQuestion, _answer, _cash, _salaryAmount, _carName, _carBrand, _carYear]) {
      c.dispose();
    }
    _page.dispose();
    super.dispose();
  }

  void _go(int step) {
    setState(() {
      _error = null;
      _step = step.clamp(0, _steps - 1);
    });
    _page.animateToPage(_step, duration: const Duration(milliseconds: 280), curve: Curves.easeOut);
  }

  bool get _canSkip => _step >= 3 && _step < _steps - 1;

  // ---------------------------------------------------------------------------------------------
  // Step actions

  Future<void> _next() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final settings = ref.read(settingsProvider.notifier);
      switch (_step) {
        case 1:
          final phone = asciiDigits(_phone.text).replaceAll(RegExp(r'[\s\-()]'), '');
          if (_name.text.trim().length < 2) return _fail('wizard.needName');
          if (!isValidPhone(phone)) return _fail('setup.phoneInvalid');
          if (_email.text.trim().isNotEmpty && !isValidEmail(_email.text)) return _fail('wizard.badEmail');
          await settings.setUserName(_name.text.trim());
          await settings.setUserPhone(phone);
          await settings.setUserEmail(_email.text.trim());
        case 2:
          if (!await _protect()) return;
        case 3:
          final q = _questionKey == 'wizard.q.custom' ? _customQuestion.text.trim() : _questionKey.tr();
          if (q.isEmpty || _answer.text.trim().length < 2) return _fail('wizard.needAnswer');
          await SecureStorageService.instance.setRecovery(q, _answer.text);
        case 4:
          await _saveAccounts();
        case 5:
          await settings.setSalaryDay(_salaryDay);
          await settings.setSalaryAmount(_salaryDay == 0 ? 0 : parseAmount(_salaryAmount.text));
        case 7:
          final year = int.tryParse(asciiDigits(_carYear.text)) ?? 0;
          if (_carName.text.trim().isNotEmpty || _carBrand.text.trim().isNotEmpty) {
            if (_carName.text.trim().isEmpty || _carBrand.text.trim().isEmpty || year < 1950) return _fail('wizard.needCar');
            await ref.read(carRepositoryProvider).createCar(name: _carName.text.trim(), brand: _carBrand.text.trim(), modelYear: year);
          }
        case 8:
          await settings.setDailyReminder(_daily);
          if (_daily) await InstallmentReminders.instance.requestPermission();
        case 9:
          (await SharedPreferences.getInstance()).remove(unreadableDbRecoveredKey);
          ref.read(lockProvider.notifier).unlock();
          // Router redirect takes the user to Home once onboarding is complete.
          await settings.completeOnboarding();
          return;
      }
      var next = _step + 1;
      // No car step when the car section is switched off.
      if (next == 7 && !ref.read(settingsProvider).moduleEnabled(AppModule.cars.key)) next = 8;
      _go(next);
    } catch (e) {
      _fail('wizard.failed');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _skip() {
    var next = _step + 1;
    if (next == 7 && !ref.read(settingsProvider).moduleEnabled(AppModule.cars.key)) next = 8;
    _go(next);
  }

  void _fail(String key) {
    if (mounted) setState(() => _error = key.tr());
  }

  Future<bool> _protect() async {
    final store = SecureStorageService.instance;
    if (_lock == SetupLock.pin) {
      String? error;
      while (true) {
        final first = await askPin(context, title: 'security.setupPin'.tr(), subtitle: 'security.setupPinHint'.tr(), error: error);
        if (first == null || !mounted) return false;
        final second = await askPin(context, title: 'security.confirmPin'.tr());
        if (second == null || !mounted) return false;
        if (first == second) {
          await store.setPin(first);
          break;
        }
        error = 'security.pinMismatch'.tr();
      }
    } else {
      final ok = await LockNotifier.runWithoutLock(
        () => LocalAuthentication().authenticate(localizedReason: 'setup.biometricsReason'.tr()),
      );
      if (!ok) {
        _fail('security.biometricsFailed');
        return false;
      }
      await store.clearPin();
    }
    final settings = ref.read(settingsProvider.notifier);
    await settings.setBiometricEnabled(_lock == SetupLock.biometrics);
    await settings.setAppLockEnabled(true);
    ref.read(lockProvider.notifier).unlock();
    _protected = true;
    return true;
  }

  Future<void> _saveAccounts() async {
    final repo = ref.read(accountRepositoryProvider);
    final accounts = await repo.watchAccounts().first;
    final cash = accounts.where((a) => a.account.type == AccountType.cash).firstOrNull;
    final opening = parseAmount(_cash.text);
    if (cash != null && opening != 0) {
      await repo.update(cash.account.id, name: cash.account.name, openingBalance: opening);
    }
    for (final a in _extra) {
      await repo.create(name: a.name, type: a.type, openingBalance: a.balance);
    }
    _extra.clear();
  }

  Future<void> _addAccount() async {
    final name = TextEditingController();
    final balance = TextEditingController();
    var type = AccountType.bank;
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + MediaQuery.of(ctx).viewInsets.bottom),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('wizard.addAccount'.tr(), style: Theme.of(ctx).textTheme.titleMedium),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final t in [
                      AccountType.bank,
                      AccountType.creditCard,
                      AccountType.debitCard,
                      AccountType.wallet,
                      AccountType.savings,
                    ])
                      ChoiceChip(
                        label: Text('accounts.type.${t.name}'.tr()),
                        selected: type == t,
                        onSelected: (_) => setSheet(() => type = t),
                      ),
                  ],
                ),
                FieldLabel('accounts.name'.tr()),
                TextField(
                  controller: name,
                  decoration: const InputDecoration(hintText: 'CIB'),
                ),
                FieldLabel('wizard.openingBalance'.tr()),
                AmountField(compact: true, controller: balance),
                const SizedBox(height: 16),
                FilledButton(onPressed: () => Navigator.pop(ctx, name.text.trim().isNotEmpty), child: Text('common.add'.tr())),
              ],
            ),
          ),
        ),
      ),
    );
    if (ok == true) setState(() => _extra.add(_NewAccount(name.text.trim(), type, parseAmount(balance.text))));
  }

  // ---------------------------------------------------------------------------------------------
  // Pages

  Widget _pageShell({required IconData icon, required String title, String? subtitle, required List<Widget> children}) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      children: [
        Center(
          child: IconBubble(icon: icon, color: DS.primary, size: 64),
        ),
        const SizedBox(height: 12),
        Text(title, textAlign: TextAlign.center, style: theme.textTheme.titleLarge),
        if (subtitle != null) ...[
          const SizedBox(height: 4),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
        const SizedBox(height: 12),
        ...children,
      ],
    );
  }

  Widget _language() {
    final current = context.locale.languageCode;
    Widget option(String code, String label) => AppCard(
      margin: const EdgeInsets.only(bottom: 10),
      color: current == code ? Theme.of(context).colorScheme.primaryContainer : null,
      onTap: () async {
        await ref.read(settingsProvider.notifier).setLanguage(code);
        if (mounted) await context.setLocale(Locale(code));
      },
      child: Row(
        children: [
          Text(label, style: Theme.of(context).textTheme.titleMedium),
          const Spacer(),
          Icon(current == code ? Icons.radio_button_checked : Icons.radio_button_off, color: DS.primary),
        ],
      ),
    );
    return _pageShell(
      icon: Icons.translate,
      title: 'wizard.languageTitle'.tr(),
      children: [option('ar', 'العربية'), option('en', 'English')],
    );
  }

  Widget _details() {
    final theme = Theme.of(context);
    return _pageShell(
      icon: Icons.person_outline,
      title: 'wizard.detailsTitle'.tr(),
      subtitle: 'setup.subtitle'.tr(),
      children: [
        if (_recovered)
          AppCard(
            color: DS.warningSoft,
            child: Text('setup.recoveredNotice'.tr(), style: theme.textTheme.bodySmall?.copyWith(color: DS.text)),
          ),
        FieldLabel('setup.name'.tr()),
        TextField(
          controller: _name,
          decoration: InputDecoration(hintText: 'setup.nameHint'.tr(), prefixIcon: const Icon(Icons.person_outline)),
        ),
        FieldLabel('setup.phone'.tr()),
        TextField(
          controller: _phone,
          keyboardType: TextInputType.phone,
          inputFormatters: [
            const AsciiDigitsFormatter(),
            FilteringTextInputFormatter.allow(RegExp(r'[0-9+\s\-]')),
            LengthLimitingTextInputFormatter(16),
          ],
          textDirection: ui.TextDirection.ltr,
          decoration: const InputDecoration(hintText: '01xxxxxxxxx', prefixIcon: Icon(Icons.phone_iphone)),
        ),
        FieldLabel('wizard.email'.tr()),
        TextField(
          controller: _email,
          keyboardType: TextInputType.emailAddress,
          textDirection: ui.TextDirection.ltr,
          decoration: const InputDecoration(hintText: 'name@example.com', prefixIcon: Icon(Icons.mail_outline)),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text('wizard.emailHint'.tr(), style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        ),
      ],
    );
  }

  Widget _protection() {
    final theme = Theme.of(context);
    final biometrics = ref.watch(biometricsAvailableProvider).value ?? false;
    Widget option(SetupLock value, IconData icon, String title, String subtitle, {bool enabled = true}) => Opacity(
      opacity: enabled ? 1 : 0.45,
      child: AppCard(
        margin: const EdgeInsets.only(bottom: 10),
        color: _lock == value ? theme.colorScheme.primaryContainer : null,
        onTap: enabled ? () => setState(() => _lock = value) : null,
        child: Row(
          children: [
            IconBubble(icon: icon, color: DS.primary, size: 44),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: theme.textTheme.titleSmall),
                  Text(subtitle, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                ],
              ),
            ),
            Icon(_lock == value ? Icons.radio_button_checked : Icons.radio_button_off, color: DS.primary),
          ],
        ),
      ),
    );
    return _pageShell(
      icon: Icons.lock_outline,
      title: 'setup.protect'.tr(),
      subtitle: _protected ? 'wizard.protectedDone'.tr() : null,
      children: [
        option(SetupLock.pin, Icons.pin_outlined, 'setup.pinTitle'.tr(), 'setup.pinSubtitle'.tr()),
        option(
          SetupLock.biometrics,
          Icons.face_retouching_natural,
          'setup.bioTitle'.tr(),
          biometrics ? 'setup.bioSubtitle'.tr() : 'setup.bioUnavailable'.tr(),
          enabled: biometrics,
        ),
      ],
    );
  }

  Widget _recovery() {
    return _pageShell(
      icon: Icons.key_outlined,
      title: 'wizard.recoveryTitle'.tr(),
      subtitle: 'wizard.recoveryHint'.tr(),
      children: [
        FieldLabel('wizard.question'.tr()),
        DropdownButtonFormField<String>(
          isExpanded: true,
          initialValue: _questionKey,
          items: [
            for (final q in recoveryQuestions)
              DropdownMenuItem(
                value: q,
                child: Text(q.tr(), overflow: TextOverflow.ellipsis),
              ),
          ],
          onChanged: (v) => setState(() => _questionKey = v ?? _questionKey),
        ),
        if (_questionKey == 'wizard.q.custom') ...[FieldLabel('wizard.customQuestion'.tr()), TextField(controller: _customQuestion)],
        FieldLabel('wizard.answer'.tr()),
        TextField(
          controller: _answer,
          decoration: InputDecoration(hintText: 'recover.answerHint'.tr()),
        ),
      ],
    );
  }

  Widget _accounts() {
    final theme = Theme.of(context);
    return _pageShell(
      icon: Icons.account_balance_wallet_outlined,
      title: 'wizard.accountsTitle'.tr(),
      subtitle: 'wizard.accountsHint'.tr(),
      children: [
        FormRowCard(
          icon: Icons.payments_outlined,
          label: 'wizard.cashBalance'.tr(),
          child: AmountField(compact: true, controller: _cash),
        ),
        for (final a in _extra)
          AppCard(
            margin: const EdgeInsets.only(top: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                const Icon(Icons.account_balance_outlined, color: DS.primary),
                const SizedBox(width: 10),
                Expanded(child: Text('${a.name} · ${'accounts.type.${a.type.name}'.tr()}', style: theme.textTheme.titleSmall)),
                AmountText(a.balance, size: 13),
                IconButton(icon: const Icon(Icons.close, size: 18), onPressed: () => setState(() => _extra.remove(a))),
              ],
            ),
          ),
        const SizedBox(height: 10),
        OutlinedButton.icon(onPressed: _addAccount, icon: const Icon(Icons.add), label: Text('wizard.addAccount'.tr())),
      ],
    );
  }

  Widget _salary() {
    return _pageShell(
      icon: Icons.payments_outlined,
      title: 'reminders.salaryDay'.tr(),
      subtitle: 'wizard.salaryHint'.tr(),
      children: [
        FieldLabel('reminders.salaryDay'.tr()),
        DropdownButtonFormField<int>(
          isExpanded: true,
          initialValue: _salaryDay,
          items: [
            DropdownMenuItem(value: 0, child: Text('reminders.noSalaryDay'.tr())),
            for (var d = 1; d <= 31; d++)
              DropdownMenuItem(
                value: d,
                child: Text('installments.dayOfMonth'.tr(namedArgs: {'day': '$d'})),
              ),
          ],
          onChanged: (v) => setState(() => _salaryDay = v ?? 0),
        ),
        if (_salaryDay > 0) ...[
          FieldLabel('${'wizard.salaryAmount'.tr()} (${'common.optional'.tr()})'),
          AmountField(compact: true, controller: _salaryAmount),
        ],
      ],
    );
  }

  Widget _modules() {
    return _pageShell(
      icon: Icons.dashboard_customize_outlined,
      title: 'modules.title'.tr(),
      subtitle: 'modules.hint'.tr(),
      children: const [ModulesList()],
    );
  }

  Widget _car() {
    return _pageShell(
      icon: Icons.directions_car_outlined,
      title: 'wizard.carTitle'.tr(),
      subtitle: 'wizard.carHint'.tr(),
      children: [
        FieldLabel('cars.name'.tr()),
        TextField(
          controller: _carName,
          decoration: InputDecoration(hintText: 'cars.nameHint'.tr()),
        ),
        FieldRow(
          flex: const [5, 3],
          [
            (
              'cars.brand'.tr(),
              TextField(
                controller: _carBrand,
                decoration: InputDecoration(hintText: 'cars.brandHint'.tr()),
              ),
            ),
            (
              'cars.modelYear'.tr(),
              TextField(
                controller: _carYear,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  const AsciiDigitsFormatter(),
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(4),
                ],
                decoration: const InputDecoration(hintText: '2022'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _reminders() {
    final times = ref.watch(settingsProvider).reminderTimes.where((t) => t.isNotEmpty).join(' · ');
    return _pageShell(
      icon: Icons.notifications_active_outlined,
      title: 'reminders.daily'.tr(),
      subtitle: 'wizard.remindersHint'.tr(),
      children: [
        AppCard(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: SwitchListTile(
            value: _daily,
            onChanged: (v) => setState(() => _daily = v),
            title: Text('reminders.dailyToggle'.tr()),
            subtitle: Text(times),
          ),
        ),
      ],
    );
  }

  Widget _done() {
    return _pageShell(
      icon: Icons.check_circle_outline,
      title: 'wizard.doneTitle'.tr(),
      subtitle: 'wizard.doneHint'.tr(),
      children: const [
        SizedBox(height: 40),
        Center(child: AppLogo(size: 110)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pages = [_language(), _details(), _protection(), _recovery(), _accounts(), _salary(), _modules(), _car(), _reminders(), _done()];
    return PopScope(
      canPop: _step == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _step > 0 && !(_step == 3 && _protected)) _go(_step - 1);
      },
      child: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Row(
                  children: [
                    Text('wizard.stepOf'.tr(namedArgs: {'n': '${_step + 1}', 'total': '$_steps'}), style: theme.textTheme.labelLarge),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(value: (_step + 1) / _steps, minHeight: 6, color: DS.gold),
                      ),
                    ),
                    if (_canSkip) TextButton(onPressed: _busy ? null : _skip, child: Text('wizard.skip'.tr())),
                  ],
                ),
              ),
              Expanded(
                child: PageView(controller: _page, physics: const NeverScrollableScrollPhysics(), children: pages),
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    _error!,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: theme.colorScheme.error),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Row(
                  children: [
                    if (_step > 0 && !(_step == 3 && _protected))
                      Padding(
                        padding: const EdgeInsetsDirectional.only(end: 10),
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(minimumSize: const Size(90, 56)),
                          onPressed: _busy
                              ? null
                              : () => _go(_step == 8 && !ref.read(settingsProvider).moduleEnabled(AppModule.cars.key) ? 6 : _step - 1),
                          child: Text('wizard.back'.tr()),
                        ),
                      ),
                    Expanded(
                      child: BigSaveButton(
                        label: (_step == _steps - 1 ? 'wizard.finish' : (_step == 2 ? 'wizard.protectNow' : 'wizard.next')).tr(),
                        busy: _busy,
                        icon: _step == _steps - 1 ? Icons.check_rounded : (_step == 2 ? Icons.lock_outline : Icons.arrow_back_rounded),
                        onPressed: _next,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Every section with "on" (used at all) and "show" (on the home screen) switches; used in the
/// wizard and in Settings.
class ModulesList extends ConsumerWidget {
  const ModulesList({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(settingsProvider);
    final theme = Theme.of(context);
    return AppCard(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Row(
              children: [
                const Expanded(child: SizedBox()),
                SizedBox(
                  width: 64,
                  child: Text('modules.enabled'.tr(), textAlign: TextAlign.center, style: theme.textTheme.labelSmall),
                ),
                SizedBox(
                  width: 64,
                  child: Text('modules.shown'.tr(), textAlign: TextAlign.center, style: theme.textTheme.labelSmall),
                ),
              ],
            ),
          ),
          for (final m in AppModule.values)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(child: Text(m.labelKey.tr(), style: theme.textTheme.bodyLarge)),
                  SizedBox(
                    width: 64,
                    child: Switch(
                      value: s.moduleEnabled(m.key),
                      onChanged: (v) => ref.read(settingsProvider.notifier).setModule(m.key, enabled: v),
                    ),
                  ),
                  SizedBox(
                    width: 64,
                    child: Switch(
                      value: s.moduleShown(m.key),
                      onChanged: s.moduleEnabled(m.key) ? (v) => ref.read(settingsProvider.notifier).setModule(m.key, shown: v) : null,
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}
