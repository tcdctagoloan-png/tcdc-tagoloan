import 'package:flutter/material.dart';
import 'firebase_options.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// Pages
import 'screens/home_page.dart';
import 'screens/login_page.dart';
import 'screens/register_page.dart';
import 'screens/about.dart';
import 'admin/admin_dashboard.dart';
import 'nurse/nurse_dashboard.dart';
import 'patient/patient_dashboard.dart';

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
      title: 'Dialysis Scheduling System',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.green),
      initialRoute: '/',
      routes: {
        '/': (context) => const AuthWrapper(),
        '/home': (context) => const HomePage(username: 'Guest'),
        '/login': (context) => const LoginPage(),
        '/register': (context) => const RegisterPage(),
        '/about': (context) => const AboutUsPage(),
      },
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      // User is not logged in → go to login page
      Future.microtask(() {
        Navigator.pushReplacementNamed(context, '/login');
      });
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('users').doc(user.uid).get(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        final data = snapshot.data!.data() as Map<String, dynamic>?;
        if (data == null || !snapshot.data!.exists) {
          FirebaseAuth.instance.signOut();
          Future.microtask(() {
            Navigator.pushReplacementNamed(context, '/login');
          });
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        final role = data['role'] ?? 'patient';
        final userId = user.uid;

        Future.microtask(() {
          if (role == "admin") {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => AdminDashboard(userId: userId)),
            );
          } else if (role == "nurse") {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => NurseDashboard(nurseId: userId)),
            );
          } else {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => PatientDashboard(userId: userId)),
            );
          }
        });

        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      },
    );
  }
}
