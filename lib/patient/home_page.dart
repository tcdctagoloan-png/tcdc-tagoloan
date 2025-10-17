import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

// ✅ Notifications setup
final FlutterLocalNotificationsPlugin _notificationsPlugin =
FlutterLocalNotificationsPlugin();

class HomePage extends StatefulWidget {
  final String userId;
  final String fullName;
  final Function(int)? onNavigate;

  const HomePage({
    super.key,
    required this.userId,
    required this.fullName,
    this.onNavigate,
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  Timer? _timer;
  Duration? _timeLeft;
  DateTime? _appointmentDate;

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

    await _notificationsPlugin.zonedSchedule(
      0,
      'Dialysis Appointment Reminder',
      'Your appointment is in 30 minutes. Please arrive at least 15 minutes early.',
      notifyTime,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'dialysis_channel',
          'Dialysis Notifications',
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

  void _startCountdown(DateTime targetTime) {
    _timer?.cancel();
    _appointmentDate = targetTime;
    _updateTimeLeft();
    _timer = Timer.periodic(const Duration(minutes: 1), (_) => _updateTimeLeft());
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
    final days = duration.inDays;
    final hours = duration.inHours % 24;
    final minutes = duration.inMinutes % 60;
    if (days > 0) return "$days day${days > 1 ? 's' : ''}, $hours hr left";
    if (hours > 0) return "$hours hr${hours > 1 ? 's' : ''}, $minutes min left";
    return "$minutes min left";
  }

  Color _countdownColor(Duration duration) {
    if (duration.inHours >= 24) return Colors.green;
    if (duration.inHours >= 1) return Colors.orange;
    return Colors.red;
  }

  @override
  Widget build(BuildContext context) {
    final isWideScreen = MediaQuery.of(context).size.width >= 900;
    return Scaffold(
      backgroundColor: Colors.white,
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
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          _buildProfileCard(context),
          const SizedBox(height: 20),
          const Text("Next Appointment",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          _buildNextAppointmentCard(context),
          const SizedBox(height: 20),
          const Text("Our Service",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          _buildServiceCard(context),
        ],
      ),
    );
  }

  // 💻 WEB VIEW (✅ full-width, no gradient)
  Widget _buildWebView(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Welcome back, ${widget.fullName} 👋",
              style: const TextStyle(
                  fontSize: 32, fontWeight: FontWeight.w700, color: Colors.blueGrey)),
          const SizedBox(height: 24),
          const Text("Next Session",
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 15),
          _buildNextAppointmentCard(context),
          const SizedBox(height: 30),
          Wrap(
            spacing: 40,
            runSpacing: 20,
            children: [
              SizedBox(width: 400, child: _buildServiceCard(context)),
              SizedBox(width: 400, child: _buildProfileCard(context)),
            ],
          ),
        ],
      ),
    );
  }

  // 💧 Service Card
  Widget _buildServiceCard(BuildContext context) {
    void navigateToBookPage() => widget.onNavigate?.call(2);
    return Card(
      elevation: 5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.water_drop_outlined, size: 48, color: Colors.blue),
            const SizedBox(height: 16),
            const Text("Hemodialysis",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
            const SizedBox(height: 8),
            const Text("Regular, in-center dialysis sessions."),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: navigateToBookPage,
              icon: const Icon(Icons.add_circle_outline),
              label: const Text("Book Now"),
            )
          ],
        ),
      ),
    );
  }

  // 👤 Profile Card
  Widget _buildProfileCard(BuildContext context) {
    void navigateToProfile() => widget.onNavigate?.call(3);
    return Card(
      elevation: 5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.account_circle_outlined,
                size: 48, color: Colors.deepOrange),
            const SizedBox(height: 16),
            const Text("Update Profile",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
            const SizedBox(height: 8),
            const Text("Review and manage your personal details."),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: navigateToProfile,
              icon: const Icon(Icons.arrow_forward),
              label: const Text("Go to Profile"),
            )
          ],
        ),
      ),
    );
  }

  // 📅 Next Appointment (✅ fixed build + stable UI)
  Widget _buildNextAppointmentCard(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('appointments')
          .where('patientId', isEqualTo: widget.userId)
          .where('status', whereIn: ['pending', 'approved'])
          .orderBy('date')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final doc = snapshot.data?.docs.isNotEmpty == true
            ? snapshot.data!.docs.first
            : null;

        if (doc == null) return _emptyAppointmentCard();

        final date = (doc['date'] as Timestamp).toDate();
        final slot = doc['slot'] ?? "N/A";
        final status = doc['status'];
        final bed = doc['bedName'] ?? "Pending";

        // ✅ FIX: Run countdown + notifications after build
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          if (_appointmentDate == null ||
              _appointmentDate!.difference(date).inMinutes != 0) {
            _startCountdown(date);
            _scheduleNotification(date);
          }
        });

        final countdownText =
        _timeLeft != null ? _formatCountdown(_timeLeft!) : "Loading...";
        final countdownColor =
        _timeLeft != null ? _countdownColor(_timeLeft!) : Colors.grey;

        return Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          padding: const EdgeInsets.all(24),
          child: Wrap(
            spacing: 20,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.start,
            children: [
              const Icon(Icons.calendar_month_outlined,
                  size: 48, color: Colors.blue),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Your Next Session",
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            color: Colors.blue.shade800)),
                    const SizedBox(height: 8),
                    _detail("Date", "${date.month}/${date.day}/${date.year}"),
                    _detail("Time", slot),
                    _detail("Bed", bed),
                    _detail("Status", status),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(Icons.access_time,
                            size: 18, color: Colors.blue),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            countdownText,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: countdownColor),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () => widget.onNavigate?.call(1),
                  icon: const Icon(Icons.arrow_forward),
                  label: const Text('View Details'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _emptyAppointmentCard() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(24),
      child: const Row(
        children: [
          Icon(Icons.event_available_outlined, size: 40, color: Colors.blue),
          SizedBox(width: 15),
          Expanded(
            child: Text(
              "No upcoming sessions. Click 'Book Now' below to schedule one!",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _detail(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
              width: 70,
              child: Text('$label:',
                  style: const TextStyle(fontWeight: FontWeight.w600))),
          Expanded(
              child: Text(value,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.normal))),
        ],
      ),
    );
  }
}
