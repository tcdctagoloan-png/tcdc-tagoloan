import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class PatientAppointmentsPage extends StatelessWidget {
  final String userId;
  const PatientAppointmentsPage({super.key, required this.userId});

  Future<void> _cancelAppointment(String appointmentId, String nurseId, DateTime date, String slot) async {
    await FirebaseFirestore.instance
        .collection('appointments')
        .doc(appointmentId)
        .update({'status': 'cancelled'});

    await FirebaseFirestore.instance.collection('notifications').add({
      'nurseId': nurseId,
      'title': "Appointment Cancelled",
      'message': "Patient has cancelled their appointment on ${date.year}-${date.month}-${date.day} at $slot.",
      'appointmentId': appointmentId,
      'read': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _deleteAppointment(String appointmentId, String nurseId, DateTime date, String slot) async {
    await FirebaseFirestore.instance
        .collection('appointments')
        .doc(appointmentId)
        .delete();

    await FirebaseFirestore.instance.collection('notifications').add({
      'nurseId': nurseId,
      'title': "Appointment Deleted",
      'message': "Patient has deleted their appointment record on ${date.year}-${date.month}-${date.day} at $slot.",
      'appointmentId': appointmentId,
      'read': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  bool _canCancel(DateTime appointmentDate) {
    final now = DateTime.now();
    return appointmentDate.isAfter(now.subtract(const Duration(days: 1)));
  }

  @override
  Widget build(BuildContext context) {
    final isWideScreen = MediaQuery.of(context).size.width >= 900;

    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: Column(
        children: [
          if (isWideScreen)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              color: Colors.green.shade100,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: const [
                      Icon(Icons.local_hospital_outlined, size: 28, color: Colors.green),
                      SizedBox(width: 8),
                      Text(
                        "Clinic Appointment System",
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black),
                      ),
                    ],
                  ),
                  Row(
                    children: const [
                      _NavItem(label: "Home"),
                      _NavItem(label: "Appointments"),
                      _NavItem(label: "Profile"),
                      _NavItem(label: "About"),
                    ],
                  )
                ],
              ),
            ),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: isWideScreen
                  ? Card(
                elevation: 8,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: SizedBox(
                  width: 900,
                  child: Row(
                    children: [
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.all(32.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: const [
                              Text(
                                "My Appointments",
                                style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.black),
                              ),
                              SizedBox(height: 16),
                              Text(
                                "Manage your bookings and appointment records easily.",
                                style: TextStyle(fontSize: 18, color: Colors.black87),
                              ),
                              SizedBox(height: 24),
                            ],
                          ),
                        ),
                      ),
                      Container(width: 1, color: Colors.grey.shade300),
                      Expanded(
                        child: _AppointmentList(userId: userId, canCancel: _canCancel, cancelAppointment: _cancelAppointment, deleteAppointment: _deleteAppointment),
                      ),
                    ],
                  ),
                ),
              )
                  : _AppointmentList(userId: userId, canCancel: _canCancel, cancelAppointment: _cancelAppointment, deleteAppointment: _deleteAppointment),
            ),
          ),
        ],
      ),
    );
  }
}

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
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('appointments')
          .where('patientId', isEqualTo: userId)
          .orderBy('date', descending: false)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text("No appointments found"));
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
            final slot = data['slot'] ?? "No slot";
            final status = data['status'] ?? "pending";
            final nurseId = data['nurseId'] as String?;

            final canCancelAppointment = canCancel(date) && status != "cancelled" && status != "rejected";

            return Card(
              margin: const EdgeInsets.symmetric(vertical: 8),
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: ListTile(
                leading: const Icon(Icons.local_hospital, color: Colors.green),
                title: FutureBuilder<DocumentSnapshot<Object?>?>(
                  future: (nurseId != null)
                      ? FirebaseFirestore.instance.collection('users').doc(nurseId).get()
                      : Future.value(null),
                  builder: (context, nurseSnap) {
                    String nurseName = "Unknown Nurse";
                    if (nurseSnap.connectionState == ConnectionState.waiting) {
                      nurseName = "Loading...";
                    } else if (nurseSnap.hasData && nurseSnap.data != null && nurseSnap.data!.exists) {
                      nurseName = nurseSnap.data!.get('fullName') ?? "Unknown Nurse";
                    }
                    return Text("Nurse: $nurseName");
                  },
                ),
                subtitle: Text("Date: ${date.year}-${date.month}-${date.day}\nSlot: $slot"),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(status, style: TextStyle(fontWeight: FontWeight.bold, color: status == "approved" ? Colors.green : (status == "rejected" ? Colors.red : Colors.orange))),
                    const SizedBox(width: 8),
                    if (canCancelAppointment)
                      IconButton(
                        icon: const Icon(Icons.cancel, color: Colors.red),
                        onPressed: () async {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text("Cancel Appointment"),
                              content: const Text("Are you sure you want to cancel this appointment?"),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("No")),
                                ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("Yes")),
                              ],
                            ),
                          );
                          if (confirm == true && nurseId != null) {
                            await cancelAppointment(appointmentId, nurseId, date, slot);
                          }
                        },
                      ),
                    if (status == "cancelled" || date.isBefore(DateTime.now()))
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.grey),
                        onPressed: () async {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text("Delete Appointment"),
                              content: const Text("Are you sure you want to delete this appointment? This action cannot be undone."),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("No")),
                                ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("Yes")),
                              ],
                            ),
                          );
                          if (confirm == true && nurseId != null) {
                            await deleteAppointment(appointmentId, nurseId, date, slot);
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

class _NavItem extends StatelessWidget {
  final String label;
  const _NavItem({required this.label});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {},
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Colors.black)),
      ),
    );
  }
}
