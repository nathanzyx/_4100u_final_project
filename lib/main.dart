import 'package:flutter/material.dart';
import 'pages/home_page.dart';
import 'services/client/client_services.dart';

// temporary
import 'dart:convert';
import 'package:http/http.dart' as http;

// For Android emulator:
const String baseUrl = 'http://10.0.2.2:8080';


Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const StudyApp());
}

class StudyApp extends StatelessWidget {
  const StudyApp({super.key});

  @override
  Widget build(BuildContext context) {

    // TEMPORARY (SERVER TEST)
    Future<void> testPing() async {
      final uri = Uri.parse('$baseUrl/ping');
      final res = await http.get(uri);

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        print('Ping OK: $data');
      } else {
        print('Ping failed: ${res.statusCode}');
      }
    }
    testPing();
    
    return MaterialApp(
      title: 'StudyConnect',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.indigo),
      home: const HomePage(),
    );

  }
}

