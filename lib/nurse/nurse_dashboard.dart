// nurse_dashboard.dart
import 'dart:async';
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

// Charts & calendar
import 'package:fl_chart/fl_chart.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';

// -----------------------------------------------------------------
// Config
// -----------------------------------------------------------------
const int MAX_BED_CAPACITY = 4;
const int WEEK_DAYS = 7;
const List<String> DEFAULT_SLOTS = [
  "06:00 - 10:00",
  "10:00 - 14:00",
  "14:00 - 18:00",
  "18:00 - 22:00"
];

// -----------------------------------------------------------------
// NurseDashboard Widget
// -----------------------------------------------------------------
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

  // Dashboard state
  DateTime _selectedDay = DateTime.now();
  DateTime _focusedDay = DateTime.now();

  // summary counts (today)
  int _totalPatientsToday = 0;
  int _ongoingSessions = 0;
  int _completedSessions = 0;
  int _missedSessions = 0;
  int _availableBeds = 0;
  int _occupiedBeds = 0;

  // UI card sizing
  static const double _cardHeight = 320.0;

  late final List<Widget> _pages;
  late final List<String> _titles;

  Timer? _nowTimer;

  // caches
  final Map<String, String> _patientNameCache = {};

  @override
  void initState() {
    super.initState();
    _nurseId = widget.nurseId;
    _nurseProfileFuture = _fetchNurseProfile();
    _listenUnreadNotifications();

    // initial computations (do any non-context work here)
    _computeTodaySummary();

    // keep current time updated for header if used
    _nowTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  // Build context-dependent things in didChangeDependencies
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _titles = ["Home", "Patients", "Appointments", "Notifications", "Reports"];
    _pages = [
      _buildHomeTab(),
      NursePatientsPage(nurseId: _nurseId),
      NurseAppointmentsPage(nurseId: _nurseId),
      NurseNotificationPage(userId: _nurseId),
      ReportsPage(role: "nurse", userId: _nurseId),
    ];
  }

  @override
  void dispose() {
    _nowTimer?.cancel();
    super.dispose();
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

  bool _isWideScreen(BuildContext context) => MediaQuery.of(context).size.width >= 900;
  void _onTap(int idx) => setState(() => _currentIndex = idx);

  // ---------------------- Utilities / Cache ----------------------
  Future<String> _getPatientName(String uid) async {
    if (_patientNameCache.containsKey(uid)) return _patientNameCache[uid]!;
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      final name = (doc.data()?['fullName'] as String?) ?? 'Unknown';
      _patientNameCache[uid] = name;
      return name;
    } catch (_) {
      _patientNameCache[uid] = 'Unknown';
      return 'Unknown';
    }
  }

  DateTime _startOfDay(DateTime dt) => DateTime(dt.year, dt.month, dt.day);
  DateTime _endOfDay(DateTime dt) => DateTime(dt.year, dt.month, dt.day, 23, 59, 59);

  // ---------------------- SUMMARY COMPUTATION (TODAY) ----------------------
  Future<void> _computeTodaySummary() async {
    try {
      final start = Timestamp.fromDate(_startOfDay(DateTime.now()));
      final end = Timestamp.fromDate(_endOfDay(DateTime.now()));

      final apptSnap = await FirebaseFirestore.instance
          .collection('appointments')
          .where('date', isGreaterThanOrEqualTo: start)
          .where('date', isLessThanOrEqualTo: end)
          .get();

      int total = apptSnap.docs.length;
      int ongoing = 0;
      int completed = 0;
      int missed = 0;
      final Set<String> occupiedBedIds = {};
      for (var d in apptSnap.docs) {
        final data = d.data() as Map<String, dynamic>? ?? {};
        final status = (data['status'] ?? '').toString().toLowerCase();
        if (status == 'showed' || status == 'in_process' || status == 'approved') ongoing++;
        if (status == 'completed') completed++;
        if (status == 'missed') missed++;
        final bedId = (data['bedId'] as String?) ?? '';
        if (bedId.isNotEmpty) occupiedBedIds.add(bedId);
      }

      // beds
      final bedsSnap = await FirebaseFirestore.instance.collection('beds').where('isWorking', isEqualTo: true).get();
      int bedsTotal = bedsSnap.docs.length;
      int occupied = occupiedBedIds.length;
      int available = bedsTotal - occupied;
      if (available < 0) available = 0;

      if (mounted) {
        setState(() {
          _totalPatientsToday = total;
          _ongoingSessions = ongoing;
          _completedSessions = completed;
          _missedSessions = missed;
          _occupiedBeds = occupied;
          _availableBeds = available;
        });
      }
    } catch (e) {
      print("Error computing summary: $e");
    }
  }

  // ---------------------- WEEKLY TRENDS DATA ----------------------
  Future<Map<String, Map<String, int>>> _fetchWeeklyAppointmentAggregates() async {
    final Map<String, Map<String, int>> result = {};
    final now = DateTime.now();
    final days = List<DateTime>.generate(WEEK_DAYS, (i) => _startOfDay(now.subtract(Duration(days: WEEK_DAYS - 1 - i))));
    final start = Timestamp.fromDate(days.first);
    final end = Timestamp.fromDate(_endOfDay(days.last));

    final snap = await FirebaseFirestore.instance
        .collection('appointments')
        .where('date', isGreaterThanOrEqualTo: start)
        .where('date', isLessThanOrEqualTo: end)
        .get();

    for (var d in days) {
      final key = DateFormat('EEE').format(d); // Mon, Tue, ...
      result[key] = {'completed': 0, 'missed': 0, 'ongoing': 0};
    }

    for (var doc in snap.docs) {
      final data = doc.data() as Map<String, dynamic>? ?? {};
      final Timestamp? ts = data['date'] as Timestamp?;
      if (ts == null) continue;
      final dt = ts.toDate();
      final key = DateFormat('EEE').format(_startOfDay(dt));
      if (!result.containsKey(key)) continue;
      final status = (data['status'] ?? '').toString().toLowerCase();
      if (status == 'completed') result[key]!['completed'] = (result[key]!['completed'] ?? 0) + 1;
      else if (status == 'missed') result[key]!['missed'] = (result[key]!['missed'] ?? 0) + 1;
      else if (status == 'showed' || status == 'in_process' || status == 'approved') result[key]!['ongoing'] = (result[key]!['ongoing'] ?? 0) + 1;
    }

    return result;
  }

  Future<Map<String, double>> _fetchWeeklyAvgDuration() async {
    final Map<String, List<int>> durations = {};
    final now = DateTime.now();
    final days = List<DateTime>.generate(WEEK_DAYS, (i) => _startOfDay(now.subtract(Duration(days: WEEK_DAYS - 1 - i))));
    final start = Timestamp.fromDate(days.first);
    final end = Timestamp.fromDate(_endOfDay(days.last));

    final snap = await FirebaseFirestore.instance
        .collection('appointments')
        .where('date', isGreaterThanOrEqualTo: start)
        .where('date', isLessThanOrEqualTo: end)
        .get();

    for (var d in days) durations[DateFormat('EEE').format(d)] = [];

    for (var doc in snap.docs) {
      final data = doc.data() as Map<String, dynamic>? ?? {};
      final ts = data['date'] as Timestamp?;
      if (ts == null) continue;
      final key = DateFormat('EEE').format(_startOfDay(ts.toDate()));
      final int dur = (data['durationMinutes'] as int?) ?? 60;
      durations[key]?.add(dur);
    }

    final Map<String, double> avg = {};
    durations.forEach((k, list) {
      if (list.isEmpty) avg[k] = 0.0;
      else avg[k] = list.reduce((a, b) => a + b) / list.length;
    });
    return avg;
  }

  Future<Map<String, int>> _fetchBedOccupancyForDate(DateTime day) async {
    final start = Timestamp.fromDate(_startOfDay(day));
    final end = Timestamp.fromDate(_endOfDay(day));
    final apptSnap = await FirebaseFirestore.instance
        .collection('appointments')
        .where('date', isGreaterThanOrEqualTo: start)
        .where('date', isLessThanOrEqualTo: end)
        .get();

    final Set<String> occupied = {};
    for (var d in apptSnap.docs) {
      final bedId = (d.data()?['bedId'] as String?) ?? '';
      if (bedId.isNotEmpty) occupied.add(bedId);
    }
    final bedsSnap = await FirebaseFirestore.instance.collection('beds').where('isWorking', isEqualTo: true).get();
    final totalBeds = bedsSnap.docs.length;
    return {'occupied': occupied.length, 'available': (totalBeds - occupied.length).clamp(0, totalBeds)};
  }

  // ---------------------- BUILD HOME TAB (main) ----------------------
  Widget _buildHomeTab() {
    final isWideLayout = _isWideScreen(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.only(top: 0),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Header
          Row(children: [
            const Text("Nurse Dashboard", style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold)),
            const SizedBox(width: 12),
            Text(DateFormat('yyyy-MM-dd – HH:mm').format(DateTime.now()), style: const TextStyle(color: Colors.black54)),
            const Spacer(),
            ElevatedButton.icon(onPressed: () => setState((){}), icon: const Icon(Icons.refresh), label: const Text('Refresh'), style: ElevatedButton.styleFrom(backgroundColor: Colors.green)),
          ]),
          const SizedBox(height: 12),
          const Text("Overview: Realtime appointment & capacity metrics", style: TextStyle(color: Colors.black54)),
          const SizedBox(height: 18),

          // SUMMARY CARDS
          LayoutBuilder(builder: (context, constraints) {
            final isWide = constraints.maxWidth > 900;
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _summaryCard("Total Patients Today", _totalPatientsToday, Icons.people, Colors.blue, width: isWide ? 220 : double.infinity),
                _summaryCard("Ongoing Sessions", _ongoingSessions, Icons.play_circle_fill, Colors.orange, width: isWide ? 220 : double.infinity),
                _summaryCard("Completed Today", _completedSessions, Icons.check_circle, Colors.green, width: isWide ? 220 : double.infinity),
                _summaryCard("Missed Today", _missedSessions, Icons.warning, Colors.red, width: isWide ? 220 : double.infinity),
                _summaryCard("Available Beds", _availableBeds, Icons.bed, Colors.teal, width: isWide ? 220 : double.infinity),
                _summaryCard("Occupied Beds", _occupiedBeds, Icons.meeting_room, Colors.purple, width: isWide ? 220 : double.infinity),
              ],
            );
          }),

          const SizedBox(height: 18),

          // CHARTS + WHITEBOARD
          LayoutBuilder(builder: (context, constraints) {
            final wide = constraints.maxWidth > 1100;
            return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // charts row
              wide
                  ? Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 5, child: SizedBox(height: 340, child: _buildWeeklyBarChartCard())),
                  const SizedBox(width: 16),
                  Expanded(flex: 3, child: SizedBox(height: 340, child: _buildPieAndLineStack())),
                ],
              )
                  : Column(children: [
                SizedBox(height: 320, child: _buildWeeklyBarChartCard()),
                const SizedBox(height: 12),
                SizedBox(height: 320, child: _buildPieAndLineStack()),
              ]),

              const SizedBox(height: 18),

              // Top patients table (kept from original)
              _buildTopAppointmentsTable(),

              const SizedBox(height: 18),

              // WHITEBOARD SECTION
              Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 3,
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      const Text("Whiteboard — Bed Map", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(width: 8),
                      Text(DateFormat('yyyy-MM-dd').format(_selectedDay), style: const TextStyle(color: Colors.black54)),
                      const Spacer(),
                      IconButton(onPressed: () => setState(() { _computeTodaySummary(); }), icon: const Icon(Icons.refresh)),
                    ]),
                    const SizedBox(height: 8),
                    ConstrainedBox(
                      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.65),
                      child: _buildWhiteboardArea(),
                    ),
                  ]),
                ),
              ),
            ]);
          }),
        ]),
      ),
    );
  }

  // ---------------------- UI: summaryCard ----------------------
  Widget _summaryCard(String title, int value, IconData icon, Color color, {double width = 220}) {
    return Card(
      elevation: 2,
      child: Container(
        width: width,
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            CircleAvatar(backgroundColor: color.withOpacity(0.15), child: Icon(icon, color: color)),
            const SizedBox(width: 10),
            Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold))),
          ]),
          const SizedBox(height: 14),
          Text(value.toString(), style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: color)),
        ]),
      ),
    );
  }

  // ---------------------- WEEKLY BAR CHART CARD ----------------------
  Widget _buildWeeklyBarChartCard() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: FutureBuilder<Map<String, Map<String, int>>>(
          future: _fetchWeeklyAppointmentAggregates(),
          builder: (context, snap) {
            if (!snap.hasData) return const Center(child: CircularProgressIndicator());
            final data = snap.data!;
            final labels = data.keys.toList();
            final completed = labels.map((k) => data[k]!['completed'] ?? 0).toList();
            final missed = labels.map((k) => data[k]!['missed'] ?? 0).toList();
            final ongoing = labels.map((k) => data[k]!['ongoing'] ?? 0).toList();

            final maxY = [
              if (completed.isNotEmpty) completed.reduce((a, b) => a > b ? a : b),
              if (missed.isNotEmpty) missed.reduce((a, b) => a > b ? a : b),
              if (ongoing.isNotEmpty) ongoing.reduce((a, b) => a > b ? a : b)
            ].fold<int>(0, (p, e) => p > e ? p : e) + 1;

            return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text("Weekly Appointments Overview", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6.0),
                  child: BarChart(BarChartData(
                    alignment: BarChartAlignment.spaceAround,
                    maxY: maxY.toDouble() <= 0 ? 1 : maxY.toDouble(),
                    groupsSpace: 12,
                    barTouchData: BarTouchData(enabled: true),
                    titlesData: FlTitlesData(
                      leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true)),
                      bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, getTitlesWidget: (v, meta) {
                        final idx = v.toInt();
                        if (idx < 0 || idx >= labels.length) return const SizedBox.shrink();
                        return SideTitleWidget(
                          meta: meta, // ✅ new API uses TitleMeta
                          child: Text(
                            labels[idx],
                            style: const TextStyle(fontSize: 10),
                          ),
                        );
                      })),
                    ),
                    barGroups: List.generate(labels.length, (i) {
                      return BarChartGroupData(
                        x: i,
                        barsSpace: 4,
                        barRods: [
                          BarChartRodData(toY: completed[i].toDouble(), color: Colors.green, width: 8),
                          BarChartRodData(toY: missed[i].toDouble(), color: Colors.redAccent, width: 8),
                          BarChartRodData(toY: ongoing[i].toDouble(), color: Colors.blue, width: 8),
                        ],
                      );
                    }),
                  )),
                ),
              ),
              const SizedBox(height: 6),
              Row(children: [
                _legendDot('Completed', Colors.green),
                const SizedBox(width: 8),
                _legendDot('Missed', Colors.redAccent),
                const SizedBox(width: 8),
                _legendDot('Ongoing', Colors.blue),
              ])
            ]);
          },
        ),
      ),
    );
  }

  Widget _legendDot(String label, Color color) {
    return Row(children: [Container(width: 10, height: 10, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))), const SizedBox(width: 6), Text(label)]);
  }

  // ---------------------- PIE + LINE STACK ----------------------
  Widget _buildPieAndLineStack() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(children: [
          const Text("Occupancy & Duration", style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Expanded(
            child: FutureBuilder<Map<String, int>>(
              future: _fetchBedOccupancyForDate(_selectedDay),
              builder: (context, assignmentSnap) {
                if (!assignmentSnap.hasData) return const Center(child: CircularProgressIndicator());
                final occ = assignmentSnap.data!;
                final occCount = occ['occupied'] ?? 0;
                final availCount = occ['available'] ?? 0;
                final total = (occCount + availCount) <= 0 ? 1 : (occCount + availCount);

                return Column(children: [
                  Expanded(
                    child: Row(children: [
                      Expanded(
                        child: PieChart(PieChartData(
                          sections: [
                            PieChartSectionData(value: occCount.toDouble(), title: '$occCount', color: Colors.redAccent, radius: 50, titleStyle: const TextStyle(color: Colors.white)),
                            PieChartSectionData(value: availCount.toDouble(), title: '$availCount', color: Colors.green, radius: 50, titleStyle: const TextStyle(color: Colors.white)),
                          ],
                          sectionsSpace: 2,
                          centerSpaceRadius: 24,
                        )),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: FutureBuilder<Map<String, double>>(future: _fetchWeeklyAvgDuration(), builder: (context, durSnap) {
                          if (!durSnap.hasData) return const Center(child: CircularProgressIndicator());
                          final map = durSnap.data!;
                          final labels = map.keys.toList();
                          final values = map.values.toList();
                          final spots = List.generate(values.length, (i) => FlSpot(i.toDouble(), values[i]));
                          final maxY = (values.isEmpty ? 60.0 : (values.reduce((a, b) => a > b ? a : b) + 10.0));
                          return LineChart(LineChartData(
                            minX: 0,
                            maxX: (labels.length - 1).toDouble(),
                            minY: 0,
                            maxY: maxY,
                            titlesData: FlTitlesData(
                              bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, getTitlesWidget: (v, meta) {
                                final idx = v.toInt();
                                if (idx < 0 || idx >= labels.length) return const SizedBox.shrink();
                                return SideTitleWidget(
                                  meta: meta, // ✅ new API uses TitleMeta instead of axisSide
                                  child: Text(
                                    labels[idx],
                                    style: const TextStyle(fontSize: 10),
                                  ),
                                );
                              })),
                            ),
                            lineBarsData: [LineChartBarData(spots: spots, isCurved: true, color: Colors.blue, barWidth: 3, dotData: FlDotData(show: true))],
                          ));
                        }),
                      ),
                    ]),
                  ),
                  const SizedBox(height: 6),
                  Row(children: [ _legendDot('Occupied', Colors.redAccent), const SizedBox(width: 8), _legendDot('Available', Colors.green) ])
                ]);
              },
            ),
          ),
        ]),
      ),
    );
  }

  // ---------------------- Whiteboard area (embedded) ----------------------
  Widget _buildWhiteboardArea() {
    final isWide = _isWideScreen(context);

    // stream beds
    final bedsStream = FirebaseFirestore.instance.collection('beds').where('isWorking', isEqualTo: true).orderBy('name').snapshots();

    // stream appointments for selectedDay
    final start = Timestamp.fromDate(_startOfDay(_selectedDay));
    final end = Timestamp.fromDate(_endOfDay(_selectedDay));
    final appointmentsStream = FirebaseFirestore.instance
        .collection('appointments')
        .where('date', isGreaterThanOrEqualTo: start)
        .where('date', isLessThanOrEqualTo: end)
        .where('status', whereIn: ['approved','showed','in_process','rescheduled'])
        .snapshots();

    return StreamBuilder<QuerySnapshot>(
      stream: bedsStream,
      builder: (context, bedSnap) {
        if (bedSnap.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        final bedDocs = bedSnap.data?.docs ?? [];
        return StreamBuilder<QuerySnapshot>(
          stream: appointmentsStream,
          builder: (context, apptSnap) {
            if (apptSnap.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
            final apptDocs = apptSnap.data?.docs ?? [];

            // map bedId -> assigned appointments
            final Map<String, List<QueryDocumentSnapshot>> perBed = {};
            final List<QueryDocumentSnapshot> unassigned = [];

            for (var d in apptDocs) {
              final data = d.data() as Map<String, dynamic>? ?? {};
              final bedId = (data['bedId'] as String?) ?? '';
              if (bedId.isEmpty) unassigned.add(d);
              else perBed.putIfAbsent(bedId, () => []).add(d);
            }

            if (isWide) {
              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  ...bedDocs.map((bedDoc) {
                    final bedId = bedDoc.id;
                    final bedData = bedDoc.data() as Map<String, dynamic>? ?? {};
                    final bedName = bedData['name'] ?? 'Bed $bedId';
                    final assigned = perBed[bedId] ?? [];
                    final count = assigned.length;
                    final color = (count == 0) ? Colors.green : ((count < MAX_BED_CAPACITY) ? Colors.blue : Colors.red);

                    return Container(
                      width: 300,
                      margin: const EdgeInsets.all(8),
                      child: Card(
                        elevation: 3,
                        child: Padding(
                          padding: const EdgeInsets.all(10),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Row(children: [Text(bedName, style: const TextStyle(fontWeight: FontWeight.bold)), const Spacer(), Text('$count / $MAX_BED_CAPACITY', style: const TextStyle(fontWeight: FontWeight.w600))]),
                            const Divider(),
                            Expanded(
                              child: assigned.isEmpty
                                  ? Center(child: Text('No assignments', style: TextStyle(color: Colors.grey[600])))
                                  : ListView(children: assigned.map((d) {
                                final data = d.data() as Map<String, dynamic>? ?? {};
                                final patientId = data['patientId'] ?? '';
                                final slot = data['slot'] ?? '';
                                return ListTile(
                                  dense: true,
                                  visualDensity: const VisualDensity(vertical: -3),
                                  title: FutureBuilder<String>(future: _getPatientName(patientId), builder: (context, snap) => Text(snap.data ?? 'Patient')),
                                  subtitle: Text(slot.toString()),
                                  trailing: Container(width: 12, height: 12, decoration: BoxDecoration(color: color.withOpacity(0.9), borderRadius: BorderRadius.circular(6))),
                                );
                              }).toList()),
                            ),
                          ]),
                        ),
                      ),
                    );
                  }).toList(),

                  // unassigned column
                  Container(
                    width: 300,
                    margin: const EdgeInsets.all(8),
                    child: Card(
                      elevation: 3,
                      child: Padding(
                        padding: const EdgeInsets.all(10),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Row(children: const [Text('Unassigned', style: TextStyle(fontWeight: FontWeight.bold)), Spacer()]),
                          const Divider(),
                          Expanded(child: unassigned.isEmpty ? Center(child: Text('No unassigned')) : ListView(children: unassigned.map((d) {
                            final data = d.data() as Map<String, dynamic>? ?? {};
                            final pid = data['patientId'] ?? '';
                            final slot = data['slot'] ?? '';
                            return ListTile(dense: true, title: FutureBuilder<String>(future: _getPatientName(pid), builder: (context, snap) => Text(snap.data ?? 'Patient')), subtitle: Text(slot.toString()));
                          }).toList()))
                        ]),
                      ),
                    ),
                  ),
                ]),
              );
            } else {
              return ListView(padding: const EdgeInsets.all(8), children: [
                ...bedDocs.map((bedDoc) {
                  final bedId = bedDoc.id;
                  final bedData = bedDoc.data() as Map<String, dynamic>? ?? {};
                  final bedName = bedData['name'] ?? 'Bed $bedId';
                  final assigned = perBed[bedId] ?? [];
                  final count = assigned.length;

                  return Card(
                    elevation: 2,
                    margin: const EdgeInsets.only(bottom: 10),
                    child: ExpansionTile(
                      title: Row(children: [Text(bedName, style: const TextStyle(fontWeight: FontWeight.bold)), const Spacer(), Text('$count / $MAX_BED_CAPACITY')]),
                      children: assigned.isEmpty ? [Padding(padding: const EdgeInsets.all(12), child: Text('No assignments', style: TextStyle(color: Colors.grey[600])))] : assigned.map((d) {
                        final data = d.data() as Map<String, dynamic>? ?? {};
                        final pid = data['patientId'] ?? '';
                        final slot = data['slot'] ?? '';
                        return ListTile(dense: true, title: FutureBuilder<String>(future: _getPatientName(pid), builder: (context, snap) => Text(snap.data ?? 'Patient')), subtitle: Text(slot.toString()));
                      }).toList(),
                    ),
                  );
                }).toList(),
                if (unassigned.isNotEmpty)
                  Card(
                    elevation: 2,
                    child: ExpansionTile(title: const Text('Unassigned'), children: unassigned.map((d) {
                      final data = d.data() as Map<String, dynamic>? ?? {};
                      final pid = data['patientId'] ?? '';
                      final slot = data['slot'] ?? '';
                      return ListTile(dense: true, title: FutureBuilder<String>(future: _getPatientName(pid), builder: (context, snap) => Text(snap.data ?? 'Patient')), subtitle: Text(slot.toString()));
                    }).toList()),
                  )
              ]);
            }
          },
        );
      },
    );
  }

  // ---------------------- Top Appointments Table (kept from original, compact) ----------------------
  Widget _buildTopAppointmentsTable() {
    return FutureBuilder<QuerySnapshot>(
      future: FirebaseFirestore.instance.collection('appointments').get(),
      builder: (context, appointmentSnapshot) {
        if (appointmentSnapshot.connectionState == ConnectionState.waiting) {
          return Card(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 2, child: const SizedBox(height: 200, child: Center(child: CircularProgressIndicator())));
        }
        if (appointmentSnapshot.hasError || !appointmentSnapshot.hasData) {
          return const Center(child: Text("Error loading appointments."));
        }

        Map<String, int> patientAppointmentCounts = {};
        for (var doc in appointmentSnapshot.data!.docs) {
          final patientId = doc['patientId'] as String;
          patientAppointmentCounts.update(patientId, (value) => value + 1, ifAbsent: () => 1);
        }

        final sortedPatients = patientAppointmentCounts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
        final topAppointments = sortedPatients.take(5).toList();
        final requiredUserIds = topAppointments.map((e) => e.key).toList();
        if (requiredUserIds.isEmpty) {
          return _buildEmptyAppointmentsTable();
        }

        return FutureBuilder<QuerySnapshot>(
          future: FirebaseFirestore.instance.collection('users').where(FieldPath.documentId, whereIn: requiredUserIds).get(),
          builder: (context, userSnapshot) {
            if (userSnapshot.connectionState == ConnectionState.waiting) {
              return Card(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 2, child: const SizedBox(height: 200, child: Center(child: CircularProgressIndicator())));
            }
            if (userSnapshot.hasError || !userSnapshot.hasData) return const Center(child: Text("Error loading patient names."));

            final patientDetails = { for (var doc in userSnapshot.data!.docs) doc.id: { 'fullName': doc['fullName'] ?? 'N/A', 'email': doc['email'] ?? 'N/A', 'address': doc['address'] ?? 'N/A', 'contactNumber': doc['contactNumber'] ?? 'N/A' } };

            List<Widget> rows = topAppointments.map((entry) {
              final patientId = entry.key;
              final count = entry.value;
              final details = patientDetails[patientId] ?? {'fullName': 'Patient ID: $patientId', 'email': 'N/A', 'address': 'N/A', 'contactNumber': 'N/A'};
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.grey.shade200))),
                child: Row(children: [
                  Expanded(flex: 3, child: Text(details['fullName']!, style: const TextStyle(fontWeight: FontWeight.w500))),
                  Expanded(flex: 3, child: Text(details['address']!, overflow: TextOverflow.ellipsis)),
                  Expanded(flex: 2, child: Text(details['email']!, overflow: TextOverflow.ellipsis)),
                  Expanded(flex: 2, child: Text(details['contactNumber']!)),
                  Expanded(flex: 1, child: Align(alignment: Alignment.centerRight, child: Text(count.toString(), style: const TextStyle(fontWeight: FontWeight.bold)))),
                ]),
              );
            }).toList();

            return Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 3,
              child: Container(
                padding: const EdgeInsets.all(10),
                width: double.infinity,
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Padding(padding: EdgeInsets.all(8.0), child: Text("Top 5 Patients by Appointments (This Week)", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
                  // header
                  Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8), color: Colors.green.shade50, child: Row(children: const [
                    Expanded(flex: 3, child: Text('Patient Name', style: TextStyle(fontWeight: FontWeight.bold))),
                    Expanded(flex: 3, child: Text('Address', style: TextStyle(fontWeight: FontWeight.bold))),
                    Expanded(flex: 2, child: Text('Email', style: TextStyle(fontWeight: FontWeight.bold))),
                    Expanded(flex: 2, child: Text('Contact', style: TextStyle(fontWeight: FontWeight.bold))),
                    Expanded(flex: 1, child: Align(alignment: Alignment.centerRight, child: Text('Total', style: TextStyle(fontWeight: FontWeight.bold)))),
                  ])),
                  ...rows,
                ]),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildEmptyAppointmentsTable() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: Container(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text("Top 5 Patients by Appointments", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8), color: Colors.green.shade50, child: Row(children: const [
            Expanded(flex: 3, child: Text('Patient Name', style: TextStyle(fontWeight: FontWeight.bold))),
            Expanded(flex: 3, child: Text('Address', style: TextStyle(fontWeight: FontWeight.bold))),
            Expanded(flex: 2, child: Text('Email', style: TextStyle(fontWeight: FontWeight.bold))),
            Expanded(flex: 2, child: Text('Contact', style: TextStyle(fontWeight: FontWeight.bold))),
            Expanded(flex: 1, child: Align(alignment: Alignment.centerRight, child: Text('Total', style: TextStyle(fontWeight: FontWeight.bold)))),
          ])),
          Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12), child: const Text("No appointments recorded this week.")),
        ]),
      ),
    );
  }

  // ---------------------- BUILD (Scaffold) ----------------------
  @override
  Widget build(BuildContext context) {
    if (!_isWideScreen(context)) {
      // Mobile layout
      return Scaffold(
        appBar: AppBar(
          title: Text(_titles[_currentIndex]),
          actions: [IconButton(icon: const Icon(Icons.logout), onPressed: _logout)],
        ),
        body: _pages[_currentIndex],
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: _onTap,
          type: BottomNavigationBarType.fixed,
          selectedItemColor: Colors.green,
          unselectedItemColor: Colors.grey,
          items: [
            const BottomNavigationBarItem(icon: Icon(Icons.home), label: "Home"),
            const BottomNavigationBarItem(icon: Icon(Icons.people), label: "Patients"),
            const BottomNavigationBarItem(icon: Icon(Icons.event_note), label: "Appointments"),
            BottomNavigationBarItem(
              icon: Stack(clipBehavior: Clip.none, children: [
                const Icon(Icons.notifications),
                if (_unreadNotifications > 0)
                  Positioned(right: -4, top: -4, child: Container(padding: const EdgeInsets.all(4), decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle), constraints: const BoxConstraints(minWidth: 18, minHeight: 18), child: Text("$_unreadNotifications", style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold), textAlign: TextAlign.center))),
              ]),
              label: "Notifications",
            ),
            const BottomNavigationBarItem(icon: Icon(Icons.bar_chart), label: "Reports"),
          ],
        ),
      );
    }

    // Web layout
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: Row(children: [
        Container(
          width: 240,
          color: Colors.white,
          child: Column(children: [
            Container(padding: const EdgeInsets.only(top: 20, bottom: 10, left: 10, right: 10), child: Column(children: [
              Image.asset(kIsWeb ? 'logo/TCDC-LOGO.png' : 'assets/logo/TCDC-LOGO.png', height: 100, errorBuilder: (context, error, stackTrace) => const Padding(padding: EdgeInsets.all(8.0), child: Icon(Icons.broken_image, size: 50, color: Colors.red))),
              const SizedBox(height: 4),
              const Text("TOTAL CARE DIALYSIS CENTER", textAlign: TextAlign.center, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.green)),
              const Text("TAGOLOAN BRANCH", textAlign: TextAlign.center, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: Colors.black54)),
            ])),
            const Divider(height: 1, color: Colors.black12),
            FutureBuilder<DocumentSnapshot>(future: _nurseProfileFuture, builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) return const ListTile(title: Text("Loading Profile..."), leading: CircularProgressIndicator.adaptive());
              if (snapshot.hasError || !snapshot.hasData || !snapshot.data!.exists) return const ListTile(title: Text("Profile Error"), leading: Icon(Icons.person));
              final data = snapshot.data!.data() as Map<String, dynamic>?;
              final nurseName = data?['fullName'] ?? 'Nurse User';
              final nurseEmail = data?['email'] ?? 'Unknown Email';
              return Container(
                padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 10),
                margin: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(10)),
                child: Row(children: [const CircleAvatar(backgroundColor: Colors.green, child: Icon(Icons.local_hospital_outlined, color: Colors.white)), const SizedBox(width: 10), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(nurseName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14), overflow: TextOverflow.ellipsis), Text(nurseEmail, style: const TextStyle(fontSize: 10, color: Colors.black54), overflow: TextOverflow.ellipsis),]),),]),
              );
            }),
            const Divider(height: 1, color: Colors.black12),
            _WebNavItem(icon: Icons.home_filled, label: "Home", index: 0, currentIndex: _currentIndex, onTap: _onTap),
            _WebNavItem(icon: Icons.people, label: "Patients", index: 1, currentIndex: _currentIndex, onTap: _onTap),
            _WebNavItem(icon: Icons.event_note, label: "Appointments", index: 2, currentIndex: _currentIndex, onTap: _onTap),
            _WebNavItem(icon: Icons.notifications_none, label: "Notifications", index: 3, currentIndex: _currentIndex, onTap: _onTap, badgeCount: _unreadNotifications),
            _WebNavItem(icon: Icons.bar_chart, label: "Reports", index: 4, currentIndex: _currentIndex, onTap: _onTap),
            const Spacer(),
            const Divider(height: 1, color: Colors.black12),
            ListTile(leading: const Icon(Icons.logout, color: Colors.black), title: const Text("Logout", style: TextStyle(color: Colors.black, fontWeight: FontWeight.w600)), onTap: _logout),
          ]),
        ),
        Expanded(child: Container(color: Colors.grey[100], padding: const EdgeInsets.fromLTRB(28, 28, 28, 0), child: _pages[_currentIndex])),
      ]),
    );
  }
}

// Web nav item helper
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
      leading: Stack(clipBehavior: Clip.none, children: [
        Icon(icon, color: isSelected ? Colors.green : Colors.black54),
        if (badgeCount > 0 && index == 3)
          Positioned(right: -4, top: -4, child: Container(padding: const EdgeInsets.all(4), decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle), constraints: const BoxConstraints(minWidth: 18, minHeight: 18), child: Text('$badgeCount', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold), textAlign: TextAlign.center))),
      ]),
      title: Text(label, style: TextStyle(color: isSelected ? Colors.green : Colors.black87, fontWeight: isSelected ? FontWeight.bold : FontWeight.w500)),
      selected: isSelected,
      onTap: () => onTap(index),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      selectedTileColor: Colors.green.shade50,
    );
  }
}
