import 'package:flutter/material.dart';
import 'pages/home_page.dart';
import 'services/client/client_services.dart';
import 'services/notification_service.dart';
import 'widgets/location_picker.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();


  final client = ClientService();
  final initialDarkMode = await client.loadDarkModePreference();

  await NotificationService.instance.init().then((_) {
    debugPrint('DEBUG NotificationService.init finished');
  }).catchError((e, st) {
    debugPrint('DEBUG NotificationService.init error: $e');
  });

  runApp(StudyApp(initialDarkModeEnabled: initialDarkMode));
}

// Root widget for the app.
// We keep theme and global settings here.
class StudyApp extends StatefulWidget {
  final bool initialDarkModeEnabled;

  const StudyApp({
    super.key,
    required this.initialDarkModeEnabled,
    });

  @override
  State<StudyApp> createState() => _StudyAppState();
}

class StartupGate extends StatefulWidget
{
  final bool darkModeEnabled;
  final ValueChanged<bool> onThemeChanged;

  const StartupGate({
    super.key,
    required this.darkModeEnabled,
    required this.onThemeChanged,
  });

  @override
  State<StartupGate> createState() => _StartupGateState();
}

class _StudyAppState extends State<StudyApp> {
  // Simple flag for dark mode (false = light theme)
  late bool _darkModeEnabled;

  @override
  void initState() {
    super.initState();
    _darkModeEnabled = widget.initialDarkModeEnabled;
  }

  // When settings page changes theme, we update this flag
  void _handleThemeChanged(bool value) {
    setState(() {
      _darkModeEnabled = value;
    });
    ClientService().saveDarkModePreference(value);
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
      home: StartupGate(
      darkModeEnabled: _darkModeEnabled,
      onThemeChanged: _handleThemeChanged,
    ),
    );
  }
}

/*
  Gate for startup tasks
    - Checks if the app requires the user to input their location
*/
class _StartupGateState extends State<StartupGate>
{
  final _client = ClientService();

  bool _ready = false;
  Object? _error;

  @override
  void initState()
  {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _boot());
  }

  Future<void> _boot() async
  {
    try {
      await _client.ensureUser();

      // Only runs if client_services decides user needs to set location
      if (_client.createdNewInLastEnsure)
      {
        final picked = await showLocationPickerDialog(
          context: context,
          barrierDismissible: false,
          title: 'Choose your location',
        );

        if (picked != null)
        {
          await _client.setUserCoordinates(
            picked.point.latitude,
            picked.point.longitude,
          );
        }
      }

      if (!mounted) return;
      setState(() => _ready = true);
    }
    catch (e)
    {
      if (!mounted) return;
      setState(() => _error = e);
    }
  }

  @override
  Widget build(BuildContext context)
  {
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('StudyConnect')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children:
              [
                Text('Startup error: $_error'),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () => setState(()
                  {
                    _error = null;
                    _ready = false;
                    _boot();
                  }),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (!_ready)
    {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return HomePage(
      darkModeEnabled: widget.darkModeEnabled,
      onThemeChanged: widget.onThemeChanged,
    );
  }
}