import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class BookPage extends StatefulWidget {
  final String userId;
  const BookPage({super.key, required this.userId});

  @override
  _BookPageState createState() => _BookPageState();
}

class _BookPageState extends State<BookPage> {
  DateTime selectedDate = DateTime.now().add(const Duration(days: 1)); // Start with tomorrow's date
  final int maxBeds = 16; // Maximum capacity of beds per time slot

  /// Helper function: Converts 24-hour time (e.g. "13:00") to "1:00 PM"
  String formatTime(String time24) {
    final parts = time24.split(':');
    int hour = int.parse(parts[0]);
    final minute = parts[1];
    final period = hour >= 12 ? 'PM' : 'AM';
    if (hour == 0) hour = 12;
    else if (hour > 12) hour -= 12;
    return '$hour:${minute.padLeft(2, '0')} $period';
  }

  /// List of dialysis slots (converted to readable AM/PM format)
  late final List<String> allSlots = [
    '${formatTime("06:00")} - ${formatTime("10:00")}', // 6:00 AM – 10:00 AM
    '${formatTime("10:00")} - ${formatTime("14:00")}', // 10:00 AM – 2:00 PM
    '${formatTime("14:00")} - ${formatTime("18:00")}', // 2:00 PM – 6:00 PM
    '${formatTime("18:00")} - ${formatTime("22:00")}', // 6:00 PM – 10:00 PM
  ];

  Future<void> _selectDate() async {
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime.now().add(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: ColorScheme.light(
              primary: Colors.green.shade700,
              onPrimary: Colors.white,
              onSurface: Colors.black87,
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: Colors.green.shade700,
              ),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != selectedDate) {
      setState(() {
        selectedDate = picked;
      });
    }
  }

  Future<void> _bookSlot(String slot) async {
    try {
      // Prevent patient from multiple active bookings
      QuerySnapshot existing = await FirebaseFirestore.instance
          .collection('appointments')
          .where('patientId', isEqualTo: widget.userId)
          .where('status', whereIn: ['pending', 'approved', 'rescheduled'])
          .get();

      if (existing.docs.isNotEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('You already have an active booking')),
        );
        return;
      }

