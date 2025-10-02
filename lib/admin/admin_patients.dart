import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminPatients extends StatelessWidget {
  final String userId;
  AdminPatients({Key? key, required this.userId});

  final CollectionReference usersRef =
  FirebaseFirestore.instance.collection('users');

  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _contactController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();

  Future<void> _addWalkInPatient(BuildContext context) async {
    if (_fullNameController.text.isEmpty ||
        _usernameController.text.isEmpty ||
        _emailController.text.isEmpty ||
        _contactController.text.isEmpty ||
        _addressController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please fill all fields")),
      );
      return;
    }

    await usersRef.add({
      'fullName': _fullNameController.text.trim(),
      'username': _usernameController.text.trim(),
      'email': _emailController.text.trim(),
      'contactNumber': _contactController.text.trim(),
      'address': _addressController.text.trim(),
      'role': 'patient',
      'verified': true, // Walk-ins are approved by admin
      'profileImage': '',
      'createdAt': FieldValue.serverTimestamp(),
    });

    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text("Walk-in Patient Added")));

    _clearControllers();
    Navigator.pop(context);
  }

  void _clearControllers() {
    _fullNameController.clear();
    _usernameController.clear();
    _emailController.clear();
    _contactController.clear();
    _addressController.clear();
  }

  void _showAddPatientDialog(BuildContext context) {
    _clearControllers();
    showDialog(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: const Text("Add Walk-in Patient"),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: _fullNameController,
                  decoration: const InputDecoration(labelText: "Full Name"),
                ),
                TextField(
                  controller: _usernameController,
                  decoration: const InputDecoration(labelText: "Username"),
                ),
                TextField(
                  controller: _emailController,
                  decoration: const InputDecoration(labelText: "Email"),
                ),
                TextField(
                  controller: _contactController,
                  decoration:
                  const InputDecoration(labelText: "Contact Number"),
                  keyboardType: TextInputType.phone,
                ),
                TextField(
                  controller: _addressController,
                  decoration: const InputDecoration(labelText: "Address"),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Cancel")),
            ElevatedButton(
                onPressed: () => _addWalkInPatient(context),
                child: const Text("Add")),
          ],
        );
      },
    );
  }

  /// Edit existing patient info
  void _showEditPatientDialog(
      BuildContext context, String patientId, Map<String, dynamic> patient) {
    _fullNameController.text = patient['fullName'] ?? '';
    _usernameController.text = patient['username'] ?? '';
    _emailController.text = patient['email'] ?? '';
    _contactController.text = patient['contactNumber'] ?? '';
    _addressController.text = patient['address'] ?? '';

    showDialog(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: const Text("Edit Patient Info"),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: _fullNameController,
                  decoration: const InputDecoration(labelText: "Full Name"),
                ),
                TextField(
                  controller: _usernameController,
                  decoration: const InputDecoration(labelText: "Username"),
                ),
                TextField(
                  controller: _emailController,
                  decoration: const InputDecoration(labelText: "Email"),
                ),
                TextField(
                  controller: _contactController,
                  decoration:
                  const InputDecoration(labelText: "Contact Number"),
                  keyboardType: TextInputType.phone,
                ),
                TextField(
                  controller: _addressController,
                  decoration: const InputDecoration(labelText: "Address"),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Cancel")),
            ElevatedButton(
              onPressed: () async {
                await usersRef.doc(patientId).update({
                  'fullName': _fullNameController.text.trim(),
                  'username': _usernameController.text.trim(),
                  'email': _emailController.text.trim(),
                  'contactNumber': _contactController.text.trim(),
                  'address': _addressController.text.trim(),
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Patient Info Updated")),
                );
                _clearControllers();
                Navigator.pop(context);
              },
              child: const Text("Save"),
            ),
          ],
        );
      },
    );
  }

  /// Delete patient
  Future<void> _deletePatient(BuildContext context, String patientId) async {
    try {
      await usersRef.doc(patientId).delete();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Patient removed successfully")),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to delete: $e")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.person_add),
        onPressed: () => _showAddPatientDialog(context),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: usersRef.where('role', isEqualTo: 'patient').snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final patients = snapshot.data!.docs;
          return ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: patients.length,
            itemBuilder: (context, index) {
              final patient = patients[index];
              final verified = patient['verified'] ?? false;
              final fullName = patient['fullName'] ?? '';
              final username = patient['username'] ?? '';
              final displayName = (fullName.isNotEmpty && username.isNotEmpty)
                  ? "$fullName ($username)"
                  : fullName.isNotEmpty
                  ? fullName
                  : username;

              return Card(
                margin: const EdgeInsets.symmetric(vertical: 8),
                child: ListTile(
                  leading: const Icon(Icons.person, color: Colors.blue),
                  title: Text(displayName),
                  subtitle: Text(verified ? "Verified" : "Unverified"),
                  onTap: () => _showEditPatientDialog(
                      context, patient.id, patient.data() as Map<String, dynamic>),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (!verified)
                        ElevatedButton(
                          child: const Text("Approve"),
                          onPressed: () async {
                            await usersRef
                                .doc(patient.id)
                                .update({'verified': true});
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text("Patient Approved")),
                            );
                          },
                        ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _deletePatient(context, patient.id),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
