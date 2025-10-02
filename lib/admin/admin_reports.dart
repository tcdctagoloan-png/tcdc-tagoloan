import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminReports extends StatelessWidget {
  AdminReports({super.key});

  final CollectionReference appointmentsRef =
  FirebaseFirestore.instance.collection('appointments');

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: appointmentsRef.snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

        final appointments = snapshot.data!.docs;

        final totalAppointments = appointments.length;
        final pending = appointments.where((a) => a['status'] == 'pending').length;
        final completed = appointments.where((a) => a['status'] == 'completed').length;
        final cancelled = appointments.where((a) => a['status'] == 'cancelled').length;

        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Total Appointments: $totalAppointments", style: const TextStyle(fontSize: 18)),
              Text("Pending: $pending", style: const TextStyle(fontSize: 18, color: Colors.orange)),
              Text("Completed: $completed", style: const TextStyle(fontSize: 18, color: Colors.green)),
              Text("Cancelled: $cancelled", style: const TextStyle(fontSize: 18, color: Colors.red)),
            ],
          ),
        );
      },
    );
  }
}
