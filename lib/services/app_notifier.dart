import 'package:flutter/material.dart';

/// Small helper for showing in-app messages.
/// We also use a flag so the Settings page can turn them on or off.
class AppNotifier {
  // When this is false, we do not show any SnackBars.
  static bool notificationsEnabled = true;

  static void show(
      BuildContext context, {
        required String message,
        IconData? icon,
      }) {
    // Respect the settings toggle
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
