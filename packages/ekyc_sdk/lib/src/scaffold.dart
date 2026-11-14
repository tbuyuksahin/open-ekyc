import 'package:material_ui/material_ui.dart';

/// Common layout of a step: title, close button, scrollable body and
/// bottom actions.
class EkycStepScaffold extends StatelessWidget {
  /// Creates the layout.
  const EkycStepScaffold({
    required this.title,
    required this.body,
    this.actions = const [],
    this.onCancel,
    this.cancelLabel,
    super.key,
  });

  /// App bar title.
  final String title;

  /// Scrollable content.
  final Widget body;

  /// Full-width buttons pinned to the bottom.
  final List<Widget> actions;

  /// Shows a close button when set.
  final VoidCallback? onCancel;

  /// Tooltip of the close button.
  final String? cancelLabel;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: ekycAppBar(title, onCancel: onCancel, cancelLabel: cancelLabel),
    body: SafeArea(
      child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: body,
            ),
          ),
          if (actions.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: 8,
                children: actions,
              ),
            ),
        ],
      ),
    ),
  );
}

/// The app bar of a step, with an optional close button.
AppBar ekycAppBar(
  String title, {
  VoidCallback? onCancel,
  String? cancelLabel,
}) => AppBar(
  title: Text(title),
  automaticallyImplyLeading: false,
  actions: [
    if (onCancel != null)
      IconButton(
        onPressed: onCancel,
        icon: const Icon(Icons.close),
        tooltip: cancelLabel,
      ),
  ],
);

/// A line of guidance with an icon.
class EkycInfoRow extends StatelessWidget {
  /// Creates the row.
  const EkycInfoRow({required this.icon, required this.text, super.key});

  /// Leading icon.
  final IconData icon;

  /// Guidance text.
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 16),
        Expanded(child: Text(text)),
      ],
    ),
  );
}
