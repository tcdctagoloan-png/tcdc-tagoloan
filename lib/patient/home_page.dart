import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
// Note: We no longer need to import BookPage or ProfilePage here for navigation,
// as the navigation happens in the parent (PatientDashboard).

class HomePage extends StatelessWidget {
  final String username;
  final String userEmail;
  // NEW: Callback function to trigger navigation in the parent Dashboard
  final Function(int)? onNavigate;

  // Index references for the Dashboard:
  // Book Page = 2
  // Profile Page = 3

  static const List<Map<String, dynamic>> services = [
    {
      "name": "Hemodialysis",
      "description": "Regular, in-center dialysis sessions.",
      "icon": Icons.water_drop_outlined,
      "color": Colors.blue,
    },
  ];

  const HomePage(
      {super.key,
        required this.username,
        this.userEmail = "user@example.com",
        this.onNavigate // NEW: Accept the navigation function
      });

  @override
  Widget build(BuildContext context) {
    final isWideScreen = MediaQuery.of(context).size.width >= 900;

    // Mobile navigation still uses push/pop as it's a dedicated page
    if (!isWideScreen) {
      // NOTE: For mobile, the user will likely already be in the Dashboard,
      // but if HomePage is used outside the Dashboard, this push logic is needed.
      // Assuming HomePage is only used *inside* PatientDashboard, mobile buttons
      // should also use the callback (for consistency).
      return _buildMobileView(context);
    }

    // Web view navigation uses the callback to switch the dashboard index.
    return _buildWebView(context);
  }

  // Helper method for the Mobile View
  Widget _buildMobileView(BuildContext context) {
    // If we are deep within the dashboard's mobile view, we should still use the callback
    // if it's provided. If not, fallback to pushing a new page (which may nest pages).
    void navigateToBookPage() {
      if (onNavigate != null) {
        onNavigate!(2); // Navigate to index 2 (Book)
      } else {
        // Fallback: This path is usually not expected when embedded in the dashboard
        // If this code path is hit, you need to import BookPage/ProfilePage here
        // and re-enable the Navigator.push logic from your previous, separate fix.
      }
    }

    // The rest of the mobile view layout (using navigateToBookPage for the button)
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
            "Our Service",
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          // Loop through services and build cards
          ...services.map((service) {
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
                    Text(service['name'] as String,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 4),
                    Text(service['description'] as String),
                    const SizedBox(height: 8),
                    // Mobile button uses the callback
                    ElevatedButton.icon(
                      onPressed: navigateToBookPage,
                      icon: const Icon(Icons.add_circle_outline, size: 18),
                      label: const Text('Book Now'),
                    )
                  ],
                ),
              ),
            );
          }).toList(),
          const SizedBox(height: 20),
          const Text(
            "Next Appointment",
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          _buildNextAppointmentCard(context, isWeb: false),
        ],
      ),
    );
  }


  // Web View - Space Optimized
  Widget _buildWebView(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Color(0xFFE0FFE0), // Light green start
            Color(0xFFCCFFCC), // Light green end
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      padding: const EdgeInsets.fromLTRB(32, 32, 32, 32),
      child: SingleChildScrollView(
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

            // 2. MAIN CONTENT AREA: Next Session and Service
            Text(
              "Next Session",
              style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.blueGrey.shade700),
            ),
            const SizedBox(height: 15),
            _buildNextAppointmentCard(context, isWeb: true),
            const SizedBox(height: 30),

            // 3. SERVICE AND ACTIVITY CARDS (In a Row for equal spacing)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // LEFT: Hemodialysis Service Card (Actionable)
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Book Session", // Simplified header
                        style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.blueGrey.shade700),
                      ),
                      const SizedBox(height: 15),
                      // Card size is fixed here for better visual balance
                      _buildServiceCard(context, services.first,
                          height: 280.0), // Fixed Height
                    ],
                  ),
                ),

                const SizedBox(width: 40),

                // RIGHT: Your Activity (Profile Link)
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Your Activity", // Simplified header
                        style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.blueGrey.shade700),
                      ),
                      const SizedBox(height: 15),
                      // Navigation to ProfilePage
                      _buildQuickActionCard(
                        context,
                        'Update Profile',
                        'Review and manage your personal details.',
                        Icons.account_circle_outlined,
                        Colors.deepOrange,
                        height: 280.0, // Fixed Height
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Builds the single, prominent Hemodialysis Service Card (Book Now)
  Widget _buildServiceCard(
      BuildContext context, Map<String, dynamic> service,
      {double height = 280.0}) {

    // NAVIGATION FUNCTION: Uses the callback to change the dashboard index to 2 (Book)
    void navigateToBookPage() {
      if (onNavigate != null) {
        onNavigate!(2); // Navigate to index 2 (Book)
      }
    }

    return SizedBox(
      height: height,
      child: Card(
        elevation: 6,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: InkWell(
          // InkWell click also navigates
          onTap: navigateToBookPage,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(service['icon'] as IconData,
                        size: 48, color: service['color']),
                    const SizedBox(height: 16),
                    Text(
                      service['name'] as String,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 20),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      service['description'] as String,
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  ],
                ),
                // Primary action button
                ElevatedButton.icon(
                  // BUTTON CLICK: Uses the callback
                  onPressed: navigateToBookPage,
                  icon: const Icon(Icons.add_circle_outline),
                  label: const Text('Book Now'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  ),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Builds the Quick Action Card (Update Profile) with unified button
  Widget _buildQuickActionCard(BuildContext context, String title,
      String subtitle, IconData icon, Color color,
      {double height = 280.0}) {

    // NAVIGATION FUNCTION: Uses the callback to change the dashboard index to 3 (Profile)
    void navigateToProfile() {
      if (onNavigate != null) {
        onNavigate!(3); // Navigate to index 3 (Profile)
      }
    }

    return SizedBox(
      height: height,
      child: Card(
        elevation: 6,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: InkWell(
          onTap: navigateToProfile,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(icon, size: 48, color: color),
                    const SizedBox(height: 16),
                    Text(title,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 20)),
                    const SizedBox(height: 8),
                    Text(subtitle,
                        style: TextStyle(color: Colors.grey.shade600)),
                  ],
                ),
                // UNIFIED BUTTON STYLE (Matches 'Book Now')
                ElevatedButton.icon(
                  onPressed: navigateToProfile,
                  icon: const Icon(Icons.arrow_forward), // Use arrow icon
                  label: const Text('Go to Page'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue, // Primary Color
                    foregroundColor: Colors.white,
                    padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  ),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Appointment card logic (remains mostly the same)
  Widget _buildNextAppointmentCard(BuildContext context, {required bool isWeb}) {
    // ... (logic for StreamBuilder and displaying appointment details)
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
            color: Colors.blue.shade50,
            shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: const Padding(
              padding: EdgeInsets.all(24),
              child: Row(
                children: [
                  Icon(Icons.event_available_outlined,
                      size: 40, color: Colors.blue),
                  SizedBox(width: 15),
                  Expanded(
                    child: Text(
                        "No upcoming sessions. Click 'Book Now' below to schedule one!",
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w500)),
                  ),
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
          color: Colors.blue.shade50,
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
                    _buildAppointmentDetail('Time', nextAppointment['slot']),
                    _buildAppointmentDetail(
                        'Bed', nextAppointment['bedName'] ?? 'Pending'),
                    _buildAppointmentDetail(
                        'Status', nextAppointment['status']),
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
}