import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';


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
    final w = MediaQuery.of(context).size.width;
    return Scaffold(
      backgroundColor: const Color(0xFF050505),
      body: Stack(
        fit: StackFit.expand,
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 700),
            builder: (context, v, child) => Opacity(opacity: v, child: child),
            child: Image.asset('assets/splash/splash.webp', fit: BoxFit.cover),
          ),
          // Live spinner over the one drawn in the artwork.
          Align(
            alignment: const Alignment(0, 0.595),
            child: SizedBox(
              width: w * 0.095,
              height: w * 0.095,
              child: const CircularProgressIndicator(strokeWidth: 3, color: Color(0xFFE9B949), backgroundColor: Color(0xFF2A2A2A)),
            ),
          ),
        ],
      ),
    );
  }
}
