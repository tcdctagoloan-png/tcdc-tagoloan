import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class AdminAppointmentsPage extends StatefulWidget {
  const AdminAppointmentsPage({super.key});

  @override
  State<AdminAppointmentsPage> createState() => _AdminAppointmentsPageState();
}

class _AdminAppointmentsPageState extends State<AdminAppointmentsPage> {
  DateTime selectedDate = DateTime.now(); // Default date
  final List<Map<String, dynamic>> defaultSlots = [
    {'label': '3:00 AM - 7:00 AM', 'startHour': 3, 'endHour': 7},
    {'label': '7:30 AM - 11:30 AM', 'startHour': 7, 'endHour': 11},
    {'label': '12:30 PM - 4:30 PM', 'startHour': 12, 'endHour': 16},
  ];

  // Show success/error message
  void _showMessage(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }

  // Initialize default slots if they don't exist for the selected date
  Future<void> _initializeSlotsForSelectedDate() async {
    final firestore = FirebaseFirestore.instance.collection('session');
    final existing = await firestore
        .where('sessionDate', isEqualTo: Timestamp.fromDate(selectedDate))
        .get();

    // If there are no existing slots for the selected date, initialize them
    for (var i = 0; i < defaultSlots.length; i++) {
      final s = defaultSlots[i];
      final startTime = DateTime(selectedDate.year, selectedDate.month, selectedDate.day, s['startHour']);
      final endTime = DateTime(selectedDate.year, selectedDate.month, selectedDate.day, s['endHour']);

      final slotExists = existing.docs.any((doc) => doc['time'] == s['label']); // Check if this slot already exists

      if (!slotExists) {
        // If slot does not exist for this date, add it
        await firestore.add({
          'slotId': 'slot${i + 1}',
          'time': s['label'],
          'startTime': Timestamp.fromDate(startTime),
          'endTime': Timestamp.fromDate(endTime),
          'isActive': true, // Slot available by default
          'status': 'available',
          'assignedPatients': [],
          'sessionDate': Timestamp.fromDate(selectedDate),
          'availableDays': ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"],
        });
      }
    }
    _showMessage("Default slots initialized for ${DateFormat('MMMM d, yyyy').format(selectedDate)}.");
  }

  // Function to allow admin to select a date and update availability
  Future<void> _selectDateAndUpdateSlotStatus(String id) async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
    );

    if (pickedDate != null) {
      setState(() {
        selectedDate = pickedDate;
      });
      await _initializeSlotsForSelectedDate(); // Reinitialize the slots for the new selected date
    }
  }

  // Toggle availability of a slot
  Future<void> _toggleActive(String id, bool newValue) async {
    try {
      await FirebaseFirestore.instance.collection('session').doc(id).update({
        'isActive': newValue,
        'status': newValue ? 'available' : 'unavailable',
      });
      _showMessage("Slot ${newValue ? 'enabled' : 'disabled'}");
    } catch (e) {
      _showMessage("Failed to update: $e", isError: true);
    }
  }

  // Delete a session slot
  Future<void> _deleteSlot(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete Slot"),
        content: const Text("Are you sure you want to delete this slot?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Delete"),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await FirebaseFirestore.instance.collection('session').doc(id).delete();
        _showMessage("Slot deleted");
      } catch (e) {
        _showMessage("Failed to delete: $e", isError: true);
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _initializeSlotsForSelectedDate(); // Ensure slots are initialized for the default date
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Admin Slot Manager")),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            // Header section with Date and Change Button
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Appointments for ${DateFormat('MMMM d, yyyy').format(selectedDate)}",
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                ElevatedButton.icon(
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: selectedDate,
                      firstDate: DateTime.now(),
                      lastDate: DateTime(2100),
                    );
                    if (picked != null) setState(() => selectedDate = picked);
                    await _initializeSlotsForSelectedDate(); // Reinitialize the slots for the new selected date
                  },
                  icon: const Icon(Icons.calendar_today),
                  label: const Text("Change Date"),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Session Slot List
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('session')
                    .where('sessionDate', isEqualTo: Timestamp.fromDate(selectedDate))
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final docs = snapshot.data?.docs ?? [];
                  if (docs.isEmpty) {
                    return const Center(child: Text("No slots available for the selected date."));
                  }

                  return ListView.builder(
                    itemCount: docs.length,
                    itemBuilder: (context, index) {
                      final doc = docs[index];
                      final data = doc.data() as Map<String, dynamic>? ?? {};
                      final isActive = data['isActive'] as bool? ?? true;
                      final timeLabel = data['time'] ?? '---';

                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        child: ListTile(
                          title: Text(timeLabel),
                          subtitle: Text(isActive ? "Available" : "Unavailable"),
                          leading: CircleAvatar(
                            backgroundColor: isActive ? Colors.green : Colors.red,
                            child: Text((index + 1).toString(), style: const TextStyle(color: Colors.white)),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Switch(
                                value: isActive,
                                onChanged: (v) => _toggleActive(doc.id, v),
                              ),
                              IconButton(
                                icon: const Icon(Icons.edit, color: Colors.blue),
                                onPressed: () => _selectDateAndUpdateSlotStatus(doc.id),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete, color: Colors.red),
                                onPressed: () => _deleteSlot(doc.id),
                              ),
                            ],
                          ),
                        ),
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
