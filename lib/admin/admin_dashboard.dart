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
    await prefs.clear();

    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LoginPage()),
    );
  }

  // --------------------------- Dashboard Layout ---------------------------
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
          Text(
            "Overview of patients, nurses, beds, and appointments • User ID: ${widget.userId}",
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
                    FirebaseFirestore.instance
                        .collection('users')
                        .where('role', isEqualTo: 'patient')
                        .count()
                        .get(),
                  ),
                  _dashboardCard(
                    "Total Nurses",
                    Icons.health_and_safety,
                    Colors.green,
                    FirebaseFirestore.instance
                        .collection('users')
                        .where('role', isEqualTo: 'nurse')
                        .count()
                        .get(),
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
                    FirebaseFirestore.instance
                        .collection('appointments')
                        .count()
                        .get(),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 40),
          const Text(
            "Overall Bed Utilization",
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('beds').snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final beds = snapshot.data!.docs;
              final totalBeds = beds.length;
              final occupied = beds
                  .where((doc) =>
              (doc['assignedPatients'] as List? ?? []).isNotEmpty)
                  .length;
              final value = totalBeds == 0 ? 0.0 : occupied / totalBeds;

              return Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: const [
                    BoxShadow(
                        color: Colors.black12,
                        blurRadius: 8,
                        offset: Offset(0, 4)),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    LinearProgressIndicator(
                      value: value,
                      minHeight: 12,
                      borderRadius: BorderRadius.circular(8),
                      backgroundColor: Colors.grey[300],
                      color: Colors.green,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "$occupied of $totalBeds beds currently in use",
                      style:
                      const TextStyle(fontSize: 16, color: Colors.black54),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // --------------------------- Dashboard Cards ---------------------------
  Widget _dashboardCard(String title, IconData icon, Color color,
      Future<AggregateQuerySnapshot> query) {
    return FutureBuilder<AggregateQuerySnapshot>(
      future: query,
      builder: (context, snapshot) {
        final count = snapshot.hasData ? snapshot.data!.count ?? 0 : 0;
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: const [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 8,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 32),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontSize: 16,
                          color: Colors.black54,
                          fontWeight: FontWeight.w500)),
                  const SizedBox(height: 6),
                  Text('$count',
                      style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: color)),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  // --------------------------- Web Layout ---------------------------
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
            const BottomNavigationBarItem(
                icon: Icon(Icons.chair), label: "Beds"),
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
                            color: Colors.red, shape: BoxShape.circle),
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

    // Web Layout
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: Row(
        children: [
          // ---------------- Sidebar ----------------
          Container(
            width: 240,
            color: Colors.white,
            child: Column(
              children: [
                const SizedBox(height: 20),
                Image.asset(
                  kIsWeb
                      ? 'logo/TCDC-LOGO.png'
                      : 'assets/logo/TCDC-LOGO.png',
                  height: 90,
                  errorBuilder: (_, __, ___) => const Icon(Icons.broken_image,
                      size: 50, color: Colors.red),
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
                const Divider(height: 24, color: Colors.black12),
                FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                  future: _adminProfileFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const ListTile(
                          title: Text("Loading Profile..."),
                          leading: CircularProgressIndicator.adaptive());
                    }
                    if (snapshot.hasError ||
                        !snapshot.hasData ||
                        snapshot.data == null ||
                        !snapshot.data!.exists) {
                      return const ListTile(
                          title: Text("Profile Error"),
                          leading: Icon(Icons.person));
                    }

                    final data = snapshot.data!.data();
                    final adminName = data?['fullName'] ?? 'Admin User';
                    final adminEmail = data?['email'] ?? 'Unknown Email';

                    return Container(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 10),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          const CircleAvatar(
                            backgroundColor: Colors.green,
                            child: Icon(Icons.admin_panel_settings,
                                color: Colors.white),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(adminName,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14),
                                    overflow: TextOverflow.ellipsis),
                                Text(adminEmail,
                                    style: const TextStyle(
                                        fontSize: 10, color: Colors.black54),
                                    overflow: TextOverflow.ellipsis),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
                const Divider(color: Colors.black12),
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
                  leading:
                  const Icon(Icons.logout, color: Colors.black54),
                  title: const Text("Logout",
                      style: TextStyle(color: Colors.black)),
                  onTap: _logout,
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
          // ---------------- Main Content ----------------
          Expanded(
            child: Container(
              color: Colors.white,
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
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: isSelected ? Colors.green.withOpacity(0.1) : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListTile(
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
                color: isSelected ? Colors.green : Colors.black54,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal)),
        onTap: () => onTap(index),
      ),
    );
  }
}
