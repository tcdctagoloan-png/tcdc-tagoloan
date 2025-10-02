import 'package:flutter/material.dart';
import 'firebase_options.dart';
import 'package:firebase_core/firebase_core.dart';

import 'screens/login_page.dart';
import 'screens/register_page.dart';
import 'screens/home_page.dart'; // 👈 Import your HomePage

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Dialysis Appointment Scheduling',
      theme: ThemeData(primarySwatch: Colors.blue),
      initialRoute: '/home', // 👈 Show HomePage first
      routes: {
        '/home': (context) => const HomePage(username: 'Guest'), // 👈 Default guest username
        '/login': (context) => const LoginPage(),
        '/register': (context) => const RegisterPage(),
      },
    );
  }
}
