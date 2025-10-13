import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// IMPORTANT: Import the BookPage for rescheduling navigation
import 'book_page.dart';

class PatientAppointmentsPage extends StatelessWidget {
  final String userId;
  const PatientAppointmentsPage({super.key, required this.userId});

  // Function to update appointment status to 'cancelled' and notify the nurse/admin
  Future<void> _cancelAppointment(String appointmentId, String? nurseId, DateTime date, String slot) async {
    await FirebaseFirestore.instance
        .collection('appointments')
        .doc(appointmentId)
        .update({'status': 'cancelled'});

    // Create a notification for the associated nurse or 'all' if nurseId is null
    await FirebaseFirestore.instance.collection('notifications').add({
      // FIX 1: Send notification to the specific nurse or 'all' admins
      'nurseId': nurseId ?? 'all',
      'title': "Appointment Cancelled",
      'message': "Patient has cancelled their appointment on ${date.year}-${date.month}-${date.day} at $slot.",
      'appointmentId': appointmentId,
      'read': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  // Function to permanently delete an appointment record and notify the nurse/admin
  Future<void> _deleteAppointment(String appointmentId, String? nurseId, DateTime date, String slot) async {
    await FirebaseFirestore.instance
        .collection('appointments')
        .doc(appointmentId)
        .delete();

    // Create a notification for the associated nurse or 'all' if nurseId is null
    await FirebaseFirestore.instance.collection('notifications').add({
      // FIX 2: Send notification to the specific nurse or 'all' admins
      'nurseId': nurseId ?? 'all',
      'title': "Appointment Record Deleted",
      'message': "Patient has deleted their appointment record on ${date.year}-${date.month}-${date.day} at $slot.",
      'appointmentId': appointmentId,
      'read': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  // Check if an appointment can be cancelled (e.g., must be more than 1 hour away)
  bool _canCancel(DateTime appointmentDate) {
    final now = DateTime.now();
    return appointmentDate.isAfter(now.add(const Duration(hours: 1)));
  }

  @override
  Widget build(BuildContext context) {
    final isWideScreen = MediaQuery.of(context).size.width >= 900;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SingleChildScrollView(
        padding: isWideScreen ? EdgeInsets.zero : const EdgeInsets.all(16.0),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1000),
            child: isWideScreen
                ? _WebAppointmentView(
              userId: userId,
              canCancel: _canCancel,
              cancelAppointment: _cancelAppointment,
              deleteAppointment: _deleteAppointment,
            )
                : _AppointmentList(
              userId: userId,
              canCancel: _canCancel,
              cancelAppointment: _cancelAppointment,
              deleteAppointment: _deleteAppointment,
            ),
          ),
        ),
      ),
    );
  }
}

// Widget for the wide-screen (web) layout
class _WebAppointmentView extends StatelessWidget {
  final String userId;
  final bool Function(DateTime) canCancel;
  final Function(String, String?, DateTime, String) cancelAppointment;
  final Function(String, String?, DateTime, String) deleteAppointment;

  const _WebAppointmentView({
    required this.userId,
    required this.canCancel,
    required this.cancelAppointment,
    required this.deleteAppointment,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    "My Appointments",
                    style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.black87),
                  ),
                  SizedBox(height: 8),
                  Text(
                    "Manage your dialysis bookings and view status updates.",
                    style: TextStyle(fontSize: 18, color: Colors.black54),
                  ),
                  Divider(height: 30),
                ],
              ),
            ),
            _AppointmentList(
              userId: userId,
              canCancel: canCancel,
              cancelAppointment: cancelAppointment,
              deleteAppointment: deleteAppointment,
            ),
          ],
        ),
      ),
    );
  }
}


// Widget to display the list of appointments
class _AppointmentList extends StatelessWidget {
  final String userId;
  final bool Function(DateTime) canCancel;
  // FIX 3: Update parameter types to allow nullable String for nurseId
  final Function(String, String?, DateTime, String) cancelAppointment;
  final Function(String, String?, DateTime, String) deleteAppointment;

