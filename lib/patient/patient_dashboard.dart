import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'dart:convert';

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
  String _userEmail = '';
  bool _loadingName = true;
  late final List<Widget> _pages;
  late final String _patientId;
  int _unreadNotifications = 0;
  String? _profileImageBase64;

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
    _userEmail = FirebaseAuth.instance.currentUser?.email ?? 'N/A';

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
    String? base64Image;

    try {
      final doc =
      await FirebaseFirestore.instance.collection('users').doc(_patientId).get();

      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        name = (data['username'] ?? data['fullName'] ?? '').toString();
        isVerified = data['verified'] == true;
        base64Image = data['profileImageBase64'];
      }
    } catch (_) {
      name = '';
    } finally {
      if (mounted) {
        setState(() {
          _username = name;
          _profileImageBase64 = base64Image;
          _loadingName = false;

          _pages[0] = HomePage(
            userId: _patientId,
            fullName: _username,
            onNavigate: _onTap,
          );

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

    // 📱 MOBILE LAYOUT
    if (!isWideScreen) {
      return Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          title: Text(_titles[_index]),
          backgroundColor: Colors.green,
          foregroundColor: Colors.white,
          elevation: 4,
          actions: [
            IconButton(
              icon: const Icon(Icons.logout),
              tooltip: 'Logout',
              onPressed: _logout,
            ),
          ],
        ),
        body: Container(
          width: double.infinity,
          height: double.infinity,
          color: Colors.white, // ✅ solid white background
          child: _pages[_index],
        ),
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _index,
          onTap: _onTap,
          type: BottomNavigationBarType.fixed,
          selectedItemColor: Colors.green,
          unselectedItemColor: Colors.grey,
          items: [
            const BottomNavigationBarItem(icon: Icon(Icons.home), label: "Home"),
            const BottomNavigationBarItem(
                icon: Icon(Icons.calendar_today), label: "Appointments"),
            const BottomNavigationBarItem(
                icon: Icon(Icons.add_circle_outline), label: "Book"),
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
                        constraints:
                        const BoxConstraints(minWidth: 20, minHeight: 20),
                        child: Center(
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 300),
                            transitionBuilder:
                                (child, animation) => ScaleTransition(
                              scale: animation,
                              child: child,
                            ),
                            child: Text(
                              '$_unreadNotifications',
                              key: ValueKey<int>(_unreadNotifications),
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              label: "Notifications",
            ),
            const BottomNavigationBarItem(
                icon: Icon(Icons.bar_chart), label: "History"),
          ],
        ),
      );
    }

    // 💻 WEB LAYOUT
    return Scaffold(
      backgroundColor: Colors.white,
      body: Row(
        children: [
          // ✅ Left sidebar
          Container(
            width: 240,
            color: Colors.white,
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  child: Column(
                    children: [
                      Image.asset(
                        kIsWeb
                            ? 'logo/TCDC-LOGO.png'
                            : 'assets/logo/TCDC-LOGO.png',
                        height: 100,
                        errorBuilder: (context, error, stackTrace) =>
                        const Icon(Icons.medical_services,
                            size: 50, color: Colors.green),
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
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10.0, vertical: 8.0),
                  child: _PatientInfoCard(
                    username: _username,
                    email: _userEmail,
                    isLoading: _loadingName,
                    profileImageBase64: _profileImageBase64,
                  ),
                ),
                const Divider(),
                _WebNavItem(
                    icon: Icons.home_filled,
                    label: "Home",
                    index: 0,
                    currentIndex: _index,
                    onTap: _onTap),
                _WebNavItem(
                    icon: Icons.calendar_today_outlined,
                    label: "Appointments",
                    index: 1,
                    currentIndex: _index,
                    onTap: _onTap),
                _WebNavItem(
                    icon: Icons.add_box_outlined,
                    label: "Book",
                    index: 2,
                    currentIndex: _index,
                    onTap: _onTap),
                _WebNavItem(
                    icon: Icons.person_outline,
                    label: "Profile",
                    index: 3,
                    currentIndex: _index,
                    onTap: _onTap),
                _WebNavItem(
                    icon: Icons.notifications_none,
                    label: "Notifications",
                    index: 4,
                    currentIndex: _index,
                    onTap: _onTap,
                    badgeCount: _unreadNotifications),
                _WebNavItem(
                    icon: Icons.bar_chart_outlined,
                    label: "History",
                    index: 5,
                    currentIndex: _index,
                    onTap: _onTap),
                const Spacer(),
                ListTile(
                  leading: const Icon(Icons.logout, color: Colors.black),
                  title: const Text("Logout",
                      style: TextStyle(color: Colors.black)),
                  onTap: _logout,
                ),
              ],
            ),
          ),

          // ✅ Main content (no green gradient)
          Expanded(
            child: Container(
              width: double.infinity,
              height: double.infinity,
              color: Colors.white, // solid white background
              padding: const EdgeInsets.all(24),
              child: _pages[_index],
            ),
          ),
        ],
      ),
    );
  }
}

// --- Supporting Widgets ---
class _PatientInfoCard extends StatelessWidget {
  final String username;
  final String email;
  final bool isLoading;
  final String? profileImageBase64;

  const _PatientInfoCard({
    required this.username,
    required this.email,
    required this.isLoading,
    this.profileImageBase64,
  });

  @override
  Widget build(BuildContext context) {
    final displayName =
    isLoading ? 'Loading...' : (username.isNotEmpty ? username : email);
    Widget profileWidget;

    if (isLoading) {
      profileWidget = const Center(
          child: SizedBox(
              width: 20,
              height: 20,
              child:
              CircularProgressIndicator(color: Colors.white, strokeWidth: 2)));
    } else if (profileImageBase64 != null && profileImageBase64!.isNotEmpty) {
      try {
        final imageBytes = base64Decode(profileImageBase64!);
        profileWidget = ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.memory(imageBytes,
                fit: BoxFit.cover, width: 48, height: 48));
      } catch (e) {
        profileWidget = const Icon(Icons.error, color: Colors.white, size: 28);
      }
    } else {
      profileWidget = const Icon(Icons.person, color: Colors.white, size: 28);
    }

    return Card(
      elevation: 0,
      color: Colors.green.shade50,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          children: [
            Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                    color: Colors.green.shade300,
                    borderRadius: BorderRadius.circular(8)),
                child: profileWidget),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(displayName,
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Colors.green.shade800),
                      overflow: TextOverflow.ellipsis),
                  Text(email,
                      style:
                      const TextStyle(fontSize: 12, color: Colors.black54),
                      overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ],
        ),
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
                decoration: const BoxDecoration(
                    color: Colors.red, shape: BoxShape.circle),
                child: Text('$badgeCount',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold)),
              ),
            ),
        ],
      ),
      title: Text(label,
          style: TextStyle(
              color: isSelected ? Colors.green : Colors.black54,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
      selected: isSelected,
      onTap: () => onTap(index),
    );
  }
}
