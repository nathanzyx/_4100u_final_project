import 'package:flutter/material.dart';

// helper for showing in-app messages.
class AppNotifier {
  static bool notificationsEnabled = true;

  static void show(
      BuildContext context, {
        required String message,
        IconData? icon,
      }) {
    if (!notificationsEnabled) return;

    final theme = Theme.of(context);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Row(
          children: [
            if (icon != null) ...[
              Icon(icon, color: theme.colorScheme.onPrimary),
              const SizedBox(width: 8),
            ],
            Expanded(child: Text(message)),
          ],
        ),
      ),
    );
  }
}
