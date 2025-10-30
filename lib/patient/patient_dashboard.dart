import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import 'appointment_page.dart';
import 'book_page.dart' as booking;
import 'notification_page.dart';
import 'profile_page.dart';
import 'home_page.dart'; // Ensure this uses your updated HomePage code
import '../screens/login_page.dart';
import 'package:dialysis_app/reports/report_page.dart';

// --------------------------------------------------------------------------
// 1. FLOATING MANUAL LOGIC (DRAGGABLE MANUAL BUTTON)
// --------------------------------------------------------------------------

/// Helper function to build the content inside the manual pop-up.
Widget _buildBookingManualContent(BuildContext context, Function(int) onTap) {
  return SingleChildScrollView(
    padding: const EdgeInsets.all(20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _manualStep(1, "Open Book → Choose a date & slot",
            "Navigate to the 'Book Appointment' page and select your desired date. Available slots will be highlighted based on clinic capacity."),
        _manualStep(2, "Pick an available bed",
            "Choose one of the open time slots (e.g., '07:30 - 11:30'). Confirm the details before proceeding."),
        _manualStep(3, "Submit Request",
            "Tap the 'Confirm Booking' button. Your request will be sent to the nurse for review. The status will initially show as 'Pending'."),
        _manualStep(4, "Wait for Approval",
            "A nurse will review your request. Check your 'Appointments' section. When approved, the status will change to 'Approved', and a bed will be assigned."),
        _manualStep(5, "Confirmation",
            "You will receive a notification 30 minutes before your approved appointment time. Please arrive at the clinic 15 minutes before the scheduled start."),
        const SizedBox(height: 20),
        Center(
          child: ElevatedButton.icon(
            onPressed: () => onTap(2), // Navigate to Book tab (index 2)
            icon: const Icon(Icons.add),
            label: const Text("Go to Book"),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue.shade600, foregroundColor: Colors.white),
          ),
        )
      ],
    ),
  );
}

Widget _manualStep(int step, String title, String description) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 20),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: Colors.blue.shade700,
            shape: BoxShape.circle,
          ),
          child: Center(
              child: Text('$step',
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold))),
        ),
        const SizedBox(width: 15),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(description),
            ],
          ),
        ),
      ],
    ),
  );
}

class DraggableManualButton extends StatefulWidget {
  final Widget manualContent;

  const DraggableManualButton({
    super.key,
    required this.manualContent,
  });

  @override
  State<DraggableManualButton> createState() => _DraggableManualButtonState();
}

class _DraggableManualButtonState extends State<DraggableManualButton> {
  double top = 50;
  double left = 50;
  bool isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;

    if (top == 50 && left == 50) {
      top = screenSize.height - 150;
      left = screenSize.width - 80;
    }

    return Stack(
      children: [
        if (isExpanded)
          Positioned.fill(
            child: GestureDetector(
              onTap: () => setState(() => isExpanded = false),
              child: Container(
                color: Colors.black54,
                child: Center(
                  child: Container(
                    width: screenSize.width * 0.9,
                    height: screenSize.height * 0.7,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 20,
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text("Booking Instructions 📚",
                                  style: TextStyle(
                                      fontSize: 20, fontWeight: FontWeight.bold)),
                              IconButton(
                                icon: const Icon(Icons.close, color: Colors.red),
                                onPressed: () => setState(() => isExpanded = false),
                              ),
                            ],
                          ),
                        ),
                        const Divider(height: 1),
                        Expanded(child: widget.manualContent),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        Positioned(
          top: top,
          left: left,
          child: Draggable(
            feedback: _buildChatHead(isDragging: true),
            childWhenDragging: Container(),
            onDragEnd: (details) {
              setState(() {
                final maxTop = screenSize.height - 100.0;
                final maxLeft = screenSize.width - 70.0;
                top = details.offset.dy.clamp(50.0, maxTop);
                left = details.offset.dx.clamp(10.0, maxLeft);
              });
            },
            child: _buildChatHead(onTap: () => setState(() => isExpanded = true)),
          ),
        ),
      ],
    );
  }

  Widget _buildChatHead({bool isDragging = false, VoidCallback? onTap}) {
    return Material(
      color: Colors.transparent,
      child: GestureDetector(
        onTap: isExpanded ? null : onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isDragging ? Colors.blue.shade300 : Colors.blue.shade600,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDragging ? 0.3 : 0.15),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Center(
            child: Icon(Icons.help_outline, color: Colors.white, size: 30),
          ),
        ),
      ),
    );
  }
}

