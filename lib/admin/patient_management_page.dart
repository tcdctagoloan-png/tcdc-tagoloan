import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PatientManagementPage extends StatefulWidget {
  const PatientManagementPage({Key? key}) : super(key: key);

  @override
  _PatientManagementPageState createState() => _PatientManagementPageState();
}

class _PatientManagementPageState extends State<PatientManagementPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String searchQuery = "";

  // Unified messaging function for web and mobile
  void _showMessage(String message, {bool isError = false}) {
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

  Future<void> _approvePatient(String docId, String fullName) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Approve Patient"),
        content: Text("Are you sure you want to approve $fullName?"),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("Cancel")),
          ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text("Confirm")),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await _firestore.collection('users').doc(docId).update({'verified': true});

      // Notify the patient
      await _firestore.collection('notifications').add({
        'title': "Account Verified",
        'message': "Your account has been verified by an admin. You may now book appointments.",
        'userId': docId,
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
        'type': 'patient', // New type field for filtering
      });

      // Notify nurses
      await _firestore.collection('notifications').add({
        'role': 'nurse',
        'title': "New Patient Verified",
        'message': "Patient $fullName has been verified by an admin.",
        'createdAt': FieldValue.serverTimestamp(),
        'isRead': false, // Add isRead for nurse notifications
        'type': 'patient',
      });

      if (!mounted) return;
      _showMessage("Patient $fullName approved successfully");
    } catch (e) {
      _showMessage("Failed to approve patient: $e", isError: true);
    }
  }

  Future<void> _toggleActive(
      String docId, bool currentStatus, String fullName) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(currentStatus ? "Hide Patient?" : "Unhide Patient?"),
        content: Text(
          currentStatus
              ? "Are you sure you want to hide $fullName? They will still be searchable."
              : "Are you sure you want to unhide $fullName?",
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("Cancel")),
          ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: currentStatus ? Colors.red : Colors.green,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text("Confirm")),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await _firestore
          .collection('users')
          .doc(docId)
          .update({'isActive': !currentStatus});
      if (!mounted) return;
      _showMessage("Patient ${!currentStatus ? 'unhidden' : 'hidden'} successfully");
    } catch (e) {
      _showMessage("Failed to update patient status: $e", isError: true);
    }
  }

  Future<void> _addWalkInPatient() async {
    final formKey = GlobalKey<FormState>();

    String fullName = '';
    String username = '';
    String email = '';
    String password = '';
    String contactNumber = '';
    String address = '';

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Add Walk-in Patient"),
        content: Form(
          key: formKey,
          child: SizedBox(
            width: MediaQuery.of(context).size.width * 0.4,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    decoration: const InputDecoration(labelText: "Full Name*", border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12)))),
                    onChanged: (v) => fullName = v,
                    validator: (v) =>
                    v == null || v.isEmpty ? "Enter full name" : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    decoration: const InputDecoration(labelText: "Username*", border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12)))),
                    onChanged: (v) => username = v,
                    validator: (v) =>
                    v == null || v.isEmpty ? "Enter username" : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    decoration: const InputDecoration(labelText: "Email*", border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12)))),
                    onChanged: (v) => email = v,
                    validator: (v) =>
                    v == null || v.isEmpty ? "Enter email" : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    decoration: const InputDecoration(labelText: "Password*", border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12)))),
                    obscureText: true,
                    onChanged: (v) => password = v,
                    validator: (v) => v == null || v.length < 6
                        ? "Password must be 6+ chars"
                        : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    decoration: const InputDecoration(labelText: "Contact Number", border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12)))),
                    onChanged: (v) => contactNumber = v,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    decoration: const InputDecoration(labelText: "Address", border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12)))),
                    onChanged: (v) => address = v,
                  ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;

              try {
                UserCredential userCred =
                await _auth.createUserWithEmailAndPassword(
                  email: email,
                  password: password,
                );

                String uid = userCred.user!.uid;

                await _firestore.collection('users').doc(uid).set({
                  'fullName': fullName,
                  'username': username,
                  'email': email,
                  'role': 'patient',
                  'contactNumber': contactNumber,
                  'address': address,
                  'verified': true,
                  'isActive': true,
                  'createdAt': FieldValue.serverTimestamp(),
                });

                // Notify nurses about the new patient
                await _firestore.collection('notifications').add({
                  'role': 'nurse',
                  'title': "New Patient Added",
                  'message': "Patient $fullName has been added by an admin.",
                  'createdAt': FieldValue.serverTimestamp(),
                  'isRead': false,
                  'type': 'patient',
                });

                if (!mounted) return;
                Navigator.pop(context);
                _showMessage("Patient $fullName added successfully");
              } on FirebaseAuthException catch (e) {
                _showMessage("Authentication Error: ${e.message}", isError: true);
              } catch (e) {
                _showMessage("Error: $e", isError: true);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text("Add"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    bool isWideScreen = MediaQuery.of(context).size.width >= 900;
    return Scaffold(
      floatingActionButton: isWideScreen ? null : FloatingActionButton(
        onPressed: _addWalkInPatient,
        tooltip: "Add Walk-in Patient",
        child: const Icon(Icons.add),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isWideScreen) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "Patient List",
                    style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87),
                  ),
                  ElevatedButton.icon(
                    onPressed: _addWalkInPatient,
                    icon: const Icon(Icons.add, color: Colors.white),
                    label: const Text("Add Patient",
                        style: TextStyle(color: Colors.white)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: TextField(
                  decoration: const InputDecoration(
                    hintText: "Search patient...",
                    prefixIcon: Icon(Icons.search, color: Colors.grey),
                    border: InputBorder.none,
                    isDense: true,
                  ),
                  onChanged: (value) {
                    setState(() {
                      searchQuery = value.toLowerCase();
                    });
                  },
                ),
              ),
              const SizedBox(height: 24),
            ] else ...[
              const Text(
                "Patient List",
                style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87),
              ),
              const SizedBox(height: 16),
              TextField(
                decoration: InputDecoration(
                  hintText: "Search patient...",
                  prefixIcon: const Icon(Icons.search, color: Colors.grey),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: Colors.grey.shade100,
                ),
                onChanged: (value) {
                  setState(() {
                    searchQuery = value.toLowerCase();
                  });
                },
              ),
              const SizedBox(height: 24),
            ],
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: _firestore
                    .collection('users')
                    .where('role', isEqualTo: 'patient')
                    .orderBy('createdAt', descending: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final patients = snapshot.data!.docs.where((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    final name = (data['fullName'] ?? "").toLowerCase();
                    final username = (data['username'] ?? "").toLowerCase();
                    return name.contains(searchQuery) ||
                        username.contains(searchQuery);
                  }).toList();

                  // Sort patients to show unverified and then active ones first
                  patients.sort((a, b) {
                    final aVerified = (a.data() as Map<String, dynamic>)['verified'] ?? false;
                    final bVerified = (b.data() as Map<String, dynamic>)['verified'] ?? false;
                    final aActive = (a.data() as Map<String, dynamic>)['isActive'] ?? true;
                    final bActive = (b.data() as Map<String, dynamic>)['isActive'] ?? true;

                    // Unverified patients at the top
                    if (aVerified != bVerified) {
                      return aVerified ? 1 : -1;
                    }

                    // Then sort by active status (active patients first)
                    if (aActive != bActive) {
                      return aActive ? -1 : 1;
                    }

                    return 0;
                  });

                  if (patients.isEmpty) {
                    return const Center(
                      child: Text(
                        'No patients found.',
                        style: TextStyle(color: Colors.grey, fontSize: 16),
                      ),
                    );
                  }

                  return GridView.builder(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: isWideScreen ? 3 : 1,
                      crossAxisSpacing: 16.0,
                      mainAxisSpacing: 16.0,
                      childAspectRatio: isWideScreen ? 1.8 : 4.5,
                    ),
                    itemCount: patients.length,
                    itemBuilder: (context, index) {
                      final doc = patients[index];
                      final data = doc.data() as Map<String, dynamic>;
                      final verifiedStatus = data['verified'] ?? false;
                      final isActive = data['isActive'] ?? true;

                      return Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(color: Colors.grey.shade200)),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                data['fullName'] ?? "",
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: isActive ? Colors.black87 : Colors.grey,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                "Username: ${data['username'] ?? "N/A"} | Email: ${data['email'] ?? "N/A"}",
                                style: TextStyle(
                                  fontSize: 14,
                                  color: isActive ? Colors.black54 : Colors.grey,
                                ),
                              ),
                              const Spacer(),
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: verifiedStatus
                                          ? Colors.green.withOpacity(0.1)
                                          : Colors.orange.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      verifiedStatus ? "Verified" : "Not Verified",
                                      style: TextStyle(
                                        color: verifiedStatus ? Colors.green : Colors.orange,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                  const Spacer(),
                                  if (!verifiedStatus && isActive)
                                    ElevatedButton(
                                      onPressed: () => _approvePatient(
                                          doc.id, data['fullName'] ?? "Unknown"),
                                      child: const Text("Approve"),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.green,
                                        foregroundColor: Colors.white,
                                      ),
                                    ),
                                  IconButton(
                                    icon: Icon(
                                      isActive ? Icons.visibility_off : Icons.visibility,
                                      color: isActive ? Colors.red : Colors.grey,
                                    ),
                                    onPressed: () => _toggleActive(
                                        doc.id, isActive, data['fullName'] ?? ""),
                                  ),
                                ],
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