import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/settings/settings_provider.dart';
import '../../../core/sync/sync_api.dart';
import '../../../core/sync/sync_controller.dart';
import '../../../core/theme/ds_tokens.dart';
import '../../../core/widgets/ds_widgets.dart';

/// App mark: wallet in a soft gradient tile (used on welcome / login / register).
class AppLogo extends StatelessWidget {
  const AppLogo({super.key, this.size = 72, this.onDark = false});
  final double size;
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: onDark ? null : const LinearGradient(colors: [Color(0xFFEDE9FE), Color(0xFFE0E7FF)]),
        color: onDark ? Colors.white.withValues(alpha: 0.12) : null,
        borderRadius: BorderRadius.circular(size * 0.28),
      ),
      child: Stack(alignment: Alignment.center, children: [
        Icon(Icons.account_balance_wallet_rounded, size: size * 0.52, color: onDark ? Colors.white : DS.primary),
        PositionedDirectional(
          top: size * 0.16,
          end: size * 0.16,
          child: Container(
            width: size * 0.2,
            height: size * 0.2,
            decoration: const BoxDecoration(color: Color(0xFFF5B301), shape: BoxShape.circle),
          ),
        ),
      ]),
    );
  }
}

class _LanguageToggle extends ConsumerWidget {
  const _LanguageToggle({this.onDark = false});
  final bool onDark;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAr = context.locale.languageCode == 'ar';
    return TextButton(
      onPressed: () async {
        final code = isAr ? 'en' : 'ar';
        await ref.read(settingsProvider.notifier).setLanguage(code);
        if (context.mounted) await context.setLocale(Locale(code));
      },
      child: Text(isAr ? 'English' : 'العربية', style: TextStyle(color: onDark ? Colors.white : null)),
    );
  }
}

/// AUTH-01 welcome (mockup 1): the account is optional — start offline, or sign in.
class WelcomeScreen extends ConsumerWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: DS.navyGradient),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Align(alignment: AlignmentDirectional.centerEnd, child: _LanguageToggle(onDark: true)),
                const Spacer(),
                Center(
                  child: Stack(alignment: Alignment.center, children: [
                    Container(
                      width: 190,
                      height: 190,
                      decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.06)),
                    ),
                    const AppLogo(size: 128, onDark: true),
                  ]),
                ),
                const SizedBox(height: 32),
                Text('app.name'.tr(),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.displaySmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                Text('welcome.tagline'.tr(),
                    textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.white70)),
                const Spacer(),
                FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: const Color(0xFF2F6BEA)),
                  onPressed: () => ref.read(settingsProvider.notifier).completeOnboarding(),
                  child: Text('welcome.start'.tr()),
                ),
                const SizedBox(height: 10),
                OutlinedButton(
                  style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: const BorderSide(color: Colors.white54)),
                  onPressed: () => context.push('/login'),
                  child: Text('auth.signIn'.tr()),
                ),
                const SizedBox(height: 8),
                Text('welcome.offlineNote'.tr(),
                    textAlign: TextAlign.center, style: const TextStyle(color: Colors.white54, fontSize: 12)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String authErrorText(BuildContext context, String code) {
  final key = 'sync.errors.$code';
  return key.trExists(context: context) ? key.tr(context: context) : 'sync.errors.unexpected'.tr(context: context);
}

/// Server address: the app's own server by default, changeable under "Advanced".
class _ServerField extends StatefulWidget {
  const _ServerField({required this.controller});
  final TextEditingController controller;

  @override
  State<_ServerField> createState() => _ServerFieldState();
}

class _ServerFieldState extends State<_ServerField> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Align(
        alignment: AlignmentDirectional.centerStart,
        child: TextButton.icon(
          onPressed: () => setState(() => _open = !_open),
          icon: Icon(_open ? Icons.expand_less : Icons.expand_more, size: 18),
          label: Text('auth.advanced'.tr()),
        ),
      ),
      if (_open)
        TextField(
          controller: widget.controller,
          keyboardType: TextInputType.url,
          decoration: InputDecoration(labelText: 'sync.serverUrl'.tr(), hintText: defaultServerUrl),
        ),
    ]);
  }
}

