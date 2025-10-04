import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

// Admin pages
import 'admin_appointments.dart';
import 'admin_beds.dart';
import 'patient_management_page.dart';
import 'nurse_management_page.dart';
import 'notifications_page.dart';
import '../screens/login_page.dart';
import 'package:dialysis_app/reports/report_page.dart';

class AdminDashboard extends StatefulWidget {
  final String userId;
  const AdminDashboard({Key? key, required this.userId}) : super(key: key);

  @override
  _AdminDashboardState createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  int _index = 0;
  int _unreadNotifications = 0;
  late final List<Widget> _pages;

  // FIX: Declare and initialize the Future for the admin's profile data
  late Future<DocumentSnapshot<Map<String, dynamic>>> _adminProfileFuture;

  final List<String> _titles = [
    "Dashboard",
    "Patients",
    "Nurses",
    "Appointments",
    "Beds",
    "Notifications",
    "Reports"
  ];

  @override
  void initState() {
    super.initState();

    // Initialize the profile data fetch using the provided userId
    _adminProfileFuture = FirebaseFirestore.instance
        .collection('users')
        .doc(widget.userId)
        .get();

    _pages = [
      _buildDashboard(),
      PatientManagementPage(),
      NurseManagementPage(),
      AdminAppointmentsPage(),
      AdminBedsPage(),
      AdminNotificationPage(
        userId: widget.userId,
        onUnreadCountChanged: _updateUnreadCount,
      ),
      ReportsPage(role: "admin", userId: widget.userId),
    ];

    _listenUnreadNotifications();
  }

  void _listenUnreadNotifications() {
    FirebaseFirestore.instance
        .collection('notifications')
        .where('role', isEqualTo: 'admin')
        .where('isRead', isEqualTo: false)
        .snapshots()
        .listen((snapshot) {
      if (mounted) {
        setState(() {
          _unreadNotifications = snapshot.docs.length;
        });
      }
    });
  }

  void _updateUnreadCount(int newCount) {
    if (mounted) {
      setState(() {
        _unreadNotifications = newCount;
      });
    }
  }

  void _onTap(int idx) => setState(() => _index = idx);

