import 'package:flutter/material.dart';

class AboutUsPage extends StatelessWidget {
  const AboutUsPage({super.key});

  // Placeholder for a high-quality clinic image
  final String heroImagePath = 'assets/dialysis_clinic.jpg';

  @override
  Widget build(BuildContext context) {
    // Defines the maximum width for the content on large screens
    final maxWidth = 900.0;
    final isWideScreen = MediaQuery.of(context).size.width > 900;

    return Scaffold(
      backgroundColor: Colors.grey[50], // Use a light off-white background
      appBar: AppBar(
        title: const Text("About Total Care Dialysis Center"),
        backgroundColor: Colors.green.shade700,
        foregroundColor: Colors.white,
        elevation: 6, // Slightly elevated AppBar
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // --- 1. Hero Image Section (Brighter Overlay) ---
            Container(
              height: MediaQuery.of(context).size.width * 0.35, // Responsive height
              constraints: const BoxConstraints(maxHeight: 350, minHeight: 200),
              width: double.infinity,
              decoration: BoxDecoration(
                image: DecorationImage(
                  // NOTE: Please add a suitable image at 'assets/dialysis_clinic.jpg'
                  image: AssetImage(heroImagePath),
                  fit: BoxFit.cover,
                  // Added error handling for image asset
                  onError: (exception, stackTrace) => const Image(
                    image: AssetImage('assets/placeholder.jpg'), // Placeholder fallback
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              child: Container(
                color: Colors.black.withOpacity(0.35), // Lighter overlay
                alignment: Alignment.center,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Text(
                    "Compassionate Care, Advanced Technology",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: MediaQuery.of(context).size.width > 600 ? 48 : 32,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      shadows: [
                        Shadow(
                          blurRadius: 8,
                          color: Colors.black.withOpacity(0.6),
                          offset: const Offset(1, 1),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // --- 2. Content Container with Max Width and Centering ---
            Center(
              child: Container(
                constraints: BoxConstraints(maxWidth: maxWidth),
                padding: const EdgeInsets.all(40.0), // Increased padding
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Mission Section
                    _buildMissionVisionCard(
                      context,
                      "Our Mission",
                      "To provide comprehensive, high-quality renal replacement therapy with a focus on patient safety, comfort, and personalized care, ensuring the best possible quality of life for those with kidney disease.",
                      Colors.green.shade50,
                    ),
                    const SizedBox(height: 32),

                    // Vision Section
                    _buildMissionVisionCard(
                      context,
                      "Our Vision",
                      "To be the leading dialysis center in the region, recognized for clinical excellence, compassionate staff, and continuous improvement in patient outcomes.",
                      Colors.white,
                    ),
                    const SizedBox(height: 40),

                    // Why Choose Us Section (Featured List)
                    _buildSectionHeader("Why Choose Us?"),
                    const SizedBox(height: 32),

                    // FIXED: Replaced GridView.count with a responsive Row/Column layout
                    LayoutBuilder(
                      builder: (context, constraints) {
                        return (constraints.maxWidth > 600)
                            ? Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: _buildFeatureCard(Icons.verified_user, "Certified Professionals", "Our team consists of highly-trained nephrologists, nurses, and technicians dedicated to your well-being.")),
                            const SizedBox(width: 20),
                            Expanded(child: _buildFeatureCard(Icons.star_half, "State-of-the-Art Equipment", "We use the latest dialysis machines and purification systems for optimal treatment efficacy.")),
                            const SizedBox(width: 20),
                            Expanded(child: _buildFeatureCard(Icons.favorite_border, "Patient-Centered Approach", "Your comfort and individual needs are our top priority in creating a calming and supportive environment.")),
                          ],
                        )
                            : Column(
                          children: [
                            _buildFeatureCard(Icons.verified_user, "Certified Professionals", "Our team consists of highly-trained nephrologists, nurses, and technicians dedicated to your well-being."),
                            const SizedBox(height: 20),
                            _buildFeatureCard(Icons.star_half, "State-of-the-Art Equipment", "We use the latest dialysis machines and purification systems for optimal treatment efficacy."),
                            const SizedBox(height: 20),
                            _buildFeatureCard(Icons.favorite_border, "Patient-Centered Approach", "Your comfort and individual needs are our top priority in creating a calming and supportive environment."),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),

            // Footer spacing
            const SizedBox(height: 60),
          ],
        ),
      ),
    );
  }

  // Helper Widget for Section Headers
  Widget _buildSectionHeader(String title) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w800,
            color: Colors.green.shade800,
          ),
        ),
        Container(
          margin: const EdgeInsets.only(top: 8),
          height: 4,
          width: 100,
          color: Colors.green.shade400,
        ),
      ],
    );
  }

  // Helper Widget for Mission/Vision sections (now in a Card)
  Widget _buildMissionVisionCard(BuildContext context, String title, String content, Color backgroundColor) {
    return Card(
      color: backgroundColor,
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.green.shade700,
              ),
            ),
            const Divider(height: 30, color: Colors.grey),
            Text(
              content,
              style: const TextStyle(fontSize: 17, height: 1.6, color: Colors.black87),
            ),
          ],
        ),
      ),
    );
  }

  // Helper Widget for Feature Cards
  Widget _buildFeatureCard(IconData icon, String title, String subtitle) {
    return Card(
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          // Added Expanded widgets here to allow the column to use the available height
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.shade100,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 32, color: Colors.green.shade700),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 8),
            // Use Expanded or flexible spacing if needed, but the Row/Column fix should solve the overflow.
            Text(
              subtitle,
              style: const TextStyle(fontSize: 16, color: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }
}
