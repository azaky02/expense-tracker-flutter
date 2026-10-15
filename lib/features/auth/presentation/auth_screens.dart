import 'dart:async';
import 'dart:ui' as ui;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/settings/settings_provider.dart';
import '../../../core/sync/sync_api.dart';
import '../../../core/sync/sync_controller.dart';
import '../../../core/theme/ds_tokens.dart';
import '../../../core/widgets/ds_widgets.dart';
import '../../../core/utils/currency.dart';

/// App mark: the app icon (wallet, coins and chart on emerald) in a rounded tile.
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
        borderRadius: BorderRadius.circular(size * 0.24),
        boxShadow: [BoxShadow(color: DS.navy.withValues(alpha: 0.25), blurRadius: size * 0.2, offset: Offset(0, size * 0.06))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(size * 0.24),
        child: Image.asset('assets/icon/app_icon.png', fit: BoxFit.cover),
      ),
    );
  }
}

/// A gold coin with the pound sign, optionally tilted (welcome screen).
class GoldCoin extends StatelessWidget {
  const GoldCoin({super.key, required this.size, this.tilt = 0});
  final double size;

  /// Rotation around the vertical axis, in radians.
  final double tilt;

  @override
  Widget build(BuildContext context) {
    final coin = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: DS.goldGradient,
        boxShadow: [
          BoxShadow(color: DS.gold.withValues(alpha: 0.35), blurRadius: size * 0.35),
          BoxShadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: size * 0.12, offset: Offset(size * 0.04, size * 0.08)),
        ],
      ),
      padding: EdgeInsets.all(size * 0.09),
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFF8A6418).withValues(alpha: 0.55), width: size * 0.025),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFE6C463), Color(0xFFC79A2E)],
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          '£',
          style: TextStyle(
            fontSize: size * 0.5,
            fontWeight: FontWeight.w900,
            color: const Color(0xFF8A6418),
            shadows: [Shadow(color: const Color(0xFFFFF1C2).withValues(alpha: 0.8), offset: Offset(-size * 0.01, -size * 0.01))],
          ),
        ),
      ),
    );
    if (tilt == 0) return coin;
    return Transform(
      alignment: Alignment.center,
      transform: Matrix4.identity()
        ..setEntry(3, 2, 0.0015)
        ..rotateY(tilt),
      child: coin,
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

/// AUTH-01 welcome: dark emerald with gold coins, then on-device sign-up.
class WelcomeScreen extends ConsumerWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final size = MediaQuery.of(context).size;
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: const Color(0xFF050B08),
      body: Stack(
        children: [
          // Vertical light bars on the far side, like light through blinds.
          PositionedDirectional(
            top: 0,
            bottom: size.height * 0.42,
            end: 0,
            width: size.width * 0.42,
            child: Row(
              children: [
                for (var i = 0; i < 7; i++)
                  Expanded(
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            (i.isEven ? const Color(0xFF1F9D5B) : const Color(0xFF0F5C3E)).withValues(alpha: 0.25 + i * 0.06),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          // Soft green glow behind the coins.
          Positioned(
            top: size.height * 0.08,
            left: -size.width * 0.2,
            child: Container(
              width: size.width * 0.9,
              height: size.width * 0.9,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [const Color(0xFF0F5C3E).withValues(alpha: 0.55), Colors.transparent]),
              ),
            ),
          ),
          PositionedDirectional(
            top: size.height * 0.11,
            start: size.width * 0.12,
            child: GoldCoin(size: size.width * 0.48, tilt: 0.45),
          ),
          PositionedDirectional(
            top: size.height * 0.40,
            start: size.width * 0.06,
            child: GoldCoin(size: size.width * 0.17, tilt: -0.3),
          ),
          PositionedDirectional(
            top: size.height * 0.33,
            end: size.width * 0.14,
            child: GoldCoin(size: size.width * 0.1, tilt: 0.6),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const AppLogo(size: 40),
                      const SizedBox(width: 10),
                      Text(
                        'app.name'.tr(),
                        style: theme.textTheme.titleMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w800),
                      ),
                      const Spacer(),
                      const _LanguageToggle(onDark: true),
                    ],
                  ),
                  const Spacer(),
                  Text(
                    'welcome.headline'.tr(),
                    style: theme.textTheme.headlineMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w800, height: 1.25),
                  ),
                  const SizedBox(height: 10),
                  Text('welcome.tagline'.tr(), style: theme.textTheme.bodyLarge?.copyWith(color: Colors.white60)),
                  const SizedBox(height: 28),
                  _GlowButton(label: 'welcome.start'.tr(), onTap: () => context.push('/setup')),
                  const SizedBox(height: 12),
                  Text(
                    'welcome.offlineNote'.tr(),
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white38, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Pill button with a green glow (welcome screen).
class _GlowButton extends StatelessWidget {
  const _GlowButton({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: const Color(0xFF2BAA6B), width: 1.2),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF0B1A12), Color(0xFF145C3A)],
        ),
        boxShadow: [BoxShadow(color: const Color(0xFF1F9D5B).withValues(alpha: 0.35), blurRadius: 24, offset: const Offset(0, 6))],
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(30),
          onTap: onTap,
          child: Center(
            child: Text(
              label,
              style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
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
      ],
    );
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
          Text(
            'app.name'.tr(),
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall?.copyWith(color: DS.primary, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 16),
          Text('auth.welcomeBack'.tr(), textAlign: TextAlign.center, style: theme.textTheme.titleLarge),
          Text(
            'auth.signInSubtitle'.tr(),
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          FieldLabel('auth.phoneOrEmail'.tr()),
          TextField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.telephoneNumber, AutofillHints.email],
            decoration: const InputDecoration(hintText: '01xxxxxxxxx'),
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
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('auth.noAccount'.tr()),
              TextButton(onPressed: () => context.pushReplacement('/register'), child: Text('auth.createAccount'.tr())),
            ],
          ),
        ],
      ),
    );
  }
}