/// AUTH-02 login (mockup 2).
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _server = TextEditingController(text: defaultServerUrl);
  bool _obscure = true;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _server.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(syncControllerProvider.notifier).signIn(serverUrl: _server.text, email: _email.text, password: _password.text);
      await afterSignIn(ref);
      if (mounted) context.go('/home');
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = authErrorText(context, e.code));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(actions: const [_LanguageToggle()]),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        children: [
          const Center(child: AppLogo()),
          const SizedBox(height: 8),
          Text('app.name'.tr(), textAlign: TextAlign.center, style: theme.textTheme.headlineSmall?.copyWith(color: DS.primary, fontWeight: FontWeight.w800)),
          const SizedBox(height: 16),
          Text('auth.welcomeBack'.tr(), textAlign: TextAlign.center, style: theme.textTheme.titleLarge),
          Text('auth.signInSubtitle'.tr(), textAlign: TextAlign.center, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          FieldLabel('sync.email'.tr()),
          TextField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
            decoration: const InputDecoration(hintText: 'name@example.com'),
          ),
          FieldLabel('sync.password'.tr()),
          TextField(
            controller: _password,
            obscureText: _obscure,
            autofillHints: const [AutofillHints.password],
            onSubmitted: (_) => _submit(),
            decoration: InputDecoration(
              suffixIcon: IconButton(
                icon: Icon(_obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
            ),
          ),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: TextButton(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: Text('auth.forgotPassword'.tr()),
                  content: Text('auth.forgotPasswordBody'.tr()),
                  actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: Text('common.ok'.tr()))],
                ),
              ),
              child: Text('auth.forgotPassword'.tr()),
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
            ),
          FilledButton(
            onPressed: _busy ? null : _submit,
            child: _busy
                ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : Text('auth.signIn'.tr()),
          ),
          _ServerField(controller: _server),
          const SizedBox(height: 8),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text('auth.noAccount'.tr()),
            TextButton(onPressed: () => context.pushReplacement('/register'), child: Text('auth.createAccount'.tr())),
          ]),
        ],
      ),
    );
  }
}

/// AUTH-03 register (mockup 3).
class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  final _code = TextEditingController();
  final _server = TextEditingController(text: defaultServerUrl);
  bool _obscure = true;
  bool _accepted = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    for (final c in [_name, _email, _phone, _password, _code, _server]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(syncControllerProvider.notifier).signIn(
            serverUrl: _server.text,
            email: _email.text,
            password: _password.text,
            register: true,
            name: _name.text,
            phone: _phone.text,
            signupCode: _code.text,
          );
      await afterSignIn(ref, name: _name.text);
      if (mounted) context.go('/home');
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = authErrorText(context, e.code));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ready = _accepted && _name.text.trim().isNotEmpty && _email.text.contains('@') && _password.text.length >= 8;
    return Scaffold(
      appBar: AppBar(),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        children: [
          const Center(child: AppLogo(size: 64)),
          const SizedBox(height: 12),
          Text('auth.createAccount'.tr(), textAlign: TextAlign.center, style: theme.textTheme.titleLarge),
          Text('auth.registerSubtitle'.tr(), textAlign: TextAlign.center, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          FieldLabel('auth.fullName'.tr()),
          TextField(controller: _name, onChanged: (_) => setState(() {})),
          FieldLabel('sync.email'.tr()),
          TextField(controller: _email, keyboardType: TextInputType.emailAddress, onChanged: (_) => setState(() {})),
          FieldLabel('auth.phone'.tr()),
          TextField(controller: _phone, keyboardType: TextInputType.phone),
          FieldLabel('sync.password'.tr()),
          TextField(
            controller: _password,
            obscureText: _obscure,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              helperText: 'auth.passwordHint'.tr(),
              suffixIcon: IconButton(
                icon: Icon(_obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
            ),
          ),
          FieldLabel('sync.signupCode'.tr()),
          TextField(controller: _code),
          const SizedBox(height: 8),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            value: _accepted,
            onChanged: (v) => setState(() => _accepted = v ?? false),
            title: Text('auth.acceptTerms'.tr(), style: theme.textTheme.bodySmall),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
            ),
          FilledButton(
            onPressed: _busy || !ready ? null : _submit,
            child: _busy
                ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : Text('auth.createAccount'.tr()),
          ),
          _ServerField(controller: _server),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text('auth.haveAccount'.tr()),
            TextButton(onPressed: () => context.pushReplacement('/login'), child: Text('auth.signIn'.tr())),
          ]),
        ],
      ),
    );
  }
}

/// After a successful sign-in from the welcome flow: leave onboarding and keep the user's name.
Future<void> afterSignIn(WidgetRef ref, {String? name}) async {
  final settings = ref.read(settingsProvider.notifier);
  final session = ref.read(syncControllerProvider).session;
  final current = ref.read(settingsProvider).userName;
  final fromServer = (name?.trim().isNotEmpty ?? false) ? name!.trim() : (session?.name ?? '');
  if (current.isEmpty && fromServer.isNotEmpty) await settings.setUserName(fromServer);
  if (!ref.read(settingsProvider).hasOnboarded) await settings.completeOnboarding();
}
