import 'package:flutter/material.dart';
import '../services/app_notifier.dart';

/// Simple Settings screen for StudyConnect.
/// Right now it lets you:
/// - Switch between light and dark theme
/// - Turn in-app notifications (SnackBars) on or off
class SettingsPage extends StatefulWidget {
  final bool darkModeEnabled;            // current theme value from main.dart
  final ValueChanged<bool> onThemeChanged; // callback to tell main.dart

  const SettingsPage({
    super.key,
    required this.darkModeEnabled,
    required this.onThemeChanged,
  });

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  // Local copy of dark mode so the switch updates right away
  late bool _darkModeEnabled;

  // Local copy of notifications flag.
  // We start with AppNotifier.notificationsEnabled so it stays in sync.
  bool _notificationsEnabled = AppNotifier.notificationsEnabled;

  @override
  void initState() {
    super.initState();
    _darkModeEnabled = widget.darkModeEnabled;
    _notificationsEnabled = AppNotifier.notificationsEnabled;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        children: [
          const SizedBox(height: 8),

          // Dark mode switch
          SwitchListTile(
            title: const Text('Dark mode'),
            subtitle: const Text('Switch between light and dark theme'),
            value: _darkModeEnabled,
            onChanged: (value) {
              setState(() {
                _darkModeEnabled = value;
              });

              // Tell the root app about the change
              widget.onThemeChanged(value);
            },
          ),

          const Divider(height: 1),

          // Notifications switch
          SwitchListTile(
            title: const Text('Notifications'),
            subtitle:
            const Text('Turn StudyConnect reminders on or off'),
            value: _notificationsEnabled,
            onChanged: (value) {
              setState(() {
                _notificationsEnabled = value;
                // Update global flag used by AppNotifier.show(...)
                AppNotifier.notificationsEnabled = value;
              });

              // Small info message so the user knows what changed
              final text = value
                  ? 'Notifications turned ON'
                  : 'Notifications turned OFF';
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(text)),
              );
            },
          ),
        ],
      ),
    );
  }
}