/// AUTH-03 register (mockup 3) → AUTH-04 verify (mockup 4): name + mobile number + password, then
/// the one-time code. With no SMS provider yet, the server returns the code and it is shown here
/// temporarily so the flow can be tested end to end.
class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _code = TextEditingController();
  final _otp = TextEditingController();
  final _server = TextEditingController(text: defaultServerUrl);
  bool _obscure = true;
  bool _accepted = false;
  bool _busy = false;
  String? _error;

  // Step 2 state.
  String? _verifiedPhone;
  String? _devCode;
  int _resendIn = 0;
  Timer? _timer;

  @override
  void dispose() {
    for (final c in [_name, _phone, _email, _password, _code, _otp, _server]) {
      c.dispose();
    }
    _timer?.cancel();
    super.dispose();
  }

  void _startCountdown() {
    _timer?.cancel();
    setState(() => _resendIn = 45);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted || _resendIn <= 1) {
        t.cancel();
        if (mounted) setState(() => _resendIn = 0);
        return;
      }
      setState(() => _resendIn--);
    });
  }

  Future<void> _requestCode() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final r = await ref.read(syncControllerProvider.notifier).requestOtp(serverUrl: _server.text, phone: _phone.text);
      setState(() {
        _verifiedPhone = r.phone;
        _devCode = r.devCode;
        _otp.clear();
      });
      _startCountdown();
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = authErrorText(context, e.code));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _verify() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(syncControllerProvider.notifier)
          .registerWithPhone(
            serverUrl: _server.text,
            phone: _verifiedPhone!,
            otp: _otp.text.trim(),
            password: _password.text,
            name: _name.text,
            email: _email.text,
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
    return Scaffold(
      appBar: AppBar(
        leading: _verifiedPhone == null
            ? null
            : IconButton(icon: const BackButtonIcon(), onPressed: () => setState(() => _verifiedPhone = null)),
      ),
      body: _verifiedPhone == null ? _form(context) : _verifyStep(context),
    );
  }

  Widget _form(BuildContext context) {
    final theme = Theme.of(context);
    final digits = _phone.text.replaceAll(RegExp(r'\D'), '');
    final ready = _accepted && _name.text.trim().isNotEmpty && digits.length >= 8 && _password.text.length >= 8;
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      children: [
        const Center(child: AppLogo(size: 64)),
        const SizedBox(height: 12),
        Text('auth.createAccount'.tr(), textAlign: TextAlign.center, style: theme.textTheme.titleLarge),
        Text(
          'auth.registerSubtitle'.tr(),
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
        FieldLabel('auth.fullName'.tr()),
        TextField(controller: _name, onChanged: (_) => setState(() {})),
        FieldLabel('auth.mobile'.tr()),
        TextField(
          controller: _phone,
          keyboardType: TextInputType.phone,
          autofillHints: const [AutofillHints.telephoneNumber],
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(hintText: '01xxxxxxxxx'),
        ),
        FieldLabel('auth.emailOptional'.tr()),
        TextField(controller: _email, keyboardType: TextInputType.emailAddress),
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
          onPressed: _busy || !ready ? null : _requestCode,
          child: _busy
              ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : Text('auth.continue'.tr()),
        ),
        _ServerField(controller: _server),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('auth.haveAccount'.tr()),
            TextButton(onPressed: () => context.pushReplacement('/login'), child: Text('auth.signIn'.tr())),
          ],
        ),
      ],
    );
  }

  Widget _verifyStep(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      children: [
        Center(
          child: Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(color: theme.colorScheme.primaryContainer, shape: BoxShape.circle),
            child: Icon(Icons.verified_user_rounded, size: 52, color: theme.colorScheme.primary),
          ),
        ),
        const SizedBox(height: 16),
        Text('auth.verifyTitle'.tr(), textAlign: TextAlign.center, style: theme.textTheme.titleLarge),
        const SizedBox(height: 4),
        Text(
          'auth.verifySent'.tr(),
          textAlign: TextAlign.center,
          style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
        ),
        Directionality(
          textDirection: ui.TextDirection.ltr,
          child: Text(_verifiedPhone!, textAlign: TextAlign.center, style: theme.textTheme.titleMedium),
        ),
        if (_devCode != null) ...[
          const SizedBox(height: 16),
          AppCard(
            color: DS.warning.withValues(alpha: 0.12),
            child: Row(
              children: [
                const Icon(Icons.info_outline, color: DS.warning),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('auth.devCodeTitle'.tr(), style: theme.textTheme.bodySmall),
                      Directionality(
                        textDirection: ui.TextDirection.ltr,
                        child: Text(
                          _devCode!,
                          style: theme.textTheme.headlineSmall?.copyWith(letterSpacing: 6, fontWeight: FontWeight.w800),
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton(onPressed: () => setState(() => _otp.text = _devCode!), child: Text('auth.useCode'.tr())),
              ],
            ),
          ),
        ],
        const SizedBox(height: 20),
        Directionality(
          textDirection: ui.TextDirection.ltr,
          child: TextField(
            controller: _otp,
            autofocus: true,
            maxLength: 6,
            keyboardType: TextInputType.number,
            inputFormatters: const [AsciiDigitsFormatter()],
            textAlign: TextAlign.center,
            onChanged: (_) => setState(() {}),
            style: theme.textTheme.headlineMedium?.copyWith(letterSpacing: 18, fontWeight: FontWeight.w700),
            decoration: const InputDecoration(counterText: '', hintText: '••••••'),
          ),
        ),
        const SizedBox(height: 8),
        Center(
          child: _resendIn > 0
              ? Text(
                  'auth.resendIn'.tr(namedArgs: {'seconds': '$_resendIn'}),
                  style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                )
              : TextButton(onPressed: _busy ? null : _requestCode, child: Text('auth.resend'.tr())),
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              _error!,
              style: TextStyle(color: theme.colorScheme.error),
              textAlign: TextAlign.center,
            ),
          ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: _busy || _otp.text.trim().length != 6 ? null : _verify,
          child: _busy
              ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : Text('auth.verify'.tr()),
        ),
      ],
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
