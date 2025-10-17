import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'book_page.dart';

class PatientAppointmentsPage extends StatelessWidget {
  final String userId;
  const PatientAppointmentsPage({super.key, required this.userId});

  Future<void> _cancelAppointment(
      String appointmentId, String? nurseId, DateTime date, String slot) async {
    await FirebaseFirestore.instance
        .collection('appointments')
        .doc(appointmentId)
        .update({'status': 'cancelled'});

    await FirebaseFirestore.instance.collection('notifications').add({
      'nurseId': nurseId ?? 'all',
      'title': "Appointment Cancelled",
      'message':
      "A patient cancelled their appointment on ${_formatDate(date)} at $slot.",
      'appointmentId': appointmentId,
      'read': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _deleteAppointment(
      String appointmentId, String? nurseId, DateTime date, String slot) async {
    await FirebaseFirestore.instance
        .collection('appointments')
        .doc(appointmentId)
        .delete();

    await FirebaseFirestore.instance.collection('notifications').add({
      'nurseId': nurseId ?? 'all',
      'title': "Appointment Record Deleted",
      'message':
      "A patient deleted their appointment record on ${_formatDate(date)} at $slot.",
      'appointmentId': appointmentId,
      'read': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  bool _canCancel(DateTime appointmentDate) {
    final now = DateTime.now();
    return appointmentDate.isAfter(now.add(const Duration(hours: 1)));
  }

  String _formatDate(DateTime date) {
    return "${date.month}/${date.day}/${date.year}";
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 900;
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: isWide
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
    );
  }
}

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
      margin: const EdgeInsets.all(24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "My Appointments",
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              "View, cancel, or reschedule your dialysis appointments.",
              style: TextStyle(color: Colors.black54),
            ),
            const Divider(height: 30),
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

class _AppointmentList extends StatelessWidget {
  final String userId;
  final bool Function(DateTime) canCancel;
  final Function(String, String?, DateTime, String) cancelAppointment;
  final Function(String, String?, DateTime, String) deleteAppointment;

  const _AppointmentList({
    required this.userId,
    required this.canCancel,
    required this.cancelAppointment,
    required this.deleteAppointment,
  });

  void _reschedule(BuildContext context, String appointmentId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Reschedule Appointment"),
        content: const Text(
          "Your current appointment will be marked as 'rescheduled'. You will be redirected to the booking page to pick a new date and time.",
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("Cancel")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue, foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.pop(ctx);
              await FirebaseFirestore.instance
                  .collection('appointments')
                  .doc(appointmentId)
                  .update({
                'status': 'rescheduled',
                'rescheduledAt': FieldValue.serverTimestamp(),
              });
              if (context.mounted) {
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => BookPage(userId: userId)));
              }
            },
            child: const Text("Proceed"),
          ),
        ],
      ),
    );
  }

  String _formatTime(String timeSlot) {
    // Accepts either "06:00 - 10:00" or "6:00 AM - 10:00 AM" and normalizes
    if (timeSlot.contains("AM") || timeSlot.contains("PM")) {
      return timeSlot; // Already formatted
    }
    try {
      final parts = timeSlot.split(' - ');
      return "${_toAMPM(parts[0])} - ${_toAMPM(parts[1])}";
    } catch (_) {
      return timeSlot;
    }
  }

  String _toAMPM(String time24) {
    final hour = int.parse(time24.split(':')[0]);
    final minute = time24.split(':')[1];
    final isPM = hour >= 12;
    final displayHour = hour == 0
        ? 12
        : (hour > 12 ? hour - 12 : hour);
    return "$displayHour:$minute ${isPM ? "PM" : "AM"}";
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
        return Colors.green;
      case 'cancelled':
        return Colors.grey;
      case 'rejected':
        return Colors.red;
      case 'completed':
        return Colors.blue;
      case 'rescheduled':
        return Colors.purple;
      default:
        return Colors.orange; // pending
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('appointments')
          .where('patientId', isEqualTo: userId)
          .orderBy('date')
          .snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(color: Colors.green));
        }
        if (!snap.hasData || snap.data!.docs.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(40.0),
            child: Center(child: Text("No appointments yet.")),
          );
        }

        final appointments = snap.data!.docs;
        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: appointments.length,
          itemBuilder: (context, index) {
            final doc = appointments[index];
            final data = doc.data()! as Map<String, dynamic>;
            final appointmentId = doc.id;
            final date = (data['date'] as Timestamp).toDate();
            final slot = _formatTime(data['slot'] ?? "N/A");
            final status = data['status'] ?? "pending";
            final nurseId = data['nurseId'] as String?;
            final statusColor = _statusColor(status);

            return Card(
              margin: const EdgeInsets.symmetric(vertical: 8),
              elevation: 5,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              child: ListTile(
                leading: Icon(Icons.schedule, color: statusColor, size: 30),
                title: Text(
                  "Date: ${date.month}/${date.day}/${date.year}",
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text("Time Slot: $slot\nStatus: ${status.toUpperCase()}"),
                trailing: Wrap(
                  spacing: 4,
                  children: [
                    if (status == 'pending' || status == 'approved')
                      IconButton(
                        tooltip: "Reschedule",
                        icon: const Icon(Icons.refresh, color: Colors.blue),
                        onPressed: () => _reschedule(context, appointmentId),
                      ),
                    if (status == 'pending' || status == 'approved')
                      IconButton(
                        tooltip: "Cancel",
                        icon:
                        const Icon(Icons.cancel_schedule_send, color: Colors.red),
                        onPressed: () async {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text("Cancel Appointment"),
                              content: const Text(
                                  "Are you sure you want to cancel this appointment?"),
                              actions: [
                                TextButton(
                                    onPressed: () => Navigator.pop(ctx, false),
                                    child: const Text("No")),
                                ElevatedButton(
                                  onPressed: () => Navigator.pop(ctx, true),
                                  style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.red),
                                  child: const Text("Yes, Cancel"),
                                ),
                              ],
                            ),
                          );
                          if (confirm == true) {
                            await cancelAppointment(
                                appointmentId, nurseId, date, slot);
                          }
                        },
                      ),
                    if (status == 'cancelled' ||
                        status == 'rejected' ||
                        status == 'rescheduled')
                      IconButton(
                        tooltip: "Delete Record",
                        icon: const Icon(Icons.delete_forever,
                            color: Colors.grey),
                        onPressed: () async {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text("Delete Appointment"),
                              content: const Text(
                                  "Delete this record permanently?"),
                              actions: [
                                TextButton(
                                    onPressed: () => Navigator.pop(ctx, false),
                                    child: const Text("No")),
                                ElevatedButton(
                                  onPressed: () => Navigator.pop(ctx, true),
                                  style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.red),
                                  child: const Text("Yes, Delete"),
                                ),
                              ],
                            ),
                          );
                          if (confirm == true) {
                            await deleteAppointment(
                                appointmentId, nurseId, date, slot);
                          }
                        },
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
}
