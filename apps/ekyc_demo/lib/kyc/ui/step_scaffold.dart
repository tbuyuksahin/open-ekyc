import 'package:flutter/material.dart';

/// Common layout for flow steps: title, scrollable body, bottom actions.
class StepScaffold extends StatelessWidget {
  const StepScaffold({
    required this.title,
    required this.body,
    this.actions = const [],
    this.onCancel,
    this.cancelLabel,
    super.key,
  });

  final String title;
  final Widget body;
  final List<Widget> actions;
  final VoidCallback? onCancel;
  final String? cancelLabel;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
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
    ),
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

/// An info row with an icon, used on the consent and review screens.
class InfoRow extends StatelessWidget {
  const InfoRow({required this.icon, required this.text, super.key});

  final IconData icon;
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