  const _AppointmentList({
    required this.userId,
    required this.canCancel,
    required this.cancelAppointment,
    required this.deleteAppointment,
  });

  // Function to handle the reschedule action
  void _rescheduleAppointment(BuildContext context, String currentAppointmentId) {
    // 1. First, show a confirmation dialog
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Reschedule Appointment"),
        content: const Text("To reschedule, your current pending/approved appointment will be marked as 'rescheduled' and you will be taken to the Book page to select a new date and time."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("No, Keep Current")),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx); // Close dialog

              // 2. Update the current appointment status to 'rescheduled'
              FirebaseFirestore.instance
                  .collection('appointments')
                  .doc(currentAppointmentId)
                  .update({'status': 'rescheduled', 'rescheduledAt': FieldValue.serverTimestamp()})
                  .then((_) {

                // 3. Navigate to the BookPage
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => BookPage(userId: userId),
                  ),
                );

                // 4. Show success message
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("Current appointment marked as 'rescheduled'. Please book your new slot."),
                    backgroundColor: Colors.blue,
                  ),
                );
              }).catchError((e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("Error marking appointment as rescheduled: $e")),
                );
              });
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue.shade700, foregroundColor: Colors.white),
            child: const Text("Yes, Reschedule"),
          ),
        ],
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    final isWideScreen = MediaQuery.of(context).size.width >= 900;

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('appointments')
          .where('patientId', isEqualTo: userId)
          .orderBy('date', descending: false)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: Padding(
            padding: EdgeInsets.all(50.0),
            child: CircularProgressIndicator(color: Colors.green),
          ));
        }
        if (snapshot.hasError) {
          return Center(child: Text("Error: ${snapshot.error}"));
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 40.0),
              child: Text(
                "You have no scheduled appointments.",
                style: TextStyle(fontSize: isWideScreen ? 20 : 16, color: Colors.grey.shade600),
              ),
            ),
          );
        }

        final appointments = snapshot.data!.docs;

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: appointments.length,
          itemBuilder: (context, index) {
            final data = appointments[index].data()! as Map<String, dynamic>;
            final appointmentId = appointments[index].id;
            final date = (data['date'] as Timestamp).toDate();
            final slot = data['slot'] ?? "N/A";
            final status = data['status'] ?? "pending";
            // FIX 4: nurseId should be treated as nullable
            final nurseId = data['nurseId'] as String?;

            final appointmentDateTime = DateTime(date.year, date.month, date.day, _getSlotHour(slot));

            final isFutureAppointment = appointmentDateTime.isAfter(DateTime.now());
            // An appointment can be active (pending or approved) and still in the future
            final isActiveFutureAppointment = isFutureAppointment && (status == "pending" || status == "approved");

            // Logic to determine if cancellation/reschedule is possible
            final canCancelAppointment = canCancel(appointmentDateTime) && status != "cancelled" && status != "rejected" && status != "rescheduled";
            final canReschedule = isActiveFutureAppointment;

            // Logic to determine if deletion (cleanup) is possible
            final canDelete = status == "cancelled" || status == "rejected" || status == "rescheduled" || appointmentDateTime.isBefore(DateTime.now());

            return Card(
              margin: const EdgeInsets.symmetric(vertical: 8),
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                // Highlight active appointments
                side: isActiveFutureAppointment ? BorderSide(color: _getStatusColor(status), width: 2) : BorderSide.none,
              ),
              child: ListTile(
                // Use a dynamic icon based on status
                leading: Icon(
                    isActiveFutureAppointment ? Icons.schedule : Icons.check_circle_outline,
                    color: _getStatusColor(status),
                    size: 30
                ),
                title: FutureBuilder<DocumentSnapshot<Object?>?>(
                  future: (nurseId != null)
                      ? FirebaseFirestore.instance.collection('users').doc(nurseId).get()
                      : Future.value(null),
                  builder: (context, nurseSnap) {
                    String nurseName = "Nurse TBD";
                    if (nurseSnap.connectionState == ConnectionState.waiting) {
                      nurseName = "Loading Nurse...";
                    } else if (nurseSnap.hasData && nurseSnap.data != null && nurseSnap.data!.exists) {
                      nurseName = nurseSnap.data!.get('fullName') ?? nurseSnap.data!.get('username') ?? "Unknown Nurse";
                    }
                    return Text("Attending Nurse: $nurseName", style: const TextStyle(fontWeight: FontWeight.bold));
                  },
                ),
                subtitle: Text("Date: ${date.month}/${date.day}/${date.year}\nTime Slot: $slot"),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Status Badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: _getStatusColor(status).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: _getStatusColor(status)),
                      ),
                      child: Text(
                        status.toUpperCase(),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: _getStatusColor(status),
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Reschedule Button (for active future appointments)
                    if (canReschedule)
                      Tooltip(
                        message: "Reschedule Appointment",
                        child: IconButton(
                          icon: const Icon(Icons.refresh, color: Colors.blue),
                          onPressed: () => _rescheduleAppointment(context, appointmentId),
                        ),
                      ),

                    // Cancel Button (for active future appointments, unless already done by reschedule)
                    if (canCancelAppointment)
                      Tooltip(
                        message: "Cancel Appointment",
                        child: IconButton(
                          icon: const Icon(Icons.cancel_schedule_send, color: Colors.red),
                          onPressed: () => _showCancelDialog(context, appointmentId, nurseId, date, slot),
                        ),
                      ),

                    // Delete Button
                    if (canDelete)
                      Tooltip(
                        message: "Delete Record",
                        child: IconButton(
                          icon: const Icon(Icons.delete, color: Colors.grey),
                          onPressed: () => _showDeleteDialog(context, appointmentId, nurseId, date, slot),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // Helper to convert time slot string to a 24h hour (for accurate date comparison)
  int _getSlotHour(String slot) {
    // This is a rough estimation. Your slot format is "06:00 - 10:00" (24h format), not AM/PM.
    // We'll use the start time's hour.
    try {
      final timePart = slot.split(' - ')[0];
      final hour = int.tryParse(timePart.split(':')[0]);
      return hour ?? 8; // Default to 8 if parsing fails
    } catch (_) {
      return 8;
    }
  }

  // Helper to get color based on status
  Color _getStatusColor(String status) {
    switch (status) {
      case "approved":
        return Colors.green;
      case "rejected":
        return Colors.red;
      case "cancelled":
        return Colors.grey;
      case "rescheduled":
        return Colors.purple;
      case "completed":
        return Colors.blue.shade700;
      default:
        return Colors.orange; // Pending
    }
  }

  // Dialog for cancelling an appointment
  Future<void> _showCancelDialog(BuildContext context, String appointmentId, String? nurseId, DateTime date, String slot) async {
    // FIX 5: Removed the 'if (nurseId == null) return;' line. The logic in _cancelAppointment handles the null case.

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Cancel Appointment"),
        content: const Text("Are you sure you want to cancel this appointment? This action notifies the clinic."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("No", style: TextStyle(color: Colors.black54))),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx, true);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Cancelling appointment...')),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text("Yes, Cancel"),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await cancelAppointment(appointmentId, nurseId, date, slot);
    }
  }

  // Dialog for deleting an appointment record
  Future<void> _showDeleteDialog(BuildContext context, String appointmentId, String? nurseId, DateTime date, String slot) async {
    // FIX 6: Removed the 'if (nurseId == null) return;' line. The logic in _deleteAppointment handles the null case.

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete Appointment Record"),
        content: const Text("Are you sure you want to delete this appointment record? This action cannot be undone."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("No", style: TextStyle(color: Colors.black54))),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx, true);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Deleting record...')),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade800, foregroundColor: Colors.white),
            child: const Text("Yes, Delete"),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await deleteAppointment(appointmentId, nurseId, date, slot);
    }
  }
}