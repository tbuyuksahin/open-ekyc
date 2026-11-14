import 'package:material_ui/material_ui.dart';

/// Covers the app with an opaque screen whenever it is not in the
/// foreground, so identity data does not appear in the iOS app switcher
/// snapshot. Android uses FLAG_SECURE (see MainActivity) for the same
/// purpose and to block screenshots.
class PrivacyShield extends StatefulWidget {
  const PrivacyShield({required this.child, required this.label, super.key});

  final Widget child;
  final String label;

  @override
  State<PrivacyShield> createState() => _PrivacyShieldState();
}

class _PrivacyShieldState extends State<PrivacyShield>
    with WidgetsBindingObserver {
  bool _hidden = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final hidden = state != AppLifecycleState.resumed;
    if (hidden != _hidden) setState(() => _hidden = hidden);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Stack(
    textDirection: TextDirection.ltr,
    children: [
      widget.child,
      if (_hidden)
        Positioned.fill(
          child: ColoredBox(
            color: Theme.of(context).colorScheme.surface,
            child: Center(
              child: Icon(
                Icons.lock_outline,
                size: 48,
                semanticLabel: widget.label,
              ),
            ),
          ),
        ),
    ],
  );
}