  bool _isWideScreen(BuildContext context) =>
      MediaQuery.of(context).size.width >= 900;

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await FirebaseAuth.instance.signOut();
    await prefs.setBool('loggedIn', false);
    await prefs.remove('email');
    await prefs.remove('password');
    await prefs.setBool('rememberMe', false);

    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LoginPage()),
    );
  }

  Widget _buildDashboard() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Admin Dashboard",
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 12),
          // Removed 'const' keyword because we are using string interpolation
          // with a dynamic variable (widget.userId).
          Text(
            "Overview of patients, nurses, beds, and appointments. User ID: ${widget.userId}",
            style: const TextStyle(fontSize: 16, color: Colors.black54),
          ),
          const SizedBox(height: 24),
          LayoutBuilder(
            builder: (context, constraints) {
              int crossAxisCount = constraints.maxWidth > 1200
                  ? 4
                  : constraints.maxWidth > 800
                  ? 3
                  : 2;
              return GridView.count(
                crossAxisCount: crossAxisCount,
                crossAxisSpacing: 24,
                mainAxisSpacing: 24,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _dashboardCard(
                    "Total Patients",
                    Icons.people,
                    Colors.blue,
                    FirebaseFirestore.instance.collection('users').where('role', isEqualTo: 'patient').count().get(),
                  ),
                  _dashboardCard(
                    "Total Nurses",
                    Icons.health_and_safety,
                    Colors.green,
                    FirebaseFirestore.instance.collection('users').where('role', isEqualTo: 'nurse').count().get(),
                  ),
                  _dashboardCard(
                    "Total Beds",
                    Icons.chair,
                    Colors.orange,
                    FirebaseFirestore.instance.collection('beds').count().get(),
                  ),
                  _dashboardCard(
                    "Total Appointments",
                    Icons.calendar_today,
                    Colors.purple,
                    FirebaseFirestore.instance.collection('appointments').count().get(),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 32),
          const Text(
            "Bed Status",
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              return StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection('beds').snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError) {
                    return const Center(child: Text('Error loading bed status.'));
                  }

                  final beds = snapshot.data!.docs;
                  int workingBeds = beds.where((doc) => doc['isWorking'] == true).length;
                  int occupiedBeds = beds.where((doc) => (doc['assignedPatients'] as List? ?? []).isNotEmpty).length;
                  int availableBeds = workingBeds - occupiedBeds;

                  return GridView.count(
                    crossAxisCount: constraints.maxWidth > 800 ? 3 : 1,
                    crossAxisSpacing: 24,
                    mainAxisSpacing: 24,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      _dashboardBedCard("Beds Working", workingBeds, Icons.bed, Colors.green),
                      _dashboardBedCard("Beds Occupied", occupiedBeds, Icons.hotel, Colors.orange),
                      _dashboardBedCard("Beds Available", availableBeds, Icons.event_available, Colors.blue),
                    ],
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _dashboardCard(String title, IconData icon, Color color, Future<AggregateQuerySnapshot> query) {
    return FutureBuilder<AggregateQuerySnapshot>(
      future: query,
      builder: (context, snapshot) {
        int count = snapshot.hasData ? snapshot.data!.count ?? 0 : 0;
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.1),
                spreadRadius: 1,
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                backgroundColor: color.withOpacity(0.1),
                child: Icon(icon, color: color),
              ),
              const SizedBox(height: 16),
              Text(count.toString(),
                  style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87)),
              const SizedBox(height: 8),
              Text(title,
                  style: const TextStyle(
                      fontSize: 16,
                      color: Colors.black54,
                      fontWeight: FontWeight.w500)),
            ],
          ),
        );
      },
    );
  }

  Widget _dashboardBedCard(String title, int count, IconData icon, Color color) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            backgroundColor: color.withOpacity(0.1),
            child: Icon(icon, color: color),
          ),
          const SizedBox(height: 16),
          Text(count.toString(),
              style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87)),
          const SizedBox(height: 8),
          Text(title,
              style: const TextStyle(
                  fontSize: 16,
                  color: Colors.black54,
                  fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    if (!_isWideScreen(context)) {
      return Scaffold(
        appBar: AppBar(
          title: Text(_titles[_index]),
          actions: [
            IconButton(icon: const Icon(Icons.logout), onPressed: _logout)
          ],
        ),
        body: _pages[_index],
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _index,
          onTap: _onTap,
          type: BottomNavigationBarType.fixed,
          selectedItemColor: Colors.green,
          unselectedItemColor: Colors.grey,
          items: [
            const BottomNavigationBarItem(
                icon: Icon(Icons.dashboard), label: "Dashboard"),
            const BottomNavigationBarItem(
                icon: Icon(Icons.people), label: "Patients"),
            const BottomNavigationBarItem(
                icon: Icon(Icons.health_and_safety), label: "Nurses"),
            const BottomNavigationBarItem(
                icon: Icon(Icons.calendar_today), label: "Appointments"),
            const BottomNavigationBarItem(icon: Icon(Icons.chair), label: "Beds"),
            BottomNavigationBarItem(
              icon: Stack(
                clipBehavior: Clip.none,
                children: [
                  const Icon(Icons.notifications),
                  if (_unreadNotifications > 0)
                    Positioned(
                      right: -4,
                      top: -4,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        constraints:
                        const BoxConstraints(minWidth: 18, minHeight: 18),
                        child: Text(
                          "$_unreadNotifications",
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              ),
              label: "Notifications",
            ),
            const BottomNavigationBarItem(
                icon: Icon(Icons.bar_chart), label: "Reports"),
          ],
        ),
      );
    }

    // Web Layout (Clean, Professional Admin Panel Look)
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: Row(
        children: [
          Container(
            width: 240,
            color: Colors.white,
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.only(top: 20, bottom: 10, left: 10, right: 10),
                  child: Column(
                    children: [
                      // Logo
                      Image.asset(
                        kIsWeb ? 'logo/TCDC-LOGO.png' : 'assets/logo/TCDC-LOGO.png',
                        height: 100,
                        errorBuilder: (context, error, stackTrace) {
                          return const Padding(
                            padding: EdgeInsets.all(8.0),
                            child: Icon(Icons.broken_image, size: 50, color: Colors.red),
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
                const Divider(height: 1, color: Colors.black12),

                // --- 2. Admin Profile Section ---
                FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                  future: _adminProfileFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const ListTile(
                          title: Text("Loading Profile..."),
                          leading: CircularProgressIndicator.adaptive());
                    }
                    // Updated null check to safely access snapshot.data
                    if (snapshot.hasError || !snapshot.hasData || snapshot.data == null || !snapshot.data!.exists) {
                      return const ListTile(
                          title: Text("Profile Error"),
                          leading: Icon(Icons.person));
                    }

                    final data = snapshot.data!.data();
                    final adminName = data?['fullName'] ?? 'Admin User';
                    final adminEmail = data?['email'] ?? 'Unknown Email';

                    return Container(
                      padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 10),
                      margin: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          const CircleAvatar(
                            backgroundColor: Colors.green,
                            child: Icon(Icons.admin_panel_settings, color: Colors.white), // Changed icon to admin-specific
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  adminName,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold, fontSize: 14),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  adminEmail,
                                  style: const TextStyle(
                                      fontSize: 10, color: Colors.black54),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
                _WebNavItem(
                    icon: Icons.dashboard,
                    label: "Dashboard",
                    index: 0,
                    currentIndex: _index,
                    onTap: _onTap),
                _WebNavItem(
                    icon: Icons.people,
                    label: "Patients",
                    index: 1,
                    currentIndex: _index,
                    onTap: _onTap),
                _WebNavItem(
                    icon: Icons.health_and_safety,
                    label: "Nurses",
                    index: 2,
                    currentIndex: _index,
                    onTap: _onTap),
                _WebNavItem(
                    icon: Icons.calendar_today,
                    label: "Appointments",
                    index: 3,
                    currentIndex: _index,
                    onTap: _onTap),
                _WebNavItem(
                    icon: Icons.chair,
                    label: "Beds",
                    index: 4,
                    currentIndex: _index,
                    onTap: _onTap),
                _WebNavItem(
                    icon: Icons.notifications_none,
                    label: "Notifications",
                    index: 5,
                    currentIndex: _index,
                    onTap: _onTap,
                    badgeCount: _unreadNotifications),
                _WebNavItem(
                    icon: Icons.bar_chart,
                    label: "Reports",
                    index: 6,
                    currentIndex: _index,
                    onTap: _onTap),
                const Spacer(),
                ListTile(
                  leading: const Icon(Icons.logout, color: Colors.black),
                  title: const Text("Logout",
                      style: TextStyle(color: Colors.black)),
                  onTap: _logout,
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
          Expanded(
            child: Container(
              color: Colors.white, // Changed from gradient to white
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: _pages[_index],
              ),
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
          if (badgeCount > 0 && index == 5)
            Positioned(
              right: -4,
              top: -4,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                    color: Colors.red, shape: BoxShape.circle),
                child: Text(
                  '$badgeCount',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold),
                ),
              ),
            ),
        ],
      ),
      title: Text(label,
          style: TextStyle(
              color: isSelected ? Colors.green : Colors.black54)),
      selected: isSelected,
      onTap: () => onTap(index),
    );
  }
}
