import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../screens/login_page.dart';
import 'nurse_patients_page.dart';
import 'nurse_appointments.dart';
import 'nurse_notifications.dart';
import 'package:dialysis_app/reports/report_page.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

// --- Imports for Dashboard Widgets ---
import 'package:fl_chart/fl_chart.dart'; // For the circular chart
import 'package:table_calendar/table_calendar.dart'; // For the calendar widget
import 'package:intl/intl.dart'; // For date formatting
// --- End: Imports for Dashboard Widgets ---


class NurseDashboard extends StatefulWidget {
  final String nurseId;
  const NurseDashboard({super.key, required this.nurseId});

  @override
  State<NurseDashboard> createState() => _NurseDashboardState();
}

class _NurseDashboardState extends State<NurseDashboard> {
  int _currentIndex = 0;
  late final String _nurseId;
  int _unreadNotifications = 0;
  Future<DocumentSnapshot>? _nurseProfileFuture;

  // --- State Variables ---
  DateTime _selectedDay = DateTime.now();
  DateTime _focusedDay = DateTime.now();
  int _patientsWithSchedule = 0;
  int _patientsWithoutSchedule = 0;
  // Define the common height for the two middle cards for alignment
  static const double _cardHeight = 350.0;
  // --- End: State Variables ---

  late final List<Widget> _pages;
  final List<String> _titles = [
    "Home",
    "Patients",
    "Appointments",
    "Notifications",
    "Reports"
  ];

  @override
  void initState() {
    super.initState();
    _nurseId = widget.nurseId;

    _pages = [
      _buildHomeTab(),
      NursePatientsPage(nurseId: _nurseId),
      NurseAppointmentsPage(nurseId: _nurseId),
      NurseNotificationPage(userId: _nurseId),
      ReportsPage(role: "nurse", userId: _nurseId),
    ];

    _nurseProfileFuture = _fetchNurseProfile();
    _listenUnreadNotifications();
    _fetchPatientScheduleSummary();
  }

  // --- Data Fetching Methods (No changes needed here) ---

  Future<void> _fetchPatientScheduleSummary() async {
    final allPatientsSnapshot = await FirebaseFirestore.instance
        .collection('users')
        .where('role', isEqualTo: 'patient')
        .get();

    DateTime startOfToday = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);

    final appointmentsSnapshot = await FirebaseFirestore.instance
        .collection('appointments')
        .where('date', isGreaterThanOrEqualTo: startOfToday)
        .get();

    final allPatientIds = allPatientsSnapshot.docs.map((doc) => doc.id).toSet();
    final patientsWithAppointments = appointmentsSnapshot.docs
        .map((doc) => doc['patientId'] as String)
        .toSet();

    if (mounted) {
      setState(() {
        _patientsWithSchedule = patientsWithAppointments.length;
        _patientsWithoutSchedule = allPatientIds.difference(patientsWithAppointments).length;
      });
    }
  }

  Future<int> _fetchDailyAppointmentCount(DateTime day) async {
    DateTime startOfDay = DateTime(day.year, day.month, day.day);
    DateTime endOfDay = DateTime(day.year, day.month, day.day, 23, 59, 59);

    final snapshot = await FirebaseFirestore.instance
        .collection('appointments')
        .where('date', isGreaterThanOrEqualTo: startOfDay)
        .where('date', isLessThanOrEqualTo: endOfDay)
        .get();
    return snapshot.docs.length;
  }

  Future<DocumentSnapshot> _fetchNurseProfile() {
    return FirebaseFirestore.instance.collection('users').doc(_nurseId).get();
  }

  void _listenUnreadNotifications() {
    FirebaseFirestore.instance
        .collection('notifications')
        .where('nurseId', whereIn: [_nurseId, 'all'])
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

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    final remember = prefs.getBool('rememberMe') ?? false;

    await FirebaseAuth.instance.signOut();
    await prefs.setBool('loggedIn', false);

    if (!remember) {
      await prefs.remove('email');
      await prefs.remove('password');
      await prefs.setBool('rememberMe', false);
    }

    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LoginPage()),
    );
  }

  // --- UI Helpers ---

  bool _isWideScreen(BuildContext context) =>
      MediaQuery.of(context).size.width >= 650;

  void _onTap(int idx) => setState(() => _currentIndex = idx);

  // ----------------------------------------------------------------------------------
  // --- REDESIGNED: HOME TAB WITH EQUAL HEIGHT CARDS ---
  // ----------------------------------------------------------------------------------
  Widget _buildHomeTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.only(top: 0),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 28.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Dashboard",
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              "Quick overview of appointment, capacity, and patient statistics.",
              style: TextStyle(fontSize: 16, color: Colors.black54),
            ),
            const SizedBox(height: 30),

            LayoutBuilder(
              builder: (context, constraints) {
                bool isWideLayout = constraints.maxWidth > 600;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. TOP ROW: CALENDAR (Full Width)
                    _buildCalendarCard(),

                    const SizedBox(height: 20),

                    // 2. MIDDLE ROW: SCHEDULE SUMMARY & DAILY CAPACITY CHART (Equal Height)
                    isWideLayout
                        ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 5,
                          // WRAP IN SIZEDBOX FOR FIXED HEIGHT
                          child: SizedBox(
                              height: _cardHeight,
                              child: _buildScheduleSummaryCard()),
                        ),
                        const SizedBox(width: 20),
                        Expanded(
                          flex: 5,
                          // WRAP IN SIZEDBOX FOR FIXED HEIGHT
                          child: SizedBox(
                              height: _cardHeight,
                              child: _buildDailyCapacityCard(context)),
                        ),
                      ],
                    )
                        : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildScheduleSummaryCard(),
                        const SizedBox(height: 20),
                        _buildDailyCapacityCard(context),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // 3. BOTTOM ROW: TOP PATIENTS TABLE (Full Width)
                    _buildTopAppointmentsTable(),

                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }


  /// --- DATA VISUALIZATION WIDGETS ---

  // Patient Schedule Summary Card (Removed fixed height container)
  Widget _buildScheduleSummaryCard() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      elevation: 4,
      // Removed Container with fixed padding/height, let the content define it
      child: Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Patient Schedule Summary",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 15),
            _summaryRow(
              "Patients with Future Schedule",
              _patientsWithSchedule,
              Colors.blue,
              Icons.check_circle_outline,
            ),
            const Divider(),
            _summaryRow(
              "Patients without Future Schedule",
              _patientsWithoutSchedule,
              Colors.red,
              Icons.cancel_outlined,
            ),
            // Added Spacer to push content up and ensure the card fills the height
            const Spacer(),
          ],
        ),
      ),
    );
  }

  // Helper for Schedule Summary Rows (No change)
  Widget _summaryRow(String title, int count, Color color, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(fontSize: 16),
              ),
            ],
          ),
          Text(
            count.toString(),
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  // Daily Capacity Card (Circular Chart) (Removed fixed height container)
  Widget _buildDailyCapacityCard(BuildContext context) {
    const int maxDailyCapacity = 64;

    return FutureBuilder<int>(
      future: _fetchDailyAppointmentCount(_selectedDay),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          // Changed height to match _cardHeight
          return Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            elevation: 4,
            child: const SizedBox(
                height: _cardHeight,
                child: Center(child: CircularProgressIndicator())),
          );
        }

        int scheduledCount = snapshot.data ?? 0;
        int remainingCapacity = maxDailyCapacity - scheduledCount;
        double scheduledPercentage = maxDailyCapacity > 0 ? (scheduledCount / maxDailyCapacity) * 100 : 0;

        if (remainingCapacity < 0) remainingCapacity = 0;

        int chartScheduledCount = scheduledCount > maxDailyCapacity ? maxDailyCapacity : scheduledCount;

        return Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          elevation: 4,
          child: Container(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Daily Capacity - ${DateFormat('MMM d, yyyy').format(_selectedDay)}",
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),
                Expanded( // Use Expanded inside the column to let PieChart take available space
                  child: PieChart(
                    PieChartData(
                      sectionsSpace: 2,
                      centerSpaceRadius: 50,
                      sections: [
                        PieChartSectionData(
                          color: Colors.lightGreen,
                          value: chartScheduledCount.toDouble(),
                          title: scheduledCount > 0 ? '${scheduledPercentage.toStringAsFixed(1)}%' : '',
                          radius: 70,
                          titleStyle: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        PieChartSectionData(
                          color: Colors.grey.shade300,
                          value: remainingCapacity.toDouble(),
                          title: remainingCapacity > 0 ? 'Remaining' : '',
                          radius: 60,
                          titleStyle: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Center(
                  child: Text(
                    "Scheduled: $scheduledCount / $maxDailyCapacity Patients",
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: scheduledCount > maxDailyCapacity ? Colors.red : Colors.black87
                    ),
                  ),
                ),
                if (scheduledCount > maxDailyCapacity)
                  const Center(
                    child: Text(
                      "Alert: Daily capacity exceeded!",
                      style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Calendar Card (Top) (No change)
  Widget _buildCalendarCard() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      elevation: 4,
      child: TableCalendar(
        firstDay: DateTime.utc(2020, 1, 1),
        lastDay: DateTime.utc(2030, 12, 31),
        focusedDay: _focusedDay,
        selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
        calendarFormat: CalendarFormat.month,
        headerStyle: const HeaderStyle(
          formatButtonVisible: false,
          titleCentered: true,
        ),
        onDaySelected: (selectedDay, focusedDay) {
          if (!isSameDay(_selectedDay, selectedDay)) {
            setState(() {
              _selectedDay = selectedDay;
              _focusedDay = focusedDay;
            });
          }
        },
        onPageChanged: (focusedDay) {
          _focusedDay = focusedDay;
        },
      ),
    );
  }

  // --- NEW Custom Table Row Widget for Full Width ---
  Widget _buildCustomTableRow({
    required Widget name,
    required Widget address,
    required Widget email,
    required Widget contact,
    required Widget count,
    bool isHeader = false,
  }) {
    // Custom table layout using Expanded with flex to control width
    // Name and Address get more space (flex: 3 and 3)
    // Email and Contact get moderate space (flex: 2 and 2)
    // Count gets minimal space (flex: 1)
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      decoration: BoxDecoration(
        color: isHeader ? Colors.green.shade50 : null,
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade200, width: 1),
        ),
      ),
      child: Row(
        children: [
          Expanded(flex: 3, child: name),
          Expanded(flex: 3, child: address),
          Expanded(flex: 2, child: email),
          Expanded(flex: 2, child: contact),
          Expanded(flex: 1, child: Align(alignment: Alignment.centerRight, child: count)),
        ],
      ),
    );
  }

  // Top Appointments Table (Redesigned with custom Expanded Row logic)
  Widget _buildTopAppointmentsTable() {
    return FutureBuilder<QuerySnapshot>(
      future: FirebaseFirestore.instance.collection('appointments').get(),
      builder: (context, appointmentSnapshot) {
        if (appointmentSnapshot.connectionState == ConnectionState.waiting) {
          return Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            elevation: 4,
            child: const SizedBox(height: 250, child: Center(child: CircularProgressIndicator())),
          );
        }
        if (appointmentSnapshot.hasError || !appointmentSnapshot.hasData) {
          return const Center(child: Text("Error loading appointments."));
        }

        Map<String, int> patientAppointmentCounts = {};
        for (var doc in appointmentSnapshot.data!.docs) {
          final patientId = doc['patientId'] as String;
          patientAppointmentCounts.update(patientId, (value) => value + 1, ifAbsent: () => 1);
        }

        final sortedPatients = patientAppointmentCounts.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));
        final topAppointments = sortedPatients.take(5).toList();

        final requiredUserIds = topAppointments.map((e) => e.key).toList();

        if (requiredUserIds.isEmpty) {
          return _buildEmptyAppointmentsTable();
        }

        // 3. Fetch Patient Details (Name, Email, Address, Contact)
        return FutureBuilder<QuerySnapshot>(
          future: FirebaseFirestore.instance.collection('users').where(FieldPath.documentId, whereIn: requiredUserIds).get(),
          builder: (context, userSnapshot) {
            if (userSnapshot.connectionState == ConnectionState.waiting) {
              return Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                elevation: 4,
                child: const SizedBox(height: 250, child: Center(child: CircularProgressIndicator())),
              );
            }
            if (userSnapshot.hasError || !userSnapshot.hasData) {
              return const Center(child: Text("Error loading patient names."));
            }

            final patientDetails = {
              for (var doc in userSnapshot.data!.docs) doc.id: {
                'fullName': doc['fullName'] ?? 'N/A',
                'email': doc['email'] ?? 'N/A',
                'address': doc['address'] ?? 'N/A',
                'contactNumber': doc['contactNumber'] ?? 'N/A',
              }
            };

            List<Widget> rows = topAppointments.map((entry) {
              final patientId = entry.key;
              final count = entry.value;
              final details = patientDetails[patientId] ?? {'fullName': 'Patient ID: $patientId', 'email': 'N/A', 'address': 'N/A', 'contactNumber': 'N/A'};

              return _buildCustomTableRow(
                name: Text(details['fullName']!, style: const TextStyle(fontWeight: FontWeight.w500)),
                address: Text(details['address']!, overflow: TextOverflow.ellipsis),
                email: Text(details['email']!, overflow: TextOverflow.ellipsis),
                contact: Text(details['contactNumber']!),
                count: Text(count.toString(), style: const TextStyle(fontWeight: FontWeight.bold)),
              );
            }).toList();

            return Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              elevation: 4,
              child: Container(
                padding: const EdgeInsets.all(10),
                width: double.infinity,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.all(10.0),
                      child: Text(
                        "Top 5 Patients by Appointments",
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ),
                    // Table Header
                    _buildCustomTableRow(
                      isHeader: true,
                      name: const Text('Patient Name', style: TextStyle(fontWeight: FontWeight.bold)),
                      address: const Text('Address', style: TextStyle(fontWeight: FontWeight.bold)),
                      email: const Text('Email', style: TextStyle(fontWeight: FontWeight.bold)),
                      contact: const Text('Contact', style: TextStyle(fontWeight: FontWeight.bold)),
                      count: const Text('Total Appointments', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                    // Table Rows
                    ...rows,
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // Helper for empty appointments table (Redesigned with custom Expanded Row logic)
  Widget _buildEmptyAppointmentsTable() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      elevation: 4,
      child: Container(
        padding: const EdgeInsets.all(20),
        width: double.infinity,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Top 5 Patients by Appointments",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            // Table Header
            _buildCustomTableRow(
              isHeader: true,
              name: const Text('Patient Name', style: TextStyle(fontWeight: FontWeight.bold)),
              address: const Text('Address', style: TextStyle(fontWeight: FontWeight.bold)),
              email: const Text('Email', style: TextStyle(fontWeight: FontWeight.bold)),
              contact: const Text('Contact', style: TextStyle(fontWeight: FontWeight.bold)),
              count: const Text('Total Appointments', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
            // Empty Row
            _buildCustomTableRow(
              name: const Text("No appointments recorded"),
              address: const Text("N/A"),
              email: const Text("N/A"),
              contact: const Text("N/A"),
              count: const Text("0"),
            ),
          ],
        ),
      ),
    );
  }

  // ----------------------------------------------------------------------------------
  // --- MAIN BUILD METHOD (Web & Mobile Layout - No significant changes) ---
  // ----------------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    if (!_isWideScreen(context)) {
      // Mobile Layout (No change)
      return Scaffold(
        appBar: AppBar(
          title: Text(_titles[_currentIndex]),
          actions: [
            IconButton(icon: const Icon(Icons.logout), onPressed: _logout)
          ],
        ),
        body: _pages[_currentIndex],
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: _onTap,
          type: BottomNavigationBarType.fixed,
          selectedItemColor: Colors.green,
          unselectedItemColor: Colors.grey,
          items: [
            const BottomNavigationBarItem(
                icon: Icon(Icons.home), label: "Home"),
            const BottomNavigationBarItem(
                icon: Icon(Icons.people), label: "Patients"),
            const BottomNavigationBarItem(
                icon: Icon(Icons.event_note), label: "Appointments"),
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

    // Web Layout (No change)
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

                // --- 2. Nurse Profile Section ---
                FutureBuilder<DocumentSnapshot>(
                  future: _nurseProfileFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const ListTile(
                          title: Text("Loading Profile..."),
                          leading: CircularProgressIndicator.adaptive());
                    }
                    if (snapshot.hasError || !snapshot.hasData || !snapshot.data!.exists) {
                      return const ListTile(
                          title: Text("Profile Error"),
                          leading: Icon(Icons.person));
                    }

                    final data = snapshot.data!.data() as Map<String, dynamic>?;
                    final nurseName = data?['fullName'] ?? 'Nurse User';
                    final nurseEmail = data?['email'] ?? 'Unknown Email';

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
                            child: Icon(Icons.local_hospital_outlined, color: Colors.white),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  nurseName,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold, fontSize: 14),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  nurseEmail,
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
                const Divider(height: 1, color: Colors.black12),

                // --- 3. Navigation Items ---
                _WebNavItem(
                    icon: Icons.home_filled,
                    label: "Home",
                    index: 0,
                    currentIndex: _currentIndex,
                    onTap: _onTap),
                _WebNavItem(
                    icon: Icons.people,
                    label: "Patients",
                    index: 1,
                    currentIndex: _currentIndex,
                    onTap: _onTap),
                _WebNavItem(
                    icon: Icons.event_note,
                    label: "Appointments",
                    index: 2,
                    currentIndex: _currentIndex,
                    onTap: _onTap),
                _WebNavItem(
                    icon: Icons.notifications_none,
                    label: "Notifications",
                    index: 3,
                    currentIndex: _currentIndex,
                    onTap: _onTap,
                    badgeCount: _unreadNotifications),
                _WebNavItem(
                    icon: Icons.bar_chart,
                    label: "Reports",
                    index: 4,
                    currentIndex: _currentIndex,
                    onTap: _onTap),
                const Spacer(),
                const Divider(height: 1, color: Colors.black12),
                ListTile(
                  leading: const Icon(Icons.logout, color: Colors.black),
                  title: const Text("Logout",
                      style: TextStyle(color: Colors.black, fontWeight: FontWeight.w600)),
                  onTap: _logout,
                ),
              ],
            ),
          ),
          Expanded(
            child: Container(
              color: Colors.grey[100],
              padding: const EdgeInsets.fromLTRB(28, 28, 28, 0),
              child: _pages[_currentIndex],
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
          if (badgeCount > 0 && index == 3)
            Positioned(
              right: -4,
              top: -4,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                    color: Colors.red, shape: BoxShape.circle),
                constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                child: Text(
                  '$badgeCount',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
        ],
      ),
      title: Text(
        label,
        style: TextStyle(
          color: isSelected ? Colors.green : Colors.black87,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
        ),
      ),
      selected: isSelected,
      onTap: () => onTap(index),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      selectedTileColor: Colors.green.shade50,
    );
  }
}