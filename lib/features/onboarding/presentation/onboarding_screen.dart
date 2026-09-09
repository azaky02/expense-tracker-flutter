import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/settings/settings_provider.dart';
import '../../../core/settings/settings_state.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _nameController = TextEditingController();
  String _language = 'ar';
  CalendarSystem _calendar = CalendarSystem.gregorian;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    final notifier = ref.read(settingsProvider.notifier);
    await notifier.setUserName(_nameController.text.trim());
    await notifier.setLanguage(_language);
    await notifier.setCalendar(_calendar);
    await notifier.completeOnboarding();
    if (mounted) {
      await context.setLocale(Locale(_language));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'onboarding.welcome'.tr(),
                style: Theme.of(context).textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              TextField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'settings.yourName'.tr(),
                  hintText: 'settings.yourNamePlaceholder'.tr(),
                ),
              ),
              const SizedBox(height: 24),
              Text('settings.language'.tr()),
              const SizedBox(height: 8),
              Row(
                children: [
                  ChoiceChip(
                    label: const Text('العربية'),
                    selected: _language == 'ar',
                    onSelected: (_) => setState(() => _language = 'ar'),
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: const Text('English'),
                    selected: _language == 'en',
                    onSelected: (_) => setState(() => _language = 'en'),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Text('settings.calendar'.tr()),
              const SizedBox(height: 8),
              Row(
                children: [
                  ChoiceChip(
                    label: Text('dates.gregorian'.tr()),
                    selected: _calendar == CalendarSystem.gregorian,
                    onSelected: (_) =>
                        setState(() => _calendar = CalendarSystem.gregorian),
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: Text('dates.hijri'.tr()),
                    selected: _calendar == CalendarSystem.hijri,
                    onSelected: (_) =>
                        setState(() => _calendar = CalendarSystem.hijri),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              FilledButton(
                onPressed: _finish,
                child: Text('onboarding.getStarted'.tr()),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
