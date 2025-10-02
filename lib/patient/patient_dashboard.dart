import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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

    _pages = [
      const Center(child: CircularProgressIndicator()), // Home placeholder
      PatientAppointmentsPage(userId: _patientId),
      const Center(child: CircularProgressIndicator()), // Book placeholder
      ProfilePage(userId: _patientId),
      PatientNotificationPage(userId: _patientId),
      ReportsPage(role: "patient", userId: _patientId),
    ];

    _loadUsername();
    _listenUnreadNotifications();
  }

  Future<void> _loadUsername() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(_patientId)
          .get();

      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        _username = (data['username'] ?? data['fullName'] ?? '').toString();
        final isVerified = data['verified'] == true;

        _pages[2] = isVerified
            ? SafeArea(child: booking.BookPage(userId: _patientId))
            : Center(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Text(
              "Booking is disabled until your account is verified.\n\n"
                  "Please pass all requirements to the admin.",
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18, color: Colors.grey),
            ),
          ),
        );
      }
    } catch (_) {
      _username = '';
    } finally {
      if (mounted) {
        setState(() {
          _loadingName = false;
          _pages[0] = HomePage(username: _username);
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
      // Mobile version with login/register theme
      return Scaffold(
        backgroundColor: Colors.grey[100],
        body: Column(
          children: [
            // No top navbar for mobile, just themed body
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
          Container(
            width: 240,
            color: Colors.green.shade50,
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  alignment: Alignment.centerLeft,
                  child: const Text(
                    "Clinic Appointment",
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.green),
                  ),
                ),
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
