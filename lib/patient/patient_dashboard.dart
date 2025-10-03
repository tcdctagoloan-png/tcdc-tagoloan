import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import 'appointment_page.dart';
import 'book_page.dart' as booking;
import 'notification_page.dart';
import 'profile_page.dart';
import 'home_page.dart';
import '../screens/login_page.dart';
import 'package:dialysis_app/reports/report_page.dart';

class PatientDashboard extends StatefulWidget {
  final String userId;
  const PatientDashboard({super.key, required this.userId});

  @override
  _PatientDashboardState createState() => _PatientDashboardState();
}

class _PatientDashboardState extends State<PatientDashboard> {
  int _index = 0;
  String _username = '';
  String _userEmail = ''; // To store the user's email
  bool _loadingName = true;
  late final List<Widget> _pages;
  late final String _patientId;
  int _unreadNotifications = 0;

  final List<String> _titles = [
    "Home",
    "Appointments",
    "Book",
    "Profile",
    "Notifications",
    "History"
  ];

  @override
  void initState() {
    super.initState();
    _patientId = widget.userId;
    // Get email from current Firebase user
    _userEmail = FirebaseAuth.instance.currentUser?.email ?? 'N/A';

    // Initialize all pages with either the component or a temporary placeholder
    _pages = [
      const Center(child: CircularProgressIndicator()),
      PatientAppointmentsPage(userId: _patientId),
      const Center(child: CircularProgressIndicator()),
      ProfilePage(userId: _patientId),
      PatientNotificationPage(userId: _patientId),
      ReportsPage(role: "patient", userId: _patientId),
    ];

    _loadUsername();
    _listenUnreadNotifications();
  }

  Future<void> _loadUsername() async {
    bool isVerified = false;
    String name = '';
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(_patientId)
          .get();

      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        name = (data['username'] ?? data['fullName'] ?? '').toString();
        isVerified = data['verified'] == true;
      }
    } catch (_) {
      name = ''; // Keep name empty on error
    } finally {
      if (mounted) {
        setState(() {
          _username = name;
          _loadingName = false;
          _pages[0] = HomePage(username: _username);

          // Conditionally update the Book page
          _pages[2] = isVerified
              ? SafeArea(child: booking.BookPage(userId: _patientId))
              : const Center(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Text(
                "Booking is disabled until your account is verified.\n\n"
                    "Please pass all requirements to the admin.",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18, color: Colors.grey),
              ),
            ),
          );
        });
      }
    }
  }

  void _listenUnreadNotifications() {
    FirebaseFirestore.instance
        .collection('notifications')
        .where('patientId', isEqualTo: _patientId)
        .where('read', isEqualTo: false)
        .snapshots()
        .listen((snapshot) {
      if (mounted) {
        setState(() {
          _unreadNotifications = snapshot.docs.length;
        });
      }
    });
  }

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LoginPage()),
    );
  }

  void _onTap(int idx) => setState(() => _index = idx);

  @override
  Widget build(BuildContext context) {
    final isWideScreen = MediaQuery.of(context).size.width >= 900;

    if (!isWideScreen) {
      // Mobile version (No changes needed here for the sidebar/image card)
      return Scaffold(
        backgroundColor: Colors.grey[100],
        body: Column(
          children: [
            Expanded(
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.white, Colors.lightGreen],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: _pages[_index],
              ),
            ),
          ],
        ),
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _index,
          onTap: _onTap,
          type: BottomNavigationBarType.fixed,
          selectedItemColor: Colors.green,
          unselectedItemColor: Colors.grey,
          items: [
            const BottomNavigationBarItem(icon: Icon(Icons.home), label: "Home"),
            const BottomNavigationBarItem(icon: Icon(Icons.calendar_today), label: "Appointments"),
            const BottomNavigationBarItem(icon: Icon(Icons.add_circle_outline), label: "Book"),
            const BottomNavigationBarItem(icon: Icon(Icons.person), label: "Profile"),
            BottomNavigationBarItem(
              icon: Stack(
                clipBehavior: Clip.none,
                children: [
                  const Icon(Icons.notifications),
                  if (_unreadNotifications > 0)
                    Positioned(
                      right: -6,
                      top: -3,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
                        child: Center(
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 300),
                            transitionBuilder: (child, animation) =>
                                ScaleTransition(scale: animation, child: child),
                            child: Text(
                              '$_unreadNotifications',
                              key: ValueKey<int>(_unreadNotifications),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              label: "Notifications",
            ),
            const BottomNavigationBarItem(icon: Icon(Icons.bar_chart), label: "History"),
          ],
        ),
      );
    }

    // Web version with modern sidebar
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: Row(
        children: [
          // Sidebar Container (240px width, white background)
          Container(
            width: 240,
            color: Colors.white,
            child: Column(
              children: [
                // Logo and Clinic Name Header
                Container(
                  padding: const EdgeInsets.only(top: 20, bottom: 10, left: 10, right: 10),
                  child: Column(
                    children: [
                      Image.asset(
                        kIsWeb ? 'logo/TCDC-LOGO.png' : 'assets/logo/TCDC-LOGO.png',
                        height: 100,
                        errorBuilder: (context, error, stackTrace) {
                          return const Padding(
                            padding: EdgeInsets.all(8.0),
                            child: Icon(Icons.medical_services, size: 50, color: Colors.green),
                          );
                        },
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        "TOTAL CARE DIALYSIS CENTER",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Colors.green),
                      ),
                      const Text(
                        "TAGOLOAN BRANCH",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                            color: Colors.black54),
                      ),
                    ],
                  ),
                ),
                const Divider(),
                // NEW: Patient Info Card
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 8.0),
                  child: _PatientInfoCard(
                    username: _username,
                    email: _userEmail,
                    isLoading: _loadingName,
                  ),
                ),
                const Divider(),
                // Navigation Items
                _WebNavItem(icon: Icons.home_filled, label: "Home", index: 0, currentIndex: _index, onTap: _onTap),
                _WebNavItem(icon: Icons.calendar_today_outlined, label: "Appointments", index: 1, currentIndex: _index, onTap: _onTap),
                _WebNavItem(icon: Icons.add_box_outlined, label: "Book", index: 2, currentIndex: _index, onTap: _onTap),
                _WebNavItem(icon: Icons.person_outline, label: "Profile", index: 3, currentIndex: _index, onTap: _onTap),
                _WebNavItem(icon: Icons.notifications_none, label: "Notifications", index: 4, currentIndex: _index, onTap: _onTap, badgeCount: _unreadNotifications),
                _WebNavItem(icon: Icons.bar_chart_outlined, label: "History", index: 5, currentIndex: _index, onTap: _onTap),
                const Spacer(),
                ListTile(
                  leading: const Icon(Icons.logout, color: Colors.redAccent),
                  title: const Text("Logout", style: TextStyle(color: Colors.redAccent)),
                  onTap: _logout,
                ),
              ],
            ),
          ),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.white, Colors.lightGreen],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: _pages[_index],
            ),
          ),
        ],
      ),
    );
  }
}

// === NEW WIDGET: Patient Info Card ===
class _PatientInfoCard extends StatelessWidget {
  final String username;
  final String email;
  final bool isLoading;

  const _PatientInfoCard({
    required this.username,
    required this.email,
    required this.isLoading,
  });

  @override
  Widget build(BuildContext context) {
    // Determine the name to display (show email if username isn't loaded yet)
    final displayName = isLoading ? 'Loading...' : (username.isNotEmpty ? username : email);

    return Card(
      elevation: 0,
      color: Colors.green.shade50,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          children: [
            // Profile Icon/Placeholder
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.green.shade300,
                borderRadius: BorderRadius.circular(8),
              ),
              child: isLoading
                  ? const Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                ),
              )
                  : const Icon(
                Icons.person,
                color: Colors.white,
                size: 28,
              ),
            ),
            const SizedBox(width: 12),
            // Name and Email
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    displayName,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Colors.green.shade800,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    email,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.black54,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// === WIDGET: Navigation Item ===
class _WebNavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final int index;
  final int currentIndex;
  final void Function(int) onTap;
  final int badgeCount;

  const _WebNavItem({
    required this.icon,
    required this.label,
    required this.index,
    required this.currentIndex,
    required this.onTap,
    this.badgeCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = index == currentIndex;
    return ListTile(
      leading: Stack(
        clipBehavior: Clip.none,
        children: [
          Icon(icon, color: isSelected ? Colors.green : Colors.black54),
          if (badgeCount > 0 && index == 4)
            Positioned(
              right: -4,
              top: -4,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                child: Text(
                  '$badgeCount',
                  style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),
            ),
        ],
      ),
      title: Text(label, style: TextStyle(color: isSelected ? Colors.green : Colors.black54)),
      selected: isSelected,
      onTap: () => onTap(index),
    );
  }
}
