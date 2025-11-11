import 'package:flutter/material.dart';


/*

  AppNotifier

  - simple class (for now) for showing notifications

  - When we implement the server, this will be more thourgouhly used

*/
class AppNotifier {
  AppNotifier._();

  // allow custom notifications for banner
  static void show(
    BuildContext context, {
    required String message,
    IconData icon = Icons.notifications,
  }) {
    final messenger = ScaffoldMessenger.of(context);

    // interrupt other banners (if applicable)
    messenger.hideCurrentMaterialBanner();

    messenger.showMaterialBanner(
      MaterialBanner
      (
        content: Text(message),
        leading: Icon(icon),
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
        // button to get rid of the notification
        actions: [
          TextButton(
            onPressed: messenger.hideCurrentMaterialBanner,
            child: const Text('Dismiss'),
          ),

        ],
      ),

    );
  }
}
