import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class HomePage extends StatelessWidget {
  final String username;
  final String userEmail; // Assuming email is now passed for the profile card

  // Added Icons to services for better desktop visual appeal
  static const List<Map<String, dynamic>> services = [
    {
      "name": "Hemodialysis",
      "description": "Regular hemodialysis sessions.",
      "icon": Icons.water_drop_outlined,
      "color": Colors.blue,
    },
    {
      "name": "Peritoneal Dialysis",
      "description": "Home-based dialysis treatment.",
      "icon": Icons.home_outlined,
      "color": Colors.green,
    },
    {
      "name": "Consultation",
      "description": "Consult with nephrologists.",
      "icon": Icons.people_outline,
      "color": Colors.orange,
    },
    {
      "name": "Lab Tests",
      "description": "Routine blood and urine tests.",
      "icon": Icons.science_outlined,
      "color": Colors.purple,
    },
  ];

  const HomePage({super.key, required this.username, this.userEmail = "user@example.com"});

  @override
  Widget build(BuildContext context) {
    final isWideScreen = MediaQuery.of(context).size.width >= 900;

    // === MOBILE VERSION (Kept original logic for brevity, but could be enhanced too) ===
    if (!isWideScreen) {
      return _buildMobileView();
    }

    // === WEB VERSION - PROFESSIONAL DASHBOARD LAYOUT ===
    return _buildWebView(context);
  }

  // Helper method for the Mobile View
  Widget _buildMobileView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            "Welcome, $username!",
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),

          const Text(
            "Our Services",
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Column(
            children: services.map((service) {
              return Card(
                elevation: 3,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                margin: const EdgeInsets.symmetric(vertical: 6),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(service['name']!,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 4),
                      Text(service['description']!),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),

          const Text(
            "Next Appointment",
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          // StreamBuilder for Next Appointment (Mobile)
          _buildNextAppointmentCard(isWeb: false),
        ],
      ),
    );
  }

  // Helper method for the Web View
  Widget _buildWebView(BuildContext context) {
    return Container(
      // Clean, professional background
      color: const Color(0xFFF8F9FA), // Subtle light gray for dashboard background
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. WELCOME HEADER
          Text(
            "Welcome back, $username! 👋",
            style: TextStyle(
                fontSize: 34,
                fontWeight: FontWeight.w800,
                color: Colors.blueGrey.shade800),
          ),
          const SizedBox(height: 30),

          // 2. MAIN CONTENT AREA (Services and Appointment)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left Section: Next Appointment (Priority Information)
              Expanded(
                flex: 4,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Next Appointment",
                      style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.blueGrey.shade700),
                    ),
                    const SizedBox(height: 15),
                    _buildNextAppointmentCard(isWeb: true),
                    const SizedBox(height: 30),

                    // Separate Section for Quick Links/Other Info
                    Text(
                      "Your Activity",
                      style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.blueGrey.shade700),
                    ),
                    const SizedBox(height: 15),
                    Row(
                      children: [
                        _buildQuickActionCard(
                          context,
                          'Latest Lab Results',
                          'Check your routine test results.',
                          Icons.insights,
                          Colors.teal,
                        ),
                        const SizedBox(width: 20),
                        _buildQuickActionCard(
                          context,
                          'Update Profile',
                          'Review and manage your details.',
                          Icons.account_circle_outlined,
                          Colors.deepOrange,
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 40),

              // Right Section: Our Services (Actionable Items)
              Expanded(
                flex: 6,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Book a Service",
                      style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.blueGrey.shade700),
                    ),
                    const SizedBox(height: 15),
                    Wrap(
                      spacing: 20,
                      runSpacing: 20,
                      children: services.map((service) {
                        return _buildServiceCard(context, service);
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Builds a single Service Card for the desktop view
  Widget _buildServiceCard(
      BuildContext context, Map<String, dynamic> service) {
    return SizedBox(
      width: 200, // Fixed width for nice alignment in Wrap
      child: Card(
        elevation: 6, // Higher elevation for a floating, professional look
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: InkWell(
          onTap: () {
            // Placeholder for navigation/action
          },
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(service['icon'] as IconData,
                    size: 36, color: service['color']),
                const SizedBox(height: 12),
                Text(
                  service['name'] as String,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 17),
                ),
                const SizedBox(height: 4),
                Text(
                  service['description'] as String,
                  style: TextStyle(color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Builds the Next Appointment Card using StreamBuilder
  Widget _buildNextAppointmentCard({required bool isWeb}) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('appointments')
          .where('patientId', isEqualTo: username)
          .where('status', isEqualTo: 'pending')
          .orderBy('date')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final nextAppointment = snapshot.data?.docs.isNotEmpty == true
            ? snapshot.data!.docs.first
            : null;

        if (nextAppointment == null) {
          return Card(
            elevation: isWeb ? 6 : 3,
            color: Colors.blue.shade50, // Light blue accent for importance
            shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: const Padding(
              padding: EdgeInsets.all(24),
              child: Row(
                children: [
                  Icon(Icons.event_available_outlined,
                      size: 40, color: Colors.blue),
                  SizedBox(width: 15),
                  Text("No upcoming appointments. Click 'Book' to schedule one!",
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w500)),
                  Spacer(),
                  // ElevatedButton (Actionable button could be added here)
                ],
              ),
            ),
          );
        }

        final date = (nextAppointment['date'] as Timestamp).toDate();
        final formattedDate =
            "${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}/${date.year}";

        return Card(
          elevation: isWeb ? 6 : 3,
          color: Colors.blue.shade50, // Light blue accent for importance
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.calendar_month_outlined,
                    size: 40, color: Colors.blue),
                const SizedBox(width: 20),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Your Next Session",
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 20,
                            color: Colors.blue.shade800)),
                    const SizedBox(height: 8),
                    _buildAppointmentDetail('Date', formattedDate),
                    _buildAppointmentDetail('Time', nextAppointment['time']),
                    _buildAppointmentDetail(
                        'Machine', nextAppointment['machineId']),
                    _buildAppointmentDetail(
                        'Nurse', nextAppointment['nurseId']),
                  ],
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: () {
                    // Action to view appointment details
                  },
                  icon: const Icon(Icons.arrow_forward),
                  label: const Text('View Details'),
                )
              ],
            ),
          ),
        );
      },
    );
  }

  // Helper for displaying appointment details
  Widget _buildAppointmentDetail(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 70,
            child: Text('$label:',
                style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
          Text(value, style: const TextStyle(fontWeight: FontWeight.normal)),
        ],
      ),
    );
  }

  // Helper for building quick action cards
  Widget _buildQuickActionCard(BuildContext context, String title,
      String subtitle, IconData icon, Color color) {
    return Expanded(
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: InkWell(
          onTap: () {
            // Action
          },
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(icon, size: 30, color: color),
                const SizedBox(width: 15),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16)),
                    Text(subtitle,
                        style: TextStyle(color: Colors.grey.shade600)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}