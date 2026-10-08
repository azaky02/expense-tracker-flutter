import 'package:flutter/material.dart';

const pinLength = 4;

/// Full-screen 4-digit PIN entry (same look as the lock screen). Pops with the entered PIN, or null.
Future<String?> askPin(BuildContext context, {required String title, String? subtitle, String? error}) {
  return Navigator.of(context).push<String>(MaterialPageRoute(
    fullscreenDialog: true,
    builder: (_) => PinEntryScreen(title: title, subtitle: subtitle, error: error),
  ));
}

class PinEntryScreen extends StatefulWidget {
  const PinEntryScreen({super.key, required this.title, this.subtitle, this.error});
  final String title;
  final String? subtitle;
  final String? error;

  @override
  State<PinEntryScreen> createState() => _PinEntryScreenState();
}

class _PinEntryScreenState extends State<PinEntryScreen> {
  String _pin = '';

  void _digit(String d) {
    if (_pin.length >= pinLength) return;
    setState(() => _pin += d);
    if (_pin.length == pinLength) {
      Future<void>.delayed(const Duration(milliseconds: 120), () {
        if (mounted) Navigator.of(context).pop(_pin);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(color: scheme.primaryContainer, shape: BoxShape.circle),
              child: Icon(Icons.lock_rounded, size: 46, color: scheme.primary),
            ),
            const SizedBox(height: 16),
            Text(widget.title, style: Theme.of(context).textTheme.titleLarge),
            if (widget.subtitle != null) ...[
              const SizedBox(height: 4),
              Text(widget.subtitle!, style: TextStyle(color: scheme.onSurfaceVariant), textAlign: TextAlign.center),
            ],
            if (widget.error != null) ...[
              const SizedBox(height: 6),
              Text(widget.error!, style: TextStyle(color: scheme.error)),
            ],
            const SizedBox(height: 20),
            Directionality(
              textDirection: TextDirection.ltr,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(pinLength, (i) {
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 6),
                    width: 52,
                    height: 56,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: scheme.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: i == _pin.length ? scheme.primary : scheme.outline, width: i == _pin.length ? 1.6 : 1),
                    ),
                    child: i < _pin.length ? Icon(Icons.circle, size: 14, color: scheme.onSurface) : null,
                  );
                }),
              ),
            ),
            const SizedBox(height: 24),
            Directionality(
              textDirection: TextDirection.ltr,
              child: SizedBox(
                width: 260,
                child: Wrap(alignment: WrapAlignment.center, children: [
                  for (final d in ['1', '2', '3', '4', '5', '6', '7', '8', '9']) _Key(d, () => _digit(d)),
                  const SizedBox(width: 86, height: 64),
                  _Key('0', () => _digit('0')),
                  SizedBox(
                    width: 86,
                    height: 64,
                    child: IconButton(
                      icon: const Icon(Icons.backspace_outlined),
                      onPressed: _pin.isEmpty ? null : () => setState(() => _pin = _pin.substring(0, _pin.length - 1)),
                    ),
                  ),
                ]),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

class _Key extends StatelessWidget {
  const _Key(this.label, this.onTap);
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 86,
        height: 64,
        child: TextButton(
          style: TextButton.styleFrom(shape: const CircleBorder()),
          onPressed: onTap,
          child: Text(label, style: Theme.of(context).textTheme.headlineSmall),
        ),
      );
}
