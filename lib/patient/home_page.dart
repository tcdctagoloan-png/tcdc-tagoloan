// --------------------------------------------------------------------------
// 🏠 HOME PAGE (FIXED FOR BEDNAME ERROR & CLEANED UP)
// --------------------------------------------------------------------------
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:intl/intl.dart';

// Your notification setup
final FlutterLocalNotificationsPlugin _notificationsPlugin =
FlutterLocalNotificationsPlugin();

class HomePage extends StatefulWidget {
  final String userId;
  final String fullName;
  final Function(int)? onNavigate;

  // IMPORTANT: Removed the now-unused 'buildManualContent' parameter
  // as the parent (PatientDashboard) now handles the floating button.
  const HomePage({
    super.key,
    required this.userId,
    required this.fullName,
    this.onNavigate, required SizedBox Function() buildManualContent,
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  Timer? _timer;
  Duration? _timeLeft;
  DateTime? _appointmentDate;

  // --- Notification and Countdown Methods ---
  @override
  void initState() {
    super.initState();
    _initializeNotifications();
  }
  Future<void> _initializeNotifications() async {
    const AndroidInitializationSettings androidInit =
    AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initSettings =
    InitializationSettings(android: androidInit);
    await _notificationsPlugin.initialize(initSettings);
  }
  Future<void> _scheduleNotification(DateTime appointmentTime) async {
    final tz.TZDateTime tzAppointment =
    tz.TZDateTime.from(appointmentTime, tz.local);
    final tz.TZDateTime notifyTime =
    tzAppointment.subtract(const Duration(minutes: 30));

    if (notifyTime.isAfter(tz.TZDateTime.now(tz.local))) {
      await _notificationsPlugin.zonedSchedule(
        0,
        'Dialysis Appointment Reminder',
        'Your appointment is in 30 minutes. Please arrive at least 15 minutes early.',
        notifyTime,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'dialysis_channel',
            'Dialysis Notifications',
            channelDescription: 'Reminders for patient dialysis appointments.',
            importance: Importance.max,
            priority: Priority.high,
          ),
        ),
        androidAllowWhileIdle: true,
        uiLocalNotificationDateInterpretation:
        UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
      );
    }
  }

