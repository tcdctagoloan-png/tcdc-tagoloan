import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AdminAppointmentsPage extends StatefulWidget {
  const AdminAppointmentsPage({super.key});

  @override
  State<AdminAppointmentsPage> createState() => _AdminAppointmentsPageState();
}

class _AdminAppointmentsPageState extends State<AdminAppointmentsPage> {
  DateTime selectedDate = DateTime.now();
  List<String> allSessions = [
    "06:00 - 10:00",
    "10:00 - 14:00",
    "14:00 - 18:00",
    "18:00 - 22:00"
  ];

  // Unified messaging function for web and mobile
  void _showMessage(BuildContext context, String message, {bool isError = false}) {
    bool isWideScreen = MediaQuery.of(context).size.width >= 900;

    if (isWideScreen) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(isError ? "Error" : "Success"),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text("OK"),
            ),
          ],
        ),
      );
    } else {
      final snackBar = SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
      );
      ScaffoldMessenger.of(context).showSnackBar(snackBar);
    }
  }

  Future<void> toggleSession(String slot, bool current) async {
    final newStatus = !current;
    final statusText = newStatus ? "available" : "unavailable";

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Confirm Change", style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text("Are you sure you want to mark slot '$slot' as $statusText?"),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text("Cancel")),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: newStatus ? Colors.green : Colors.red,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text("Yes")),
        ],
      ),
    );

    if (confirm != true) return;

    final sessionDate = DateTime(selectedDate.year, selectedDate.month, selectedDate.day);

    try {
      final query = await FirebaseFirestore.instance
          .collection("session")
          .where("sessionDate", isEqualTo: Timestamp.fromDate(sessionDate))
          .where("slot", isEqualTo: slot)
          .get();

      String sessionId;
      if (query.docs.isEmpty) {
        final docRef = await FirebaseFirestore.instance.collection("session").add({
          "sessionDate": Timestamp.fromDate(sessionDate),
          "slot": slot,
          "isActive": newStatus,
          "bedId": null,
          "patientId": null,
          "nurseId": null,
        });
        sessionId = docRef.id;
      } else {
        sessionId = query.docs.first.id;
        await FirebaseFirestore.instance.collection("session").doc(sessionId).update({"isActive": newStatus});
      }

      if (!mounted) return;
      _showMessage(context, "Slot '$slot' marked as $statusText");

      // Notify nurses
      await FirebaseFirestore.instance.collection("notifications").add({
        'role': 'nurse', // Target nurses
        'title': "Slot $statusText",
        'message': "Slot '$slot' on ${sessionDate.toLocal().toString().split(' ')[0]} is now $statusText.",
        'createdAt': FieldValue.serverTimestamp(),
        'isRead': false,
      });

      // Notify all patients
      final patientsSnapshot = await FirebaseFirestore.instance.collection("users").where('role', isEqualTo: 'patient').get();
      for (var patientDoc in patientsSnapshot.docs) {
        await FirebaseFirestore.instance.collection("notifications").add({
          'userId': patientDoc.id,
          'title': "Slot $statusText",
          'message': "Reminder: Slot '$slot' on ${sessionDate.toLocal().toString().split(' ')[0]} is now $statusText. ${!newStatus ? "This slot is not available today." : ""}",
          'createdAt': FieldValue.serverTimestamp(),
          'isRead': false,
        });
      }

    } catch (e) {
      _showMessage(context, "Failed to update slot: $e", isError: true);
    }
  }

  bool _isWideScreen(BuildContext context) =>
      MediaQuery.of(context).size.width >= 900;

  @override
  Widget build(BuildContext context) {
    final onlyDate =
    DateTime(selectedDate.year, selectedDate.month, selectedDate.day);

    return Scaffold(
      floatingActionButton: _isWideScreen(context) ? null : FloatingActionButton.extended(
        onPressed: () async {
          DateTime? picked = await showDatePicker(
            context: context,
            initialDate: selectedDate,
            firstDate: DateTime.now(),
            lastDate: DateTime(2100),
          );
          if (picked != null) setState(() => selectedDate = picked);
        },
        label: const Text("Change Date"),
        icon: const Icon(Icons.calendar_today),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_isWideScreen(context))
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "Appointments",
                    style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87),
                  ),
                  ElevatedButton.icon(
                    onPressed: () async {
                      DateTime? picked = await showDatePicker(
                        context: context,
                        initialDate: selectedDate,
                        firstDate: DateTime.now(),
                        lastDate: DateTime(2100),
                      );
                      if (picked != null) setState(() => selectedDate = picked);
                    },
                    icon: const Icon(Icons.calendar_today, color: Colors.white),
                    label: Text(
                      "Appointments for ${onlyDate.toLocal().toString().split(' ')[0]}",
                      style: const TextStyle(color: Colors.white),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                  ),
                ],
              )
            else
              Text(
                "Appointments for ${onlyDate.toLocal().toString().split(' ')[0]}",
                style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87),
              ),
            const SizedBox(height: 24),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection("session")
                    .where("sessionDate",
                    isEqualTo: Timestamp.fromDate(onlyDate))
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState ==
                      ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  Map<String, bool> enabledMap =
                  {for (var slot in allSessions) slot: true};
                  for (var doc in snapshot.data?.docs ?? []) {
                    enabledMap[doc['slot']] = doc['isActive'] ?? true;
                  }

                  return GridView.builder(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: _isWideScreen(context) ? 3 : 1,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      childAspectRatio: _isWideScreen(context) ? 2.5 : 4,
                    ),
                    itemCount: allSessions.length,
                    itemBuilder: (context, index) {
                      final slot = allSessions[index];
                      final enabled = enabledMap[slot] ?? true;
                      return Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: Colors.grey.shade200),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    slot,
                                    style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black87),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    enabled ? "Available" : "Unavailable",
                                    style: TextStyle(
                                      color: enabled ? Colors.green : Colors.red,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                              Switch(
                                value: enabled,
                                onChanged: (_) => toggleSession(slot, enabled),
                                activeColor: Colors.green,
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