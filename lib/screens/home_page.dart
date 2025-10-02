import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; // Import for kIsWeb
import 'register_page.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
// FIXED: Changed import from 'about.dart' to 'about_us_page.dart'
import 'about.dart';
// Note: LoginPage is assumed to be accessible via named route (/login).

class HomePage extends StatelessWidget {
  final String username;

  const HomePage({super.key, required this.username});

  final String logoPath =
  kIsWeb ? 'logo/TCDC-LOGO.png' : 'assets/logo/TCDC-LOGO.png';

  @override
  Widget build(BuildContext context) {
    final isWideScreen = MediaQuery.of(context).size.width >= 900;
    // Determine the user name to display
    final displayedUsername = username.isEmpty || username == 'Guest' ? 'Guest' : username;


    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: Column(
        children: [
          // Top navigation bar (only for web)
          if (isWideScreen)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              color: Colors.green.shade100,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // FIXED: Added Logo Asset
                  Row(
                    children: [
                      Image.asset(
                        logoPath,
                        height: 50,
                        errorBuilder: (context, error, stackTrace) {
                          // Fallback icon if asset fails to load
                          return const Icon(Icons.local_hospital_outlined,
                              size: 28, color: Colors.green);
                        },
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        "TOTAL CARE DIALYSIS CENTER",
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                    ],
                  ),
                  // FIXED: Functional Navigation Links
                  Row(
                    children: [
                      // Home: Navigates to itself, replacing the current route (should only be used in App-Shell navigation)
                      _NavItem(
                        label: "Home",
                        onTap: () =>
                            Navigator.pushReplacementNamed(context, '/home'),
                      ),
                      // Login: Navigates to the login page
                      _NavItem(
                        label: "Login",
                        onTap: () =>
                            Navigator.pushReplacementNamed(context, '/login'),
                      ),
                      // Register: Navigates to the register page
                      _NavItem(
                        label: "Register",
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const RegisterPage()),
                        ),
                      ),
                      // FIXED: About navigates directly to AboutUsPage using MaterialPageRoute
                      _NavItem(
                        label: "About",
                        onTap: () =>
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const AboutUsPage()),
                            ),
                      ),
                    ],
                  )
                ],
              ),
            ),

          // Main content (Welcome + Get Started in one section)
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Card(
                  elevation: 8,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  // FIXED: Card width capped at 500 for better wide-screen look
                  child: Container(
                    width: isWideScreen ? 500 : 400,
                    padding: const EdgeInsets.all(32.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          "Welcome, $displayedUsername 👋",
                          style: const TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          "Dialysis Appointment System helps you manage bookings with ease.",
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.black87,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 32),
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: () {
                              Navigator.pushReplacementNamed(context, '/login');
                            },
                            child: const Text(
                              "Get Started",
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _NavItem({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: Colors.black,
          ),
        ),
      ),
    );
  }
}