  void _startCountdown(DateTime targetTime) {
    _timer?.cancel();
    _appointmentDate = targetTime;
    _updateTimeLeft();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _updateTimeLeft());
  }

  void _updateTimeLeft() {
    if (_appointmentDate == null) return;
    final now = DateTime.now();
    final diff = _appointmentDate!.difference(now);
    if (diff.isNegative) {
      _timer?.cancel();
      if (mounted) setState(() => _timeLeft = Duration.zero);
    } else {
      if (mounted) setState(() => _timeLeft = diff);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _formatCountdown(Duration duration) {
    if (duration.inSeconds <= 0) return "SESSION OVERDUE";
    final days = duration.inDays;
    final hours = duration.inHours % 24;
    final minutes = duration.inMinutes % 60;
    final seconds = duration.inSeconds % 60;

    if (days > 0) return "$days day${days > 1 ? 's' : ''}, $hours hr left";
    if (hours > 0) return "$hours hr${hours > 1 ? 's' : ''}, $minutes min left";
    return "$minutes min $seconds sec left";
  }

  Color _countdownColor(Duration duration) {
    if (duration.inHours >= 24) return Colors.green.shade700;
    if (duration.inHours >= 1) return Colors.orange.shade700;
    return Colors.red.shade700;
  }
  // --------------------------------------------------------------------------

  // --- Build Methods for UI ---

  @override
  Widget build(BuildContext context) {
    final isWideScreen = MediaQuery.of(context).size.width >= 900;

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: SafeArea(
        child: isWideScreen ? _buildWebView(context) : _buildMobileView(context),
      ),
    );
  }

  // 📱 MOBILE VIEW
  Widget _buildMobileView(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text("Welcome, ${widget.fullName} 👋",
              style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: Theme.of(context).primaryColor)),
          const SizedBox(height: 16),
          // Using the fixed layout logic
          _buildNextAppointmentCard(context),
          const SizedBox(height: 24),
          _buildActionSection(context),
        ],
      ),
    );
  }

  // 💻 WEB VIEW (Fixed for consistency)
  Widget _buildWebView(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Welcome back, ${widget.fullName} 👋",
              style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.w800,
                  color: Theme.of(context).primaryColor)),
          const SizedBox(height: 32),
          _buildWebLayoutGrid(context),
        ],
      ),
    );
  }

  Widget _buildWebLayoutGrid(BuildContext context) {
    // Constraint ensures the content doesn't stretch awkwardly wide on huge monitors
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 1000), // Increased max width slightly for better use of space
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // --- 2.1 Next Session Card (Takes 100% of the constrained width) ---
          const Text("Your Next Session",
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 15),

          // We don't need a separate ConstrainedBox here, as the parent ConstrainedBox handles the width.
          _buildNextAppointmentCard(context),

          const SizedBox(height: 40),

          // --- 2.2 Quick Actions Grid (Two Equal-Width Flexible Cards) ---
          const Text("Quick Actions",
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 15),

          // Row and Expanded make the cards scale equally and flexibly
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Card 1: Book New Session
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(right: 20.0), // Consistent spacing between cards
                  child: _buildServiceCard(context),
                ),
              ),

              // Card 2: Manage Profile
              Expanded(
                child: _buildProfileCard(context),
              ),
            ],
          ),
          const SizedBox(height: 20), // Final bottom space
        ],
      ),
    );
  }

  Widget _buildActionSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Quick Actions",
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        _buildServiceCard(context),
        const SizedBox(height: 12),
        _buildProfileCard(context),
      ],
    );
  }

  // 💧 Service Card (Book Appointment)
  Widget _buildServiceCard(BuildContext context) {
    void navigateToBookPage() => widget.onNavigate?.call(2);
    return Card(
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.add_circle_outline, size: 48, color: Colors.teal.shade400),
            const SizedBox(height: 16),
            const Text("Book New Session",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
            const SizedBox(height: 8),
            const Text("Schedule your next hemodialysis appointment now."),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: navigateToBookPage,
              icon: const Icon(Icons.calendar_today),
              label: const Text("Book Now"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
            )
          ],
        ),
      ),
    );
  }

  // 👤 Profile Card (Update Details)
  Widget _buildProfileCard(BuildContext context) {
    void navigateToProfile() => widget.onNavigate?.call(3);
    return Card(
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.account_circle, size: 48, color: Colors.indigo.shade400),
            const SizedBox(height: 16),
            const Text("Manage Profile",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
            const SizedBox(height: 8),
            const Text("Review, update, and manage your personal details."),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: navigateToProfile,
              icon: const Icon(Icons.settings),
              label: const Text("Go to Profile"),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
                side: BorderSide(color: Colors.indigo.shade400),
                foregroundColor: Colors.indigo.shade400,
              ),
            )
          ],
        ),
      ),
    );
  }

  // 📅 Next Appointment
  Widget _buildNextAppointmentCard(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 900;
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('appointments')
          .where('patientId', isEqualTo: widget.userId)
          .where('status', whereIn: ['pending', 'approved', 'rescheduled', 'showed'])
          .orderBy('date')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()));
        }

        final doc = snapshot.data?.docs.isNotEmpty == true
            ? snapshot.data!.docs.first
            : null;

        if (doc == null) return _emptyAppointmentCard();

        // ------------------------------------------------------------------
        // FIX: SAFE DATA ACCESS TO ELIMINATE BadState ERROR
        // ------------------------------------------------------------------
        final data = doc.data() as Map<String, dynamic>;

        final date = (data['date'] as Timestamp).toDate();
        final slot = data['slot'] ?? "N/A";
        final status = data['status'] ?? "Pending";

        // This is the CRITICAL FIX: Use the data map's containsKey check
        final bed = data.containsKey('bedName') && data['bedName']?.toString().isNotEmpty == true
            ? data['bedName']
            : "Pending";

        final statusColor = _getStatusColor(status);
        // ------------------------------------------------------------------

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          if (_appointmentDate == null ||
              _appointmentDate!.difference(date).inMinutes.abs() > 1) {
            _startCountdown(date);
            _scheduleNotification(date);
          }
        });

        final countdownText =
        _timeLeft != null ? _formatCountdown(_timeLeft!) : "Loading...";
        final countdownColor =
        _timeLeft != null ? _countdownColor(_timeLeft!) : Colors.grey;

        IconData icon = Icons.calendar_month_outlined;
        Color iconColor = Colors.blue.shade700;
        if (status.toLowerCase() == 'approved') {
          icon = Icons.check_circle_outline;
          iconColor = Colors.green.shade700;
        } else if (status.toLowerCase() == 'rescheduled') {
          icon = Icons.schedule;
          iconColor = Colors.orange.shade700;
        } else if (status.toLowerCase() == 'showed') {
          icon = Icons.directions_run;
          iconColor = Colors.purple.shade700;
        }

        return Card(
          elevation: 8,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  children: [
                    Icon(icon, size: 48, color: iconColor),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(status.toUpperCase(),
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: statusColor)),
                    )
                  ],
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Your Next Session",
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: isWide ? 22 : 18,
                              color: Theme.of(context).primaryColor)),
                      const SizedBox(height: 10),
                      _detail("Date",
                          DateFormat('MMM d, yyyy').format(date)),
                      _detail("Time Slot", slot),
                      _detail("Assigned Bed", bed),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Icon(Icons.access_time_filled,
                              size: 18, color: countdownColor),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              countdownText,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: countdownColor),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: isWide ? const EdgeInsets.only(top: 8.0) : EdgeInsets.zero,
                  child: TextButton.icon(
                    onPressed: () => widget.onNavigate?.call(1),
                    icon: const Icon(Icons.visibility),
                    label: Text(isWide ? 'View Details' : 'Details'),
                    style: TextButton.styleFrom(
                        foregroundColor: Theme.of(context).primaryColor),
                  ),
                )
              ],
            ),
          ),
        );
      },
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'rescheduled':
        return Colors.blue;
      case 'showed':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  Widget _emptyAppointmentCard() {
    return Card(
      elevation: 5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(24),
        child: Row(
          children: [
            const Icon(Icons.event_busy_outlined, size: 40, color: Colors.red),
            const SizedBox(width: 15),
            const Expanded(
              child: Text(
                "No upcoming sessions. Schedule your next dialysis session now!",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
            ),
            const SizedBox(width: 15),
            ElevatedButton(
                onPressed: () => widget.onNavigate?.call(2),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.shade600,
                  foregroundColor: Colors.white,
                ),
                child: const Text("Book Now"))
          ],
        ),
      ),
    );
  }

  Widget _detail(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
              width: 100,
              child: Text('$label:',
                  style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.grey))),
          Expanded(
              child: Text(value,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }
}