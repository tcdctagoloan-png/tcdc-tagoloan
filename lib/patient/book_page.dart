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

  final List<String> allSlots = const [
    "06:00 - 10:00",
    "10:00 - 14:00",
    "14:00 - 18:00",
    "18:00 - 22:00"
  ];

  Future<void> _selectDate() async {
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      // User is only allowed to book appointments starting from tomorrow
      firstDate: DateTime.now().add(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: ColorScheme.light(
              primary: Colors.green.shade700, // Header background color
              onPrimary: Colors.white, // Header text color
              onSurface: Colors.black87, // Body text color
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: Colors.green.shade700, // Button text color
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
      // 1. CHECK FOR EXISTING ACTIVE BOOKING
      // Prevents patient from having multiple active (pending/approved/rescheduled) appointments.
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

      // 2. CREATE NEW APPOINTMENT
      DocumentReference appointmentRef = await FirebaseFirestore.instance
          .collection('appointments')
          .add({
        'patientId': widget.userId,
        // Store only the date part as a Timestamp for consistent querying
        'date': Timestamp.fromDate(
          DateTime(selectedDate.year, selectedDate.month, selectedDate.day),
        ),
        'slot': slot,
        'bedName': null, // Bed will be assigned by the nurse/admin later
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });

      // 3. CREATE NOTIFICATION FOR ADMINS/NURSES
      await FirebaseFirestore.instance.collection('notifications').add({
        'nurseId': 'all', // Targeting all administrative roles
        'title': 'New Appointment',
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
    // Date object containing only year, month, and day for query comparison
    DateTime onlyDate =
    DateTime(selectedDate.year, selectedDate.month, selectedDate.day);

    final isWideScreen = _isWideScreen(context);

    // Common Widget for the Header (Date Selection)
    Widget dateHeader = Padding(
      padding: EdgeInsets.symmetric(horizontal: isWideScreen ? 0 : 16.0, vertical: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Primary Title: "Book Your Appointment"
          Padding(
            padding: const EdgeInsets.only(bottom: 12.0),
            child: Text(
              "Book Your Appointment",
              style: TextStyle(
                fontSize: isWideScreen ? 28 : 24,
                fontWeight: FontWeight.w900,
                color: Colors.black87,
              ),
            ),
          ),
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


    // Common StreamBuilder Logic for Slot List
    Widget slotList = Expanded(
      child: StreamBuilder<QuerySnapshot>(
        // 1. Stream for Admin Session Disablement
        stream: FirebaseFirestore.instance
            .collection('session')
            .where('sessionDate', isEqualTo: Timestamp.fromDate(onlyDate))
            .snapshots(),
        builder: (context, sessionSnap) {
          if (sessionSnap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Colors.green));
          }

          Map<String, bool> enabledMap = {for (var s in allSlots) s: true};

          // Check which slots the admin has explicitly disabled
          for (var doc in sessionSnap.data?.docs ?? []) {
            String slot = doc['slot'];
            bool enabled = doc['isActive'] ?? true;
            enabledMap[slot] = enabled;
          }

          // 2. Stream for Appointments Count
          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('appointments')
                .where(
              'date',
              isGreaterThanOrEqualTo: Timestamp.fromDate(onlyDate),
            )
                .where(
              'date',
              isLessThan: Timestamp.fromDate(
                onlyDate.add(const Duration(days: 1)),
              ),
            )
                .where('status',
                whereIn: ['pending', 'approved', 'rescheduled'])
                .snapshots(),
            builder: (context, appSnap) {
              if (appSnap.connectionState ==
                  ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(color: Colors.green));
              }

              // Initialize counts for all slots
              Map<String, int> slotCounts =
              {for (var s in allSlots) s: 0};

              // Count active appointments per slot (LOGIC RETAINED)
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

                  // Check availability based on 16 bed limit (LOGIC RETAINED)
                  bool slotFull = bookedCount >= maxBeds;
                  // Check availability based on Admin control (LOGIC RETAINED)
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
                        side: BorderSide(color: isAvailable ? Colors.green.shade200 : cardColor, width: 1.5)
                    ),
                    color: cardColor,
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
                      leading: Icon(
                        isAvailable ? Icons.check_circle_outline : Icons.event_busy,
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
      // === MOBILE VERSION (Improved UI) ===
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

    // === WEB VERSION (Improved UI) ===
    return Scaffold(
      backgroundColor: Colors.grey.shade100, // Subtle background
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
