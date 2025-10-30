import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

// Assuming these are constants defined globally or within this file
const List<String> kDefaultSlots = [
  "3:00 AM - 7:00 AM",
  "7:30 AM - 11:30 AM",
  "12:30 PM - 4:30 PM",
];

class BookPage extends StatefulWidget {
  final String userId;
  // Function to navigate after success (e.g., to the Appointments page at index 1)
  final Function(int)? onNavigate;

  const BookPage({
    super.key,
    required this.userId,
    this.onNavigate,
  });

  @override
  State<BookPage> createState() => _BookPageState();
}

class _BookPageState extends State<BookPage> {
  DateTime selectedDate = DateTime.now().add(const Duration(days: 1));

  @override
  void initState() {
    super.initState();
    // Ensures initial date is never a Sunday
    if (selectedDate.weekday == DateTime.sunday) {
      selectedDate = selectedDate.add(const Duration(days: 1));
    }
  }

  bool _isWideScreen(BuildContext context) =>
      MediaQuery.of(context).size.width >= 900;

  // Let patient pick another day (no Sundays)
  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime.now().add(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      // Filter out Sundays
      selectableDayPredicate: (DateTime date) {
        return date.weekday != DateTime.sunday;
      },
      builder: (context, child) {
        // Apply professional theme to the date picker
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: ColorScheme.light(
              primary: Colors.teal.shade700,
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(foregroundColor: Colors.teal.shade700),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        selectedDate = picked;
      });
    }
  }

  /// Stream the session docs for the chosen day.
  Stream<QuerySnapshot> _sessionForSelectedDateStream() {
    final onlyDate = DateTime(selectedDate.year, selectedDate.month, selectedDate.day);
    return FirebaseFirestore.instance
        .collection("session")
        .where(
      "sessionDate",
      isEqualTo: Timestamp.fromDate(onlyDate),
    )
        .snapshots();
  }

  // Confirmation dialog before booking
  void _showConfirmationDialog({
    required String slotTimeRange,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Your Appointment'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Please review the details before confirming:",
              style: TextStyle(fontSize: 15, color: Colors.black87),
            ),
            const SizedBox(height: 12),
            _infoRow(
              icon: Icons.calendar_today,
              label: "Date",
              value: DateFormat('EEEE, MMMM d, y').format(selectedDate),
            ),
            _infoRow(
              icon: Icons.access_time_filled,
              label: "Time",
              value: slotTimeRange,
            ),
            const SizedBox(height: 16),
            const Text(
              "Note: Your booking status will be 'Pending' until reviewed by the nurse.",
              style: TextStyle(fontSize: 13, fontStyle: FontStyle.italic, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
            },
            child: const Text(
              "Cancel",
              style: TextStyle(color: Colors.red),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await _bookSlot(slotTimeRange);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal.shade700,
              foregroundColor: Colors.white,
            ),
            child: const Text("Confirm & Book"),
          ),
        ],
      ),
    );
  }

  Widget _infoRow({required IconData icon, required String label, required String value}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Colors.teal.shade700),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.black54)),
              Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            ],
          ),
        ],
      ),
    );
  }

  /// Actually write the appointment and navigate
  Future<void> _bookSlot(String slotTimeRange) async {
    try {
      // 1. block multiple active bookings by same patient
      final existing = await FirebaseFirestore.instance
          .collection('appointments')
          .where('patientId', isEqualTo: widget.userId)
          .where('status', whereIn: ['pending', 'approved', 'rescheduled', 'showed'])
          .get();

      if (existing.docs.isNotEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('You already have an active booking. Please check the Appointments tab.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      // 2. create the appointment
      final appointmentRef = await FirebaseFirestore.instance
          .collection('appointments')
          .add({
        'patientId': widget.userId,
        'date': Timestamp.fromDate(
          DateTime(selectedDate.year, selectedDate.month, selectedDate.day),
        ),
        'slot': slotTimeRange,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });

      // 3. notify nurses (broadcast style)
      await FirebaseFirestore.instance.collection('notifications').add({
        'nurseId': 'all',
        'title': 'New Appointment Request',
        'message':
        'Patient booked $slotTimeRange on ${DateFormat('y-MM-dd').format(selectedDate)}',
        'appointmentId': appointmentRef.id,
        'read': false,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // 4. success toast
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Successfully booked $slotTimeRange! Redirecting to Appointments...'),
            backgroundColor: Colors.green,
          ),
        );

        // 5. Navigate to Appointments Page (assuming index 1 for Appointments)
        widget.onNavigate?.call(1);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: Failed to book appointment. $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isWideScreen = _isWideScreen(context);
    final isMobile = MediaQuery.of(context).size.width < 600;

    return SingleChildScrollView(
      // Padding adjusts based on screen size
      padding: isWideScreen
          ? const EdgeInsets.fromLTRB(32, 24, 32, 24)
          : const EdgeInsets.all(16.0),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── HEADER ─────────────────────────────────────────
              Text(
                "Book Your Appointment",
                style: TextStyle(
                    fontSize: isWideScreen ? 32 : 28, // Responsive font size
                    fontWeight: FontWeight.bold,
                    color: Colors.black87),
              ),
              const SizedBox(height: 12),
              Text(
                "Select an available date and time slot for your dialysis session.",
                style: TextStyle(fontSize: 16, color: Colors.grey.shade700),
              ),
              const Divider(height: 30),

              // ── DATE SELECTION CARD ────────────────────────────
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                color: Colors.white,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    // Layout changes for mobile screens
                    mainAxisAlignment: isMobile ? MainAxisAlignment.center : MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Date Display Column
                      Flexible(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text("Selected Date", style: TextStyle(fontSize: 14, color: Colors.black54)),
                            const SizedBox(height: 4),
                            Text(
                              DateFormat('EEEE, MMMM d, y').format(selectedDate),
                              style: TextStyle(
                                fontSize: isWideScreen ? 20 : 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.teal.shade700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Button (moved to a new line on mobile)
                      if (!isMobile)
                        ElevatedButton.icon(
                          onPressed: _selectDate,
                          icon: const Icon(Icons.edit_calendar, size: 20),
                          label: const Text("Change Date"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue.shade600,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      if (isMobile) const SizedBox(width: 16),
                    ],
                  ),
                ),
              ),

              // Button for mobile (outside the card)
              if (isMobile)
                Padding(
                  padding: const EdgeInsets.only(top: 16.0),
                  child: Center(
                    child: ElevatedButton.icon(
                      onPressed: _selectDate,
                      icon: const Icon(Icons.edit_calendar, size: 20),
                      label: const Text("Change Date"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue.shade600,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 50), // Full width on mobile
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                ),

              const SizedBox(height: 24),
              const Text(
                "Available Time Slots",
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87),
              ),
              const SizedBox(height: 12),

              // ── SLOT LIST ─────────────────────────────────────
              StreamBuilder<QuerySnapshot>(
                stream: _sessionForSelectedDateStream(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: Padding(
                          padding: EdgeInsets.only(top: 50),
                          child: CircularProgressIndicator(color: Colors.teal)),
                    );
                  }

                  // Availability map logic (unchanged)
                  final Map<String, bool> availabilityMap = {
                    for (final slot in kDefaultSlots) slot: true,
                  };
                  for (final doc in snapshot.data?.docs ?? []) {
                    final data = doc.data() as Map<String, dynamic>;
                    final slotLabel = data['slot'] as String?;
                    final isActive = data['isActive'] as bool?;
                    if (slotLabel != null && isActive != null) {
                      availabilityMap[slotLabel] = isActive;
                    }
                  }
                  final List<String> availableToday = availabilityMap.entries
                      .where((entry) => entry.value == true)
                      .map((entry) => entry.key)
                      .toList();

                  if (availableToday.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(40.0),
                        child: Text(
                          "No available slots for ${DateFormat('y-MM-dd').format(selectedDate)}. Please select another day.",
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 16, color: Colors.red),
                        ),
                      ),
                    );
                  }

                  return ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: availableToday.length,
                    itemBuilder: (context, index) {
                      final slotLabel = availableToday[index];

                      return _SlotBookingCard(
                        slotLabel: slotLabel,
                        onBookPressed: () => _showConfirmationDialog(slotTimeRange: slotLabel),
                        isMobile: isMobile,
                      );
                    },
                  );
                },
              ),
              const SizedBox(height: 50),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------
// Custom Slot Booking Card Widget
// ---------------------------------------------------

class _SlotBookingCard extends StatelessWidget {
  final String slotLabel;
  final VoidCallback onBookPressed;
  final bool isMobile; // Use this to adjust layout

  const _SlotBookingCard({
    required this.slotLabel,
    required this.onBookPressed,
    required this.isMobile,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.teal.shade300, width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Icon
                Icon(Icons.schedule, color: Colors.teal.shade700, size: 30),
                const SizedBox(width: 16),

                // 2. Time Slot Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("Time Slot", style: TextStyle(fontSize: 12, color: Colors.black54)),
                      Text(
                        slotLabel,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: isMobile ? 16 : 18,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.check_circle, size: 16, color: Colors.green.shade700),
                          const SizedBox(width: 4),
                          Text(
                            "Available to book",
                            style: TextStyle(
                              color: Colors.green.shade700,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // 3. Action Button (only shows on wider screens in the row)
                if (!isMobile)
                  ElevatedButton(
                    onPressed: onBookPressed,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal.shade700,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text(
                      "Book Now",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
              ],
            ),

            // 4. Mobile Button (full width at the bottom)
            if (isMobile)
              Padding(
                padding: const EdgeInsets.only(top: 16.0),
                child: ElevatedButton(
                  onPressed: onBookPressed,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal.shade700,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 45), // Full width
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text(
                    "Book Now",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}