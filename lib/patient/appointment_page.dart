import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class PatientAppointmentsPage extends StatelessWidget {
  final String userId;
  const PatientAppointmentsPage({super.key, required this.userId});

  // Function to update appointment status to 'cancelled' and notify the nurse
  Future<void> _cancelAppointment(String appointmentId, String nurseId, DateTime date, String slot) async {
    await FirebaseFirestore.instance
        .collection('appointments')
        .doc(appointmentId)
        .update({'status': 'cancelled'});

    // Create a notification for the associated nurse
    await FirebaseFirestore.instance.collection('notifications').add({
      'nurseId': nurseId,
      'title': "Appointment Cancelled",
      'message': "Patient has cancelled their appointment on ${date.year}-${date.month}-${date.day} at $slot.",
      'appointmentId': appointmentId,
      'read': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  // Function to permanently delete an appointment record and notify the nurse
  Future<void> _deleteAppointment(String appointmentId, String nurseId, DateTime date, String slot) async {
    await FirebaseFirestore.instance
        .collection('appointments')
        .doc(appointmentId)
        .delete();

    // Create a notification for the associated nurse
    await FirebaseFirestore.instance.collection('notifications').add({
      'nurseId': nurseId,
      'title': "Appointment Deleted",
      'message': "Patient has deleted their appointment record on ${date.year}-${date.month}-${date.day} at $slot.",
      'appointmentId': appointmentId,
      'read': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  // Check if an appointment can be cancelled (e.g., must be more than 24 hours away)
  bool _canCancel(DateTime appointmentDate) {
    final now = DateTime.now();
    // Allow cancellation if the appointment date is after today.
    // We check if it is at least 1 hour in the future to allow for buffer.
    return appointmentDate.isAfter(now.add(const Duration(hours: 1)));
  }

  @override
  Widget build(BuildContext context) {
    final isWideScreen = MediaQuery.of(context).size.width >= 900;

    // Remove the redundant top navigation bar and focus on the content
    return Scaffold(
      backgroundColor: Colors.transparent, // Background will be handled by the Dashboard's container/gradient
      body: SingleChildScrollView(
        padding: isWideScreen ? EdgeInsets.zero : const EdgeInsets.all(16.0),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1000), // Max width for content on web
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
  final Function(String, String, DateTime, String) cancelAppointment;
  final Function(String, String, DateTime, String) deleteAppointment;

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
  final Function(String, String, DateTime, String) cancelAppointment;
  final Function(String, String, DateTime, String) deleteAppointment;

  const _AppointmentList({
    required this.userId,
    required this.canCancel,
    required this.cancelAppointment,
    required this.deleteAppointment,
  });

  @override
  Widget build(BuildContext context) {
    final isWideScreen = MediaQuery.of(context).size.width >= 900;

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('appointments')
          .where('patientId', isEqualTo: userId)
      // Sort by date to show upcoming appointments first
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
            final nurseId = data['nurseId'] as String?;

            final appointmentDateTime = DateTime(date.year, date.month, date.day, _getSlotHour(slot));

            // FIX: Changed _canCancel to canCancel to use the function passed via constructor.
            // Logic to determine if cancellation is possible
            final canCancelAppointment = canCancel(appointmentDateTime) && status != "cancelled" && status != "rejected";

            // Logic to determine if deletion (cleanup) is possible
            final canDelete = status == "cancelled" || appointmentDateTime.isBefore(DateTime.now());

            return Card(
              margin: const EdgeInsets.symmetric(vertical: 8),
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: ListTile(
                leading: const Icon(Icons.calendar_month, color: Colors.green, size: 30),
                title: FutureBuilder<DocumentSnapshot<Object?>?>(
                  future: (nurseId != null)
                      ? FirebaseFirestore.instance.collection('users').doc(nurseId).get()
                      : Future.value(null),
                  builder: (context, nurseSnap) {
                    String nurseName = "Nurse TBD";
                    if (nurseSnap.connectionState == ConnectionState.waiting) {
                      nurseName = "Loading Nurse...";
                    } else if (nurseSnap.hasData && nurseSnap.data != null && nurseSnap.data!.exists) {
                      // Use fullName as the primary display name for nurses
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

                    // Cancel Button
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
    if (slot.contains('AM')) {
      final hour = int.tryParse(slot.split(':')[0]) ?? 0;
      return hour == 12 ? 0 : hour; // 12 AM is midnight (0)
    } else if (slot.contains('PM')) {
      final hour = int.tryParse(slot.split(':')[0]) ?? 0;
      return hour == 12 ? 12 : hour + 12; // 12 PM is noon (12)
    }
    return 8; // Default to 8 AM if format is unknown
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
      case "completed":
        return Colors.blue.shade700;
      default:
        return Colors.orange; // Pending
    }
  }

  // Dialog for cancelling an appointment
  Future<void> _showCancelDialog(BuildContext context, String appointmentId, String? nurseId, DateTime date, String slot) async {
    if (nurseId == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Cancel Appointment"),
        content: const Text("Are you sure you want to cancel this appointment? This action notifies the clinic."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("No", style: TextStyle(color: Colors.black54))),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text("Yes, Cancel"),
          ),
        ],
      ),
    );
    if (confirm == true) {
      // Use the function passed in the constructor
      await cancelAppointment(appointmentId, nurseId, date, slot);
    }
  }

  // Dialog for deleting an appointment record
  Future<void> _showDeleteDialog(BuildContext context, String appointmentId, String? nurseId, DateTime date, String slot) async {
    if (nurseId == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete Appointment Record"),
        content: const Text("Are you sure you want to delete this appointment record? This action cannot be undone."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("No", style: TextStyle(color: Colors.black54))),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade800, foregroundColor: Colors.white),
            child: const Text("Yes, Delete"),
          ),
        ],
      ),
    );
    if (confirm == true) {
      // Use the function passed in the constructor
      await deleteAppointment(appointmentId, nurseId, date, slot);
    }
  }
}
