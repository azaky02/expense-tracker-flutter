import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/ds_tokens.dart';
import 'auth_screens.dart';

/// True once the opening splash has been shown (3 seconds at every cold start).
class SplashDoneNotifier extends Notifier<bool> {
  /// Tests and screenshot runs skip the splash.
  static bool skip = false;

  @override
  bool build() {
    if (skip) return true;
    Future<void>.delayed(const Duration(seconds: 3), () => state = true);
    return false;
  }
}

final splashDoneProvider = NotifierProvider<SplashDoneNotifier, bool>(SplashDoneNotifier.new);

/// Opening screen: logo and gold coins on dark emerald, then the PIN screen, then Home.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Scaffold(
      backgroundColor: const Color(0xFF050B08),
      body: Stack(
        children: [
          Center(
            child: Container(
              width: size.width * 1.1,
              height: size.width * 1.1,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [DS.primary.withValues(alpha: 0.55), Colors.transparent]),
              ),
            ),
          ),
          PositionedDirectional(
            top: size.height * 0.12,
            start: size.width * 0.08,
            child: GoldCoin(size: size.width * 0.22, tilt: 0.5),
          ),
          PositionedDirectional(
            bottom: size.height * 0.18,
            end: size.width * 0.1,
            child: GoldCoin(size: size.width * 0.16, tilt: -0.4),
          ),
          PositionedDirectional(
            top: size.height * 0.28,
            end: size.width * 0.16,
            child: GoldCoin(size: size.width * 0.09, tilt: 0.7),
          ),
          Center(
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.8, end: 1),
              duration: const Duration(milliseconds: 900),
              curve: Curves.easeOutBack,
              builder: (context, v, child) => Transform.scale(
                scale: v,
                child: Opacity(opacity: v.clamp(0, 1).toDouble(), child: child),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const AppLogo(size: 128),
                  const SizedBox(height: 20),
                  Text(
                    'app.name'.tr(),
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'welcome.tagline'.tr(),
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: DS.goldLight, fontSize: 13),
                  ),
                ],
              ),
            ),
          ),
          const Positioned(
            left: 0,
            right: 0,
            bottom: 48,
            child: Center(
              child: SizedBox(width: 26, height: 26, child: CircularProgressIndicator(strokeWidth: 2.5, color: DS.goldLight)),
            ),
          ),
        ],
      ),
    );
  }
}
