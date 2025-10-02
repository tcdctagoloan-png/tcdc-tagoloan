// book_page.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class BookPage extends StatefulWidget {
  final String userId;
  const BookPage({super.key, required this.userId});

  @override
  _BookPageState createState() => _BookPageState();
}

class _BookPageState extends State<BookPage> {
  DateTime selectedDate = DateTime.now();

  final List<String> allSlots = [
    "06:00 - 10:00",
    "10:00 - 14:00",
    "14:00 - 18:00",
    "18:00 - 22:00"
  ];

  Future<void> _selectDate() async {
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (picked != null && picked != selectedDate) {
      setState(() {
        selectedDate = picked;
      });
    }
  }

  Future<void> _bookSlot(String slot) async {
    try {
      QuerySnapshot existing = await FirebaseFirestore.instance
          .collection('appointments')
          .where('patientId', isEqualTo: widget.userId)
          .where('status', whereIn: ['pending', 'approved', 'rescheduled'])
          .get();

      if (existing.docs.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('You already have an active booking')),
        );
        return;
      }

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

      await FirebaseFirestore.instance.collection('notifications').add({
        'nurseId': 'all',
        'title': 'New Appointment',
        'message': 'Patient booked $slot on ${selectedDate.toLocal().toString().split(' ')[0]}',
        'appointmentId': appointmentRef.id,
        'read': false,
        'createdAt': FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Successfully booked $slot')),
      );
    } catch (e) {
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

    if (!_isWideScreen(context)) {
      // === MOBILE VERSION ===
      return Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Selected date: ${selectedDate.toLocal().toString().split(' ')[0]}",
                      style: const TextStyle(fontSize: 16),
                    ),
                    ElevatedButton(
                      onPressed: _selectDate,
                      child: const Text("Pick Date"),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('session')
                      .where('sessionDate', isEqualTo: Timestamp.fromDate(onlyDate))
                      .snapshots(),
                  builder: (context, sessionSnap) {
                    if (sessionSnap.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    Map<String, bool> enabledMap =
                    {for (var s in allSlots) s: true};

                    for (var doc in sessionSnap.data?.docs ?? []) {
                      String slot = doc['slot'];
                      bool enabled = doc['isActive'] ?? true;
                      enabledMap[slot] = enabled;
                    }

                    return StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('appointments')
                          .where(
                        'date',
                        isGreaterThanOrEqualTo: Timestamp.fromDate(
                          DateTime(onlyDate.year, onlyDate.month, onlyDate.day),
                        ),
                      )
                          .where(
                        'date',
                        isLessThan: Timestamp.fromDate(
                          DateTime(onlyDate.year, onlyDate.month, onlyDate.day)
                              .add(const Duration(days: 1)),
                        ),
                      )
                          .where('status',
                          whereIn: ['pending', 'approved', 'rescheduled'])
                          .snapshots(),
                      builder: (context, appSnap) {
                        if (appSnap.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator());
                        }

                        Map<String, int> slotCounts =
                        {for (var s in allSlots) s: 0};

                        for (var doc in appSnap.data?.docs ?? []) {
                          String bookedSlot = doc['slot'];
                          if (slotCounts.containsKey(bookedSlot)) {
                            slotCounts[bookedSlot] = slotCounts[bookedSlot]! + 1;
                          }
                        }

                        return ListView.builder(
                          itemCount: allSlots.length,
                          itemBuilder: (context, index) {
                            String slot = allSlots[index];
                            int bookedCount = slotCounts[slot] ?? 0;

                            bool slotFull = bookedCount >= 16;
                            bool adminDisabled = !(enabledMap[slot] ?? true);
                            bool isAvailable = !slotFull && !adminDisabled;

                            String tooltipMsg = '';
                            if (slotFull) tooltipMsg = 'Slot is full';
                            if (adminDisabled) tooltipMsg =
                            'Slot disabled by admin';

                            return Card(
                              margin: const EdgeInsets.symmetric(
                                  vertical: 8, horizontal: 16),
                              color: isAvailable
                                  ? Colors.white
                                  : Colors.grey.shade300,
                              child: ListTile(
                                title: Text(
                                  slot,
                                  style: TextStyle(
                                    color: isAvailable
                                        ? Colors.black
                                        : Colors.grey.shade600,
                                  ),
                                ),
                                subtitle: Text(
                                  "Booked: $bookedCount / 16",
                                  style: TextStyle(
                                    color: slotFull ? Colors.red : Colors.black,
                                  ),
                                ),
                                trailing: isAvailable
                                    ? ElevatedButton(
                                  onPressed: () => _bookSlot(slot),
                                  child: const Text("Book"),
                                )
                                    : Tooltip(
                                  message: tooltipMsg,
                                  child: const Text(
                                    "Unavailable",
                                    style: TextStyle(
                                        color: Colors.red,
                                        fontWeight: FontWeight.bold),
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
              ),
            ],
          ),
        ),
      );
    }

    // === WEB VERSION ===
    return Scaffold(
      body: Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.white, Colors.greenAccent],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Selected date: ${selectedDate.toLocal().toString().split(' ')[0]}",
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade700,
                    ),
                    onPressed: _selectDate,
                    child: const Text("Pick Date"),
                  ),
                ],
              ),
            ),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('session')
                    .where('sessionDate', isEqualTo: Timestamp.fromDate(onlyDate))
                    .snapshots(),
                builder: (context, sessionSnap) {
                  if (sessionSnap.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
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
                        .where(
                      'date',
                      isGreaterThanOrEqualTo: Timestamp.fromDate(
                        DateTime(onlyDate.year, onlyDate.month, onlyDate.day),
                      ),
                    )
                        .where(
                      'date',
                      isLessThan: Timestamp.fromDate(
                        DateTime(onlyDate.year, onlyDate.month, onlyDate.day)
                            .add(const Duration(days: 1)),
                      ),
                    )
                        .where('status',
                        whereIn: ['pending', 'approved', 'rescheduled'])
                        .snapshots(),
                    builder: (context, appSnap) {
                      if (appSnap.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      Map<String, int> slotCounts = {for (var s in allSlots) s: 0};

                      for (var doc in appSnap.data?.docs ?? []) {
                        String bookedSlot = doc['slot'];
                        if (slotCounts.containsKey(bookedSlot)) {
                          slotCounts[bookedSlot] = slotCounts[bookedSlot]! + 1;
                        }
                      }

                      return ListView.builder(
                        itemCount: allSlots.length,
                        itemBuilder: (context, index) {
                          String slot = allSlots[index];
                          int bookedCount = slotCounts[slot] ?? 0;

                          bool slotFull = bookedCount >= 16;
                          bool adminDisabled = !(enabledMap[slot] ?? true);
                          bool isAvailable = !slotFull && !adminDisabled;

                          String tooltipMsg = '';
                          if (slotFull) tooltipMsg = 'Slot is full';
                          if (adminDisabled) tooltipMsg = 'Slot disabled by admin';

                          return Card(
                            margin: const EdgeInsets.symmetric(
                                vertical: 8, horizontal: 16),
                            elevation: 4,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                            child: ListTile(
                              title: Text(
                                slot,
                                style: TextStyle(
                                  fontSize: 18,
                                  color: isAvailable
                                      ? Colors.black
                                      : Colors.grey.shade600,
                                ),
                              ),
                              subtitle: Text(
                                "Booked: $bookedCount / 16",
                                style: TextStyle(
                                  fontSize: 14,
                                  color: slotFull ? Colors.red : Colors.black,
                                ),
                              ),
                              trailing: isAvailable
                                  ? ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green.shade700,
                                ),
                                onPressed: () => _bookSlot(slot),
                                child: const Text("Book"),
                              )
                                  : Tooltip(
                                message: tooltipMsg,
                                child: const Text(
                                  "Unavailable",
                                  style: TextStyle(
                                      color: Colors.red,
                                      fontWeight: FontWeight.bold),
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
            ),
          ],
        ),
      ),
    );
  }
}
