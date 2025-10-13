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

    // The rest of the pages are safe, as they're not wrapped in SingleChildScrollView
    // when loaded as the main content of the Scaffold body (in mobile)
    // or the Expanded pane (in web).
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

  // --- Data Fetching Methods ---

  Future<void> _fetchPatientScheduleSummary() async {
    final allPatientsSnapshot = await FirebaseFirestore.instance
        .collection('users')
        .where('role', isEqualTo: 'patient')
        .get();

    // Fetch appointments that are in the future or on the current day
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

  // FIX 1: Lower the wide-screen breakpoint from 900 to 650.
  bool _isWideScreen(BuildContext context) =>
      MediaQuery.of(context).size.width >= 650;

  void _onTap(int idx) => setState(() => _currentIndex = idx);

  // ----------------------------------------------------------------------------------
  // --- REFINED: HOME TAB WITH NEW LAYOUT STRUCTURE (KEEPING LOGIC INTACT) ---
  // ----------------------------------------------------------------------------------
  Widget _buildHomeTab() {
    // NOTE: this home tab intentionally does NOT include the full-width calendar.
    // On wide screens the calendar will be shown as a mini-calendar on the right side.
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
            const SizedBox(height: 20),

            // Summary & Capacity row (responsive handled in LayoutBuilder)
            LayoutBuilder(builder: (context, constraints) {
              bool isWide = constraints.maxWidth > 600;
              return isWide
                  ? Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 6, child: _buildScheduleSummaryCard()),
                  const SizedBox(width: 16),
                  Expanded(flex: 4, child: _buildDailyCapacityCard(context)),
                ],
              )
                  : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildScheduleSummaryCard(),
                  const SizedBox(height: 16),
                  _buildDailyCapacityCard(context),
                ],
              );
            }),

            const SizedBox(height: 20),

            // Top appointments table - full width under the above cards
            _buildTopAppointmentsTable(),
          ],
        ),
      ),
    );
  }

  /// --- DATA VISUALIZATION WIDGETS ---

  // Patient Schedule Summary Card
  Widget _buildScheduleSummaryCard() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      elevation: 3,
      child: Container(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Patient Schedule Summary",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
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
          ],
        ),
      ),
    );
  }

  // Helper for Schedule Summary Rows
  Widget _summaryRow(String title, int count, Color color, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 10),
              Text(
                title,
                style: const TextStyle(fontSize: 15),
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

  // Daily Capacity Card (Circular Chart)
  Widget _buildDailyCapacityCard(BuildContext context) {
    // Max capacity: Assuming 16 beds * 4 sessions/bed = 64 patients max daily capacity
    const int maxDailyCapacity = 64;

    return FutureBuilder<int>(
      future: _fetchDailyAppointmentCount(_selectedDay),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            elevation: 3,
            child: Container(
              padding: const EdgeInsets.all(18),
              height: 240,
              child: const Center(child: CircularProgressIndicator()),
            ),
          );
        }

        int scheduledCount = snapshot.data ?? 0;
        int remainingCapacity = maxDailyCapacity - scheduledCount;
        double scheduledPercentage = maxDailyCapacity > 0 ? (scheduledCount / maxDailyCapacity) * 100 : 0;

        if (remainingCapacity < 0) remainingCapacity = 0;

        int chartScheduledCount = scheduledCount > maxDailyCapacity ? maxDailyCapacity : scheduledCount;

        return Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          elevation: 3,
          child: Container(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Daily Capacity - ${DateFormat('MMM d, yyyy').format(_selectedDay)}",
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 14),
                Center(
                  child: SizedBox(
                    height: 160,
                    child: PieChart(
                      PieChartData(
                        sectionsSpace: 2,
                        centerSpaceRadius: 36,
                        sections: [
                          // Scheduled Section
                          PieChartSectionData(
                            color: Colors.lightGreen,
                            value: chartScheduledCount.toDouble(),
                            title: scheduledCount > 0 ? '${scheduledPercentage.toStringAsFixed(1)}%' : '',
                            radius: 56,
                            titleStyle: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          // Remaining Section
                          PieChartSectionData(
                            color: Colors.grey.shade300,
                            value: remainingCapacity.toDouble(),
                            title: '',
                            radius: 46,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Center(
                  child: Text(
                    "Scheduled: $scheduledCount / $maxDailyCapacity Patients",
                    style: TextStyle(
                        fontSize: 15,
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

  // Keep the full calendar card for mobile and optionally for dialogs.
  // On wide screens we will use a compact mini-calendar shown in the right column.
  // Full calendar card (Main)
  Widget _buildCalendarCard() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(8.0),
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
      ),
    );
  }

  // Mini Calendar (right panel, flexible)
  Widget _buildMiniCalendarCard() {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 3,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                const Text("Calendar", style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: constraints.maxHeight.isFinite ? constraints.maxHeight - 40 : 350,
                    minHeight: 280,
                  ),
                  child: SingleChildScrollView(
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
                      daysOfWeekStyle: const DaysOfWeekStyle(
                        weekdayStyle: TextStyle(fontSize: 12),
                        weekendStyle: TextStyle(fontSize: 12),
                      ),
                      calendarStyle: const CalendarStyle(
                        outsideDaysVisible: false,
                        defaultTextStyle: TextStyle(fontSize: 12),
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
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

// Top Appointments Table (Bottom)
  Widget _buildTopAppointmentsTable() {
    return LayoutBuilder(
      builder: (context, constraints) {
        return ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: 250,
            maxHeight: constraints.maxHeight.isFinite ? constraints.maxHeight : 400,
          ),
          child: FutureBuilder<QuerySnapshot>(
            future: FirebaseFirestore.instance.collection('appointments').get(),
            builder: (context, appointmentSnapshot) {
              if (appointmentSnapshot.connectionState == ConnectionState.waiting) {
                return _buildLoadingCard();
              }
              if (appointmentSnapshot.hasError || !appointmentSnapshot.hasData) {
                return const Center(child: Text("Error loading appointments."));
              }

              // 1. Count Appointments per Patient
              Map<String, int> patientAppointmentCounts = {};
              for (var doc in appointmentSnapshot.data!.docs) {
                final patientId = doc['patientId'] as String;
                patientAppointmentCounts.update(patientId, (value) => value + 1, ifAbsent: () => 1);
              }

              // 2. Sort and Get Top 5 (or less)
              final sortedPatients = patientAppointmentCounts.entries.toList()
                ..sort((a, b) => b.value.compareTo(a.value));
              final topAppointments = sortedPatients.take(5).toList();
              final requiredUserIds = topAppointments.map((e) => e.key).toList();

              if (requiredUserIds.isEmpty) return _buildEmptyAppointmentsTable();

              // 3. Fetch Patient Details (Name, Email, Contact, Address)
              return FutureBuilder<QuerySnapshot>(
                future: FirebaseFirestore.instance
                    .collection('users')
                    .where(FieldPath.documentId, whereIn: requiredUserIds)
                    .get(),
                builder: (context, userSnapshot) {
                  if (userSnapshot.connectionState == ConnectionState.waiting) {
                    return _buildLoadingCard();
                  }
                  if (userSnapshot.hasError || !userSnapshot.hasData) {
                    return const Center(child: Text("Error loading patient details."));
                  }

                  final patientDetails = {
                    for (var doc in userSnapshot.data!.docs)
                      doc.id: {
                        'fullName': doc['fullName'] ?? 'N/A',
                        'email': doc['email'] ?? 'N/A',
                        'contactNumber': doc['contactNumber'] ?? 'N/A',
                        'address': doc['address'] ?? 'N/A',
                      }
                  };

                  List<DataRow> rows = topAppointments.map((entry) {
                    final patientId = entry.key;
                    final count = entry.value;
                    final details = patientDetails[patientId] ?? {
                      'fullName': 'Patient ID: $patientId',
                      'email': 'N/A',
                      'contactNumber': 'N/A',
                      'address': 'N/A'
                    };

                    return DataRow(cells: [
                      DataCell(Text(details['fullName']!, style: const TextStyle(fontWeight: FontWeight.w500))),
                      DataCell(Text(details['email']!)),
                      DataCell(Text(details['contactNumber']!)),
                      DataCell(Text(details['address']!)),
                      DataCell(Text(count.toString())),
                    ]);
                  }).toList();

                  return Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                    elevation: 3,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      width: double.infinity,
                      height: double.infinity,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 10),
                            child: Text(
                              "Top 5 Patients by Appointments",
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                          ),
                          Expanded(
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: SingleChildScrollView(
                                child: DataTable(
                                  columnSpacing: 15,
                                  headingRowColor: MaterialStatePropertyAll(Colors.greenAccent.shade100),
                                  columns: const [
                                    DataColumn(label: Text('Patient Name', style: TextStyle(fontWeight: FontWeight.bold))),
                                    DataColumn(label: Text('Email', style: TextStyle(fontWeight: FontWeight.bold))),
                                    DataColumn(label: Text('Contact No.', style: TextStyle(fontWeight: FontWeight.bold))),
                                    DataColumn(label: Text('Address', style: TextStyle(fontWeight: FontWeight.bold))),
                                    DataColumn(
                                        label: Text('Total Appts', style: TextStyle(fontWeight: FontWeight.bold)),
                                        numeric: true),
                                  ],
                                  rows: rows,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildEmptyAppointmentsTable() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      elevation: 3,
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
            Center(
              child: DataTable(
                columnSpacing: 15,
                columns: const [
                  DataColumn(label: Text('Patient Name', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Email', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Contact No.', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Address', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Total Appts', style: TextStyle(fontWeight: FontWeight.bold)), numeric: true),
                ],
                rows: const [
                  DataRow(cells: [
                    DataCell(Text("No appointments recorded")),
                    DataCell(Text("N/A")),
                    DataCell(Text("N/A")),
                    DataCell(Text("N/A")),
                    DataCell(Text("0")),
                  ]),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingCard() {
    return const Card(
      elevation: 4,
      child: SizedBox(height: 250, child: Center(child: CircularProgressIndicator())),
    );
  }



  // ----------------------------------------------------------------------------------
  // --- MAIN BUILD METHOD (Web & Mobile Layout) ---
  // ----------------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    if (!_isWideScreen(context)) {
      // Mobile Layout (renders for phones)
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

    // Web Layout (Professional Admin Panel Look)
    // NOTE: main Row now contains: LEFT SIDEBAR, MAIN CONTENT, RIGHT MINI CALENDAR
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: Row(
        children: [
          // LEFT NAV SIDEBAR
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
                        height: 90,
                        errorBuilder: (context, error, stackTrace) {
                          return const Padding(
                            padding: EdgeInsets.all(8.0),
                            child: Icon(Icons.broken_image, size: 48, color: Colors.red),
                          );
                        },
                      ),
                      const SizedBox(height: 6),
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

                // --- Nurse Profile Section ---
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

                // --- Navigation Items ---
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

          // MAIN CONTENT (center)
          Expanded(
            flex: 3,
            child: Container(
              color: Colors.grey[100],
              padding: const EdgeInsets.fromLTRB(28, 28, 18, 0),
              child: _pages[_currentIndex],
            ),
          ),

          // RIGHT MINI CALENDAR (compact, only on wide screens)
          Container(
            width: 320,
            padding: const EdgeInsets.fromLTRB(12, 28, 24, 0),
            color: Colors.grey[100],
            child: Column(
              children: [
                // Place the mini calendar only on Home tab, otherwise show a small summary / shortcuts
                if (_currentIndex == 0) ...[
                  _buildMiniCalendarCard(),
                  const SizedBox(height: 16),
                  // Quick summary card under calendar
                  Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 3,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        children: [
                          Row(
                            children: const [
                              Icon(Icons.event_available, color: Colors.green),
                              SizedBox(width: 8),
                              Text("Today's Appointments", style: TextStyle(fontWeight: FontWeight.w600)),
                            ],
                          ),
                          const SizedBox(height: 8),
                          FutureBuilder<int>(
                            future: _fetchDailyAppointmentCount(DateTime.now()),
                            builder: (context, snap) {
                              if (snap.connectionState == ConnectionState.waiting) {
                                return const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 12),
                                  child: Center(child: CircularProgressIndicator()),
                                );
                              }
                              final count = snap.data ?? 0;
                              return Column(
                                children: [
                                  Text("$count", style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 6),
                                  const Text("Scheduled Today", style: TextStyle(color: Colors.black54)),
                                ],
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ] else ...[
                  // For other tabs we show compact navigation or notifications preview
                  Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 3,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        children: [
                          Row(
                            children: const [
                              Icon(Icons.info_outline, color: Colors.green),
                              SizedBox(width: 8),
                              Text("Quick Actions", style: TextStyle(fontWeight: FontWeight.w600)),
                            ],
                          ),
                          const SizedBox(height: 8),
                          ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.people, size: 20),
                            title: const Text("View Patients"),
                            onTap: () => setState(() => _currentIndex = 1),
                          ),
                          ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.event_note, size: 20),
                            title: const Text("View Appointments"),
                            onTap: () => setState(() => _currentIndex = 2),
                          ),
                        ],
                      ),
                    ),
                  ),
                ]
              ],
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
