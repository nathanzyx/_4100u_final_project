import 'package:flutter/material.dart';
import 'pages/home_page.dart';
import 'services/client/client_services.dart';
import 'services/notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Make sure we have a local user stored
  // (run in background so it doesn't block startup)
  ClientService().ensureUser().then((_) {
    debugPrint('DEBUG ensureUser finished');
  }).catchError((e, st) {
    debugPrint('DEBUG ensureUser error: $e');
  });

  // Set up local notifications (also non-blocking)
  NotificationService.instance.init().then((_) {
    debugPrint('DEBUG NotificationService.init finished');
  }).catchError((e, st) {
    debugPrint('DEBUG NotificationService.init error: $e');
  });

  runApp(const StudyApp());
}

// Root widget for the app.
// We keep theme and global settings here.
class StudyApp extends StatefulWidget {
  const StudyApp({super.key});

  @override
  State<StudyApp> createState() => _StudyAppState();
}

class _StudyAppState extends State<StudyApp> {
  // Simple flag for dark mode (false = light theme)
  bool _darkModeEnabled = false;

  // When settings page changes theme, we update this flag
  void _handleThemeChanged(bool value) {
    setState(() {
      _darkModeEnabled = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'StudyConnect',
      debugShowCheckedModeBanner: false,

      // Light theme
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.indigo,
        brightness: Brightness.light,
      ),

      // Dark theme
      darkTheme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.indigo,
        brightness: Brightness.dark,
      ),

      // Pick which theme to use based on the toggle
      themeMode: _darkModeEnabled ? ThemeMode.dark : ThemeMode.light,

      // Pass dark-mode state and callback down into HomePage
      home: HomePage(
        darkModeEnabled: _darkModeEnabled,
        onThemeChanged: _handleThemeChanged,
      ),
    );
  }
}