      // Create new appointment
      DocumentReference appointmentRef = await FirebaseFirestore.instance
          .collection('appointments')
          .add({
        'patientId': widget.userId,
        'date': Timestamp.fromDate(
          DateTime(selectedDate.year, selectedDate.month, selectedDate.day),
        ),
        'slot': slot,
        'bedName': null,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Notify nurse(s)
      await FirebaseFirestore.instance.collection('notifications').add({
        'nurseId': 'all',
        'title': 'New Appointment Request',
        'message': 'Patient booked $slot on ${selectedDate.toLocal().toString().split(' ')[0]}',
        'appointmentId': appointmentRef.id,
        'read': false,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Successfully requested booking for $slot'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error booking slot: $e')),
      );
    }
  }

  bool _isWideScreen(BuildContext context) =>
      MediaQuery.of(context).size.width >= 900;

  @override
  Widget build(BuildContext context) {
    DateTime onlyDate =
    DateTime(selectedDate.year, selectedDate.month, selectedDate.day);
    final isWideScreen = _isWideScreen(context);

    Widget dateHeader = Padding(
      padding: EdgeInsets.symmetric(horizontal: isWideScreen ? 0 : 16.0, vertical: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Book Your Appointment",
            style: TextStyle(
              fontSize: isWideScreen ? 28 : 24,
              fontWeight: FontWeight.w900,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            "Operating Hours: 6:00 AM – 10:00 PM",
            style: TextStyle(fontSize: 14, color: Colors.grey[700]),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Selected Date:", style: TextStyle(fontSize: 14, color: Colors.grey)),
                  Text(
                    selectedDate.toLocal().toString().split(' ')[0],
                    style: TextStyle(fontSize: isWideScreen ? 24 : 18, fontWeight: FontWeight.bold, color: Colors.green.shade800),
                  ),
                ],
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade700,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  elevation: 5,
                ),
                onPressed: _selectDate,
                icon: const Icon(Icons.calendar_today, size: 18),
                label: const Text("Change Date"),
              ),
            ],
          ),
        ],
      ),
    );

    Widget slotList = Expanded(
      child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('session')
            .where('sessionDate', isEqualTo: Timestamp.fromDate(onlyDate))
            .snapshots(),
        builder: (context, sessionSnap) {
          if (sessionSnap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Colors.green));
          }

          Map<String, bool> enabledMap = {for (var s in allSlots) s: true};
          for (var doc in sessionSnap.data?.docs ?? []) {
            String slot = doc['slot'];
            bool enabled = doc['isActive'] ?? true;
            enabledMap[slot] = enabled;
          }

          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('appointments')
                .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(onlyDate))
                .where('date', isLessThan: Timestamp.fromDate(onlyDate.add(const Duration(days: 1))))
                .where('status', whereIn: ['pending', 'approved', 'rescheduled'])
                .snapshots(),
            builder: (context, appSnap) {
              if (appSnap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(color: Colors.green));
              }

              Map<String, int> slotCounts = {for (var s in allSlots) s: 0};
              for (var doc in appSnap.data?.docs ?? []) {
                String bookedSlot = doc['slot'];
                if (slotCounts.containsKey(bookedSlot)) {
                  slotCounts[bookedSlot] = slotCounts[bookedSlot]! + 1;
                }
              }

              return ListView.builder(
                padding: isWideScreen ? const EdgeInsets.all(16) : const EdgeInsets.symmetric(horizontal: 8),
                itemCount: allSlots.length,
                itemBuilder: (context, index) {
                  String slot = allSlots[index];
                  int bookedCount = slotCounts[slot] ?? 0;
                  bool slotFull = bookedCount >= maxBeds;
                  bool adminDisabled = !(enabledMap[slot] ?? true);
                  bool isAvailable = !slotFull && !adminDisabled;

                  String statusText = '';
                  Color statusColor = Colors.grey.shade500;
                  Color cardColor = Colors.white;

                  if (slotFull) {
                    statusText = 'FULL';
                    statusColor = Colors.red.shade700;
                    cardColor = Colors.red.shade50;
                  } else if (adminDisabled) {
                    statusText = 'CLOSED';
                    statusColor = Colors.orange.shade700;
                    cardColor = Colors.orange.shade50;
                  } else {
                    statusText = 'AVAILABLE';
                    statusColor = Colors.green.shade700;
                    cardColor = Colors.white;
                  }

                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                    elevation: isAvailable ? 5 : 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                      side: BorderSide(color: isAvailable ? Colors.green.shade200 : cardColor, width: 1.5),
                    ),
                    color: cardColor,
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
                      leading: Icon(
                        isAvailable ? Icons.access_time_rounded : Icons.event_busy,
                        color: statusColor,
                        size: isWideScreen ? 30 : 24,
                      ),
                      title: Text(
                        slot,
                        style: TextStyle(
                          fontSize: isWideScreen ? 20 : 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      subtitle: Text(
                        "Booked: $bookedCount / $maxBeds | Status: $statusText",
                        style: TextStyle(
                          fontSize: isWideScreen ? 14 : 12,
                          color: statusColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      trailing: isAvailable
                          ? ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green.shade700,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          elevation: 3,
                        ),
                        onPressed: () => _bookSlot(slot),
                        icon: const Icon(Icons.send_rounded, size: 18),
                        label: const Text("Book"),
                      )
                          : Tooltip(
                        message: statusText,
                        child: Icon(
                          adminDisabled ? Icons.admin_panel_settings : Icons.block,
                          color: statusColor,
                          size: isWideScreen ? 30 : 24,
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );

    if (!isWideScreen) {
      return Scaffold(
        backgroundColor: Colors.grey.shade50,
        body: SafeArea(
          child: Column(
            children: [
              dateHeader,
              slotList,
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Card(
            elevation: 10,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                children: [
                  dateHeader,
                  slotList,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
