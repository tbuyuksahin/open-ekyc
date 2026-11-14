import 'package:material_ui/material_ui.dart';

/// A round camera shutter for manual capture.
///
/// Dimmed and not tappable while [onPressed] is `null`.
class ShutterButton extends StatelessWidget {
  /// Creates a shutter.
  const ShutterButton({
    required this.onPressed,
    this.label,
    this.color = Colors.white,
    this.size = 76,
    super.key,
  });

  /// Called on tap; `null` disables the button.
  final VoidCallback? onPressed;

  /// Announced to screen readers.
  final String? label;

  /// Ring color while enabled.
  final Color color;

  /// Outer diameter.
  final double size;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      child: AnimatedOpacity(
        opacity: enabled ? 1 : 0.4,
        duration: const Duration(milliseconds: 150),
        // Own Material so the ink works in hosts without a Scaffold.
        child: Material(
          type: MaterialType.transparency,
          shape: const CircleBorder(),
          child: InkResponse(
            onTap: onPressed,
            radius: size * 0.58,
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: enabled ? color : Colors.white,
                  width: 5,
                ),
              ),
              padding: const EdgeInsets.all(6),
              child: const DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
