import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class NurseManagementPage extends StatefulWidget {
  const NurseManagementPage({Key? key}) : super(key: key);

  @override
  _NurseManagementPageState createState() => _NurseManagementPageState();
}

class _NurseManagementPageState extends State<NurseManagementPage> {
  final CollectionReference usersRef = FirebaseFirestore.instance.collection('users');
  final FirebaseAuth _auth = FirebaseAuth.instance;

  final TextEditingController searchController = TextEditingController();
  final TextEditingController fullNameController = TextEditingController();
  final TextEditingController usernameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController contactController = TextEditingController();
  final TextEditingController addressController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  String searchQuery = '';

  @override
  void dispose() {
    searchController.dispose();
    fullNameController.dispose();
    usernameController.dispose();
    emailController.dispose();
    contactController.dispose();
    addressController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  void clearControllers() {
    fullNameController.clear();
    usernameController.clear();
    emailController.clear();
    contactController.clear();
    addressController.clear();
    passwordController.clear();
  }

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

  void showNurseDialog({DocumentSnapshot? nurse}) {
    final bool isEditing = nurse != null;
    if (isEditing) {
      final d = nurse.data() as Map<String, dynamic>;
      fullNameController.text = d['fullName'] ?? '';
      usernameController.text = d['username'] ?? '';
      emailController.text = d['email'] ?? '';
      contactController.text = d['contactNumber'] ?? '';
      addressController.text = d['address'] ?? '';
    } else {
      clearControllers();
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isEditing ? 'Edit Nurse' : 'Add Nurse', style: const TextStyle(fontWeight: FontWeight.bold)),
        content: SizedBox(
          width: MediaQuery.of(context).size.width * 0.4,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: fullNameController,
                  decoration: InputDecoration(labelText: 'Full Name*', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: usernameController,
                  decoration: InputDecoration(labelText: 'Username', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: emailController,
                  decoration: InputDecoration(labelText: 'Email*', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: contactController,
                  decoration: InputDecoration(labelText: 'Contact Number', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: addressController,
                  decoration: InputDecoration(labelText: 'Address', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                ),
                if (!isEditing) ...[
                  const SizedBox(height: 16),
                  TextField(
                    controller: passwordController,
                    decoration: InputDecoration(labelText: 'Password*', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                    obscureText: true,
                  ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              clearControllers();
              Navigator.pop(ctx);
            },
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (fullNameController.text.isEmpty || emailController.text.isEmpty || (!isEditing && passwordController.text.isEmpty)) {
                _showMessage("Full name, email, and password are required.", isError: true);
                return;
              }

              try {
                if (!isEditing) {
                  // Add Nurse
                  UserCredential userCred = await _auth.createUserWithEmailAndPassword(
                    email: emailController.text,
                    password: passwordController.text,
                  );

                  String uid = userCred.user!.uid;

                  await usersRef.doc(uid).set({
                    'fullName': fullNameController.text,
                    'username': usernameController.text,
                    'email': emailController.text,
                    'role': 'nurse',
                    'contactNumber': contactController.text,
                    'address': addressController.text,
                    'createdAt': FieldValue.serverTimestamp(),
                  });
                } else {
                  // Edit Nurse
                  await usersRef.doc(nurse.id).update({
                    'fullName': fullNameController.text,
                    'username': usernameController.text,
                    'email': emailController.text,
                    'contactNumber': contactController.text,
                    'address': addressController.text,
                  });
                }

                clearControllers();
                if (!mounted) return;
                Navigator.pop(ctx);
                _showMessage(isEditing ? 'Nurse updated successfully' : 'Nurse added successfully');
              } on FirebaseAuthException catch (e) {
                _showMessage("Authentication Error: ${e.message}", isError: true);
              } catch (e) {
                _showMessage("Error: $e", isError: true);
              }
            },
            child: Text(isEditing ? 'Update' : 'Add'),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(String docId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Confirm Deletion"),
        content: const Text("Are you sure you want to delete this nurse?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await usersRef.doc(docId).delete();
                if (!mounted) return;
                Navigator.of(ctx).pop();
                _showMessage("Nurse deleted successfully");
              } catch (e) {
                _showMessage("Failed to delete nurse: $e", isError: true);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text("Delete"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    bool isWideScreen = MediaQuery.of(context).size.width >= 900;

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isWideScreen) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Nurse Management",
                  style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87),
                ),
                ElevatedButton.icon(
                  onPressed: () => showNurseDialog(),
                  icon: const Icon(Icons.add, color: Colors.white),
                  label: const Text("Add Nurse", style: TextStyle(color: Colors.white)),
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
          ] else ...[
            const Text(
              "Nurse Management",
              style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87),
            ),
            const SizedBox(height: 16),
          ],
          TextField(
            controller: searchController,
            decoration: InputDecoration(
              hintText: 'Search nurses...',
              prefixIcon: const Icon(Icons.search, color: Colors.grey),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor: Colors.grey.shade100,
            ),
            onChanged: (val) => setState(() => searchQuery = val.toLowerCase()),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: usersRef.where('role', isEqualTo: 'nurse').snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final docs = snapshot.data!.docs.where((d) {
                  final data = d.data() as Map<String, dynamic>;
                  final name = (data['fullName'] ?? '').toString().toLowerCase();
                  final email = (data['email'] ?? '').toString().toLowerCase();
                  return name.contains(searchQuery) || email.contains(searchQuery);
                }).toList();

                if (docs.isEmpty) {
                  return const Center(child: Text('No nurses found.'));
                }

                return SingleChildScrollView(
                  child: Column(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.grey.withOpacity(0.1),
                              spreadRadius: 1,
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Table(
                          defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                          columnWidths: const {
                            0: FlexColumnWidth(1.5),
                            1: FlexColumnWidth(2),
                            2: FlexColumnWidth(1),
                          },
                          children: [
                            const TableRow(
                              decoration: BoxDecoration(
                                border: Border(bottom: BorderSide(color: Colors.grey, width: 0.2)),
                              ),
                              children: [
                                Padding(
                                  padding: EdgeInsets.all(16.0),
                                  child: Text('Name', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)),
                                ),
                                Padding(
                                  padding: EdgeInsets.all(16.0),
                                  child: Text('Email', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)),
                                ),
                                Padding(
                                  padding: EdgeInsets.all(16.0),
                                  child: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)),
                                ),
                              ],
                            ),
                            ...docs.map((doc) {
                              final data = doc.data() as Map<String, dynamic>;
                              return TableRow(
                                decoration: BoxDecoration(
                                  border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
                                ),
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.all(16.0),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.person, color: Colors.green),
                                        const SizedBox(width: 8),
                                        Text(data['fullName'] ?? ''),
                                      ],
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.all(16.0),
                                    child: Text(data['email'] ?? ''),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.all(16.0),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                            icon: const Icon(Icons.edit, color: Colors.blue),
                                            onPressed: () => showNurseDialog(nurse: doc)),
                                        IconButton(
                                            icon: const Icon(Icons.delete, color: Colors.red),
                                            onPressed: () => _confirmDelete(doc.id)),
                                      ],
                                    ),
                                  ),
                                ],
                              );
                            }).toList(),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          if (!isWideScreen)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16.0),
              child: ElevatedButton.icon(
                onPressed: () => showNurseDialog(),
                icon: const Icon(Icons.add),
                label: const Text('Add Nurse'),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(50),
                ),
              ),
            ),
        ],
      ),
    );
  }
}