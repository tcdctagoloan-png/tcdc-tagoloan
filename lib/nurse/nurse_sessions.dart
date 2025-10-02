import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class NurseSessions extends StatelessWidget {
  final String nurseId;
  const NurseSessions({super.key, required this.nurseId});

  @override
  Widget build(BuildContext context) {
    final CollectionReference appointmentsRef =
    FirebaseFirestore.instance.collection('appointments');

    return StreamBuilder<QuerySnapshot>(
      stream: appointmentsRef
          .where('assignedNurse', isEqualTo: nurseId)
          .where('status', isEqualTo: 'in-progress')
          .orderBy('sessionStart')
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

        final sessions = snapshot.data!.docs;

        return ListView.builder(
          padding: const EdgeInsets.all(20),
          itemCount: sessions.length,
          itemBuilder: (context, index) {
            final session = sessions[index];
            return Card(
              margin: const EdgeInsets.symmetric(vertical: 8),
              child: ListTile(
                leading: const Icon(Icons.medical_services, color: Colors.green),
                title: Text("Patient: ${session['patientId']}"),
                subtitle: Text("Bed: ${session['bedNumber']}"),
                trailing: ElevatedButton(
                  child: const Text("Complete"),
                  onPressed: () async {
                    await appointmentsRef
                        .doc(session.id)
                        .update({'status': 'completed'});
                    ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Session Completed")));
                  },
                ),
              ),
            );
          },
        );
      },
    );
  }
}
