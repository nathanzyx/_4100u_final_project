import 'package:flutter/material.dart';
import '../services/app_notifier.dart';
import '../services/client/client_services.dart';
import 'package:study_connect_shared/models/user.dart';
import 'account_settings_page.dart';

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

class _LoginDialog extends StatefulWidget {
  const _LoginDialog({Key? key}) : super(key: key);

  @override
  State<_LoginDialog> createState() => _LoginDialogState();
}

class _LoginDialogState extends State<_LoginDialog> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _doLogin() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final cs = ClientService();
    try {
      final user = await cs.loginWithUsernamePassword(
        _usernameController.text,
        _passwordController.text,
      );

      if (!mounted) return;
      Navigator.of(context).pop(user);
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Log in'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _usernameController,
            decoration: const InputDecoration(labelText: 'Username'),
            enabled: !_loading,
          ),
          TextField(
            controller: _passwordController,
            decoration: const InputDecoration(labelText: 'Password'),
            obscureText: true,
            enabled: !_loading,
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: const TextStyle(color: Colors.red)),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _loading ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _loading ? null : _doLogin,
          child: _loading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Log in'),
        ),
      ],
    );
  }
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
          const Divider(height: 1),

          // Switch account tile
          ListTile(
            leading: const Icon(Icons.switch_account),
            title: const Text('Switch account'),
            subtitle: const Text('Log into another account on this device'),
            onTap: () async
            {
              final cs = ClientService();
              final u = await showDialog<User>(
                context: context,
                builder: (_) => const _LoginDialog(),
              );
              if (u == null || !mounted) return;

              cs.stopNotificationPolling();
              cs.startNotificationPolling();

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Logged in as ${u.displayName}')),
              );
            },
          ),

          // Account settings page
          ListTile(
            leading: const Icon(Icons.manage_accounts),
            title: const Text('Account settings'),
            subtitle: const Text('Change display name, username, password'),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AccountSettingsPage()),
              );
            },
          ),
        ],
      ),
    );
  }
}
