import 'package:flutter/material.dart';
import 'drive_theme.dart';

/// Consistent, non-blocking confirmation after the server accepts an action.
/// Never show a success notification before an API call resolves.
void journeyNotice(BuildContext context, String title, {
  String? next,
  bool error = false,
  String? actionLabel,
  VoidCallback? onAction,
}) {
  if (!context.mounted) return;
  final messenger = ScaffoldMessenger.of(context);
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(SnackBar(
    behavior: SnackBarBehavior.floating,
    duration: Duration(seconds: error ? 7 : 5),
    backgroundColor: error ? const Color(0xFF51292F) : const Color(0xFF153D3A),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15),
      side: BorderSide(color: error ? const Color(0xFFB65A66) : DriveColors.accent)),
    content: Row(children: [
      Icon(error ? Icons.error_outline_rounded : Icons.check_circle_rounded,
          color: error ? const Color(0xFFFFB5B9) : DriveColors.accent),
      const SizedBox(width: 12),
      Expanded(child: Column(mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w800, color: Colors.white)),
        if (next != null) ...[
          const SizedBox(height: 3),
          Text(next, style: const TextStyle(fontSize: 12, color: Color(0xFFCADCD9))),
        ],
      ])),
    ]),
    action: actionLabel != null && onAction != null
        ? SnackBarAction(label: actionLabel, textColor: DriveColors.accent, onPressed: onAction)
        : null,
  ));
}

/// Explains a helpful capability in terms of the task, rather than the AI technique.
class ContextualTip extends StatelessWidget {
  final IconData icon;
  final String title, description;
  final String? action;
  final VoidCallback? onPressed;
  const ContextualTip({super.key, required this.icon, required this.title,
    required this.description, this.action, this.onPressed});
  @override Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(color: const Color(0xFF102E2D),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: const Color(0xFF1D6861))),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(icon, color: DriveColors.accent, size: 22),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        Text(description, style: const TextStyle(fontSize: 12, color: DriveColors.muted, height: 1.5)),
        if (action != null && onPressed != null) ...[
          const SizedBox(height: 9),
          TextButton.icon(onPressed: onPressed,
            icon: const Icon(Icons.arrow_forward_rounded, size: 16), label: Text(action!)),
        ],
      ])),
    ]),
  );
}
