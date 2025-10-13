import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'register_page.dart';
import 'about.dart';

class HomePage extends StatelessWidget {
  final String username;

  const HomePage({super.key, required this.username});

  final String logoPath =
  kIsWeb ? 'logo/TCDC-LOGO.png' : 'assets/logo/TCDC-LOGO.png';

  @override
  Widget build(BuildContext context) {
    final isWideScreen = MediaQuery.of(context).size.width >= 900;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: Column(
        children: [
          // ✅ Top Navigation Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            color: Colors.green.shade100,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Logo + Title
                Row(
                  children: [
                    Image.asset(
                      logoPath,
                      height: 45,
                      errorBuilder: (context, error, stackTrace) {
                        return const Icon(Icons.local_hospital_outlined,
                            size: 28, color: Colors.green);
                      },
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      "TOTAL CARE DIALYSIS CENTER",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
                // Navigation Links
                Row(
                  children: [
                    _NavItem(label: "Home", onTap: () => Navigator.pushReplacementNamed(context, '/home')),
                    _NavItem(label: "Login", onTap: () => Navigator.pushReplacementNamed(context, '/login')),
                    _NavItem(label: "Register", onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RegisterPage()))),
                    _NavItem(label: "About", onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AboutUsPage()))),
                  ],
                ),
              ],
            ),
          ),

          // ✅ Hero Section
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 24),
                    width: double.infinity,
                    color: Colors.green.shade50,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          "Dialysis Appointment Scheduling",
                          style: TextStyle(
                            fontSize: isWideScreen ? 40 : 28,
                            fontWeight: FontWeight.bold,
                            color: Colors.green.shade700,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          "Book, manage, and track your dialysis appointments with ease.",
                          style: TextStyle(fontSize: 18, color: Colors.black87),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 32),
                        ElevatedButton(
                          onPressed: () => Navigator.pushReplacementNamed(context, '/login'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            "Get Started",
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // ✅ Features Section
                  Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 24,
                      runSpacing: 24,
                      children: const [
                        _FeatureCard(
                          icon: Icons.event_available,
                          title: "Easy Booking",
                          description: "Schedule dialysis sessions at your preferred date and time.",
                        ),
                        _FeatureCard(
                          icon: Icons.local_hospital,
                          title: "Bed & Slot Management",
                          description: "Check available slots and beds in real time.",
                        ),
                        _FeatureCard(
                          icon: Icons.notifications_active,
                          title: "Reminders",
                          description: "Get notified for upcoming appointments.",
                        ),
                      ],
                    ),
                  ),

                  // ✅ Footer
                  Container(
                    width: double.infinity,
                    color: Colors.green.shade100,
                    padding: const EdgeInsets.all(16),
                    child: const Center(
                      child: Text(
                        "© 2025 Total Care Dialysis Center | All Rights Reserved",
                        style: TextStyle(color: Colors.black54),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ✅ Reusable Navigation Item
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
            color: Colors.black87,
          ),
        ),
      ),
    );
  }
}

// ✅ Feature Card Widget
class _FeatureCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;

  const _FeatureCard({required this.icon, required this.title, required this.description});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shadowColor: Colors.black26,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 280,
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(icon, size: 48, color: Colors.green),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              description,
              style: const TextStyle(fontSize: 16, color: Colors.black54),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
