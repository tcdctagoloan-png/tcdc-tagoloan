import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'register_page.dart';
import 'home_page.dart';

class AboutUsPage extends StatelessWidget {
  const AboutUsPage({super.key});

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
                Row(
                  children: [
                    _NavItem(
                        label: "Home",
                        onTap: () => Navigator.pushReplacementNamed(
                            context, '/home')),
                    _NavItem(
                        label: "Login",
                        onTap: () =>
                            Navigator.pushReplacementNamed(context, '/login')),
                    _NavItem(
                        label: "Register",
                        onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const RegisterPage()))),
                    _NavItem(
                        label: "About",
                        onTap: () => Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const AboutUsPage()))),
                  ],
                ),
              ],
            ),
          ),

          // ✅ Main Content
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  // ✅ Hero Section
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        vertical: 60, horizontal: 24),
                    color: Colors.green.shade50,
                    child: Column(
                      children: [
                        Text(
                          "About Us",
                          style: TextStyle(
                            fontSize: isWideScreen ? 42 : 28,
                            fontWeight: FontWeight.bold,
                            color: Colors.green.shade700,
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          "Providing compassionate dialysis care with modern technology and trusted expertise.",
                          style: TextStyle(fontSize: 18, color: Colors.black87),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),

                  // ✅ Who We Are
                  Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Column(
                      children: const [
                        Text(
                          "Who We Are",
                          style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87),
                        ),
                        SizedBox(height: 16),
                        Text(
                          "Total Care Dialysis Center is dedicated to serving patients with high-quality dialysis treatment in a safe and comfortable environment. "
                              "We aim to reduce the burden of kidney disease by providing efficient scheduling, reliable technology, and patient-focused healthcare services.",
                          style: TextStyle(fontSize: 18, color: Colors.black54),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),

                  // ✅ Mission & Vision
                  Container(
                    color: Colors.white,
                    padding: const EdgeInsets.all(32),
                    child: Wrap(
                      spacing: 40,
                      runSpacing: 20,
                      alignment: WrapAlignment.center,
                      children: const [
                        _InfoCard(
                          icon: Icons.flag,
                          title: "Our Mission",
                          description:
                          "To provide seamless, accessible, and compassionate dialysis care through modern healthcare solutions.",
                        ),
                        _InfoCard(
                          icon: Icons.visibility,
                          title: "Our Vision",
                          description:
                          "To be the leading dialysis center known for innovation, trust, and excellence in patient care.",
                        ),
                      ],
                    ),
                  ),

                  // ✅ Services
                  Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Column(
                      children: const [
                        Text(
                          "Our Services",
                          style: TextStyle(
                              fontSize: 28, fontWeight: FontWeight.bold),
                        ),
                        SizedBox(height: 24),
                        _FeatureCard(
                          icon: Icons.event_available,
                          title: "Easy Scheduling",
                          description:
                          "Book your dialysis appointments online with real-time availability.",
                        ),
                        _FeatureCard(
                          icon: Icons.local_hospital,
                          title: "Modern Facility",
                          description:
                          "State-of-the-art equipment and comfortable treatment areas.",
                        ),
                        _FeatureCard(
                          icon: Icons.people,
                          title: "Expert Team",
                          description:
                          "Highly trained staff focused on your health and well-being.",
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

// ✅ Reusable Nav Item
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

// ✅ Reusable Info Card
class _InfoCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;

  const _InfoCard(
      {required this.icon, required this.title, required this.description});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 300,
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(icon, size: 40, color: Colors.green),
            const SizedBox(height: 16),
            Text(title,
                style: const TextStyle(
                    fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
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

// ✅ Reusable Feature Card
class _FeatureCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;

  const _FeatureCard(
      {required this.icon, required this.title, required this.description});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shadowColor: Colors.black26,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 280,
        padding: const EdgeInsets.all(24),
        margin: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          children: [
            Icon(icon, size: 48, color: Colors.green),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87),
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