// --------------------------------------------------------------------------
// 2. PATIENT DASHBOARD (FIXED)
// --------------------------------------------------------------------------

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

    // placeholders — will be replaced after loading username
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
        base64Image = (data['profileImageBase64'] as String?) ?? data['profileImage'];
      }
    } catch (_) {
      name = '';
    } finally {
      if (!mounted) return;
      setState(() {
        _username = name;
        _profileImageBase64 = base64Image;
        _loadingName = false;

        // FIX: HomeWrapper removed. HomePage is placed directly in the list.
        _pages[0] = HomePage(
          userId: _patientId,
          fullName: _username,
          onNavigate: _onTap,
          // Add a dummy argument since the parent now handles the manual content
          buildManualContent: () => const SizedBox.shrink(),
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

    // Mobile layout
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
        body: Stack( // FIX: Stack added for the floating button on mobile
          children: [
            Container(
              width: double.infinity,
              height: double.infinity,
              color: Colors.white,
              child: _pages[_index],
            ),
            // Floating Button on top of mobile content
            DraggableManualButton(
              manualContent: _buildBookingManualContent(context, _onTap),
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

    // Web layout
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack( // FIX: The main Stack that allows the DraggableButton to float
        children: [
          Row(
            children: [
              // Sidebar
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
                            kIsWeb ? 'logo/TCDC-LOGO.png' : 'assets/logo/TCDC-LOGO.png',
                            height: 100,
                            errorBuilder: (context, error, stackTrace) =>
                            const Icon(Icons.medical_services, size: 50, color: Colors.green),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            "TOTAL CARE DIALYSIS CENTER",
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.green),
                          ),
                          const Text(
                            "TAGOLOAN BRANCH",
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: Colors.black54),
                          ),
                        ],
                      ),
                    ),
                    const Divider(),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 8.0),
                      child: _PatientInfoCard(
                        username: _username,
                        email: _userEmail,
                        isLoading: _loadingName,
                        profileImageBase64: _profileImageBase64,
                      ),
                    ),
                    const Divider(),
                    _WebNavItem(icon: Icons.home_filled, label: "Home", index: 0, currentIndex: _index, onTap: _onTap),
                    _WebNavItem(icon: Icons.calendar_today_outlined, label: "Appointments", index: 1, currentIndex: _index, onTap: _onTap),
                    _WebNavItem(icon: Icons.add_box_outlined, label: "Book", index: 2, currentIndex: _index, onTap: _onTap),
                    _WebNavItem(icon: Icons.person_outline, label: "Profile", index: 3, currentIndex: _index, onTap: _onTap),
                    _WebNavItem(icon: Icons.notifications_none, label: "Notifications", index: 4, currentIndex: _index, onTap: _onTap, badgeCount: _unreadNotifications),
                    _WebNavItem(icon: Icons.bar_chart_outlined, label: "History", index: 5, currentIndex: _index, onTap: _onTap),
                    const Spacer(),
                    ListTile(
                      leading: const Icon(Icons.logout, color: Colors.black),
                      title: const Text("Logout", style: TextStyle(color: Colors.black)),
                      onTap: _logout,
                    ),
                  ],
                ),
              ),

              // Main content
              Expanded(
                child: Container(
                  width: double.infinity,
                  height: double.infinity,
                  color: Colors.white,
                  padding: const EdgeInsets.all(24),
                  child: _pages[_index],
                ),
              ),
            ],
          ),

          // 2. The Floating Chat Head (Overlay) - Always on top
          DraggableManualButton(
            manualContent: _buildBookingManualContent(context, _onTap),
          ),
        ],
      ),
    );
  }
}

// --------------------------------------------------------------------------
// 3. HELPER WIDGETS (Unchanged)
// --------------------------------------------------------------------------

/// Helper widget for the Patient Info Card in the sidebar
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
    final displayName = isLoading ? 'Loading...' : (username.isNotEmpty ? username : email);
    Widget profileWidget;

    if (isLoading) {
      profileWidget = const Center(
          child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)));
    } else if (profileImageBase64 != null && profileImageBase64!.isNotEmpty) {
      try {
        final imageBytes = base64Decode(profileImageBase64!);
        profileWidget = ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.memory(imageBytes, fit: BoxFit.cover, width: 48, height: 48));
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
            Container(width: 48, height: 48, decoration: BoxDecoration(color: Colors.green.shade300, borderRadius: BorderRadius.circular(8)), child: profileWidget),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(displayName, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.green.shade800), overflow: TextOverflow.ellipsis),
                Text(email, style: const TextStyle(fontSize: 12, color: Colors.black54), overflow: TextOverflow.ellipsis),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}

/// Helper widget for the Web Navigation Items in the sidebar
class _WebNavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final int index;
  final int currentIndex;
  final void Function(int) onTap;
  final int badgeCount;

  const _WebNavItem({required this.icon, required this.label, required this.index, required this.currentIndex, required this.onTap, this.badgeCount = 0});

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
                child: Text('$badgeCount', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
              ),
            ),
        ],
      ),
      title: Text(label, style: TextStyle(color: isSelected ? Colors.green : Colors.black54, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
      selected: isSelected,
      onTap: () => onTap(index),
    );
  }
}