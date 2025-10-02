// admin_beds.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class AdminBedsPage extends StatelessWidget {
  AdminBedsPage({Key? key}) : super(key: key);

  final CollectionReference bedsRef =
  FirebaseFirestore.instance.collection('beds');

  void _showMessage(BuildContext context, String message, {bool isError = false}) {
    // Determine if the screen is wide (web) or not (mobile)
    bool isWideScreen = MediaQuery.of(context).size.width >= 900;

    if (isWideScreen) {
      // For web, use a web-friendly alert or a modal dialog
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
      // For mobile, use a SnackBar
      final snackBar = SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
      );
      ScaffoldMessenger.of(context).showSnackBar(snackBar);
    }
  }

  // Add Bed Dialog
  Future<void> _showAddBedDialog(BuildContext context) async {
    final formKey = GlobalKey<FormState>();
    String name = '';
    bool isWorking = true;

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Add Bed"),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                decoration:
                const InputDecoration(labelText: "Bed Name (e.g., Bed 1)"),
                onChanged: (v) => name = v,
                validator: (v) =>
                v == null || v.isEmpty ? "Enter bed name" : null,
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("Working"),
                  StatefulBuilder(
                    builder: (context, setState) => Switch(
                      value: isWorking,
                      onChanged: (v) => setState(() => isWorking = v),
                    ),
                  ),
                ],
              )
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              try {
                await bedsRef.add({
                  'name': name,
                  'isWorking': isWorking,
                  'assignedPatients': [], // Changed from assignedPatient
                  'createdAt': FieldValue.serverTimestamp(),
                });
                Navigator.pop(ctx);
                _showMessage(context, "New bed added successfully");
              } catch (e) {
                _showMessage(context, "Failed to add bed: $e", isError: true);
              }
            },
            child: const Text("Add"),
          ),
        ],
      ),
    );
  }

  // Edit Bed Dialog with availability toggle
  Future<void> _showEditBedDialog(
      BuildContext context, String docId, Map<String, dynamic> bedData) async {
    final formKey = GlobalKey<FormState>();
    String name = bedData['name'] ?? '';
    bool isWorking = bedData['isWorking'] ?? true;

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Edit Bed"),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                initialValue: name,
                decoration: const InputDecoration(labelText: "Bed Name"),
                onChanged: (v) => name = v,
                validator: (v) =>
                v == null || v.isEmpty ? "Enter bed name" : null,
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("Status"),
                  StatefulBuilder(
                    builder: (context, setState) => Switch(
                      value: isWorking,
                      onChanged: (v) => setState(() => isWorking = v),
                    ),
                  ),
                ],
              )
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              final statusText = isWorking ? "Working" : "Not Working";

              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text("Confirm Update"),
                  content: Text(
                      "Are you sure you want to mark this bed as $statusText?"),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text("Cancel")),
                    ElevatedButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text("Yes")),
                  ],
                ),
              );

              if (confirm != true) return;

              try {
                await bedsRef.doc(docId).update({
                  'name': name,
                  'isWorking': isWorking,
                });

                // Notify nurses
                await FirebaseFirestore.instance
                    .collection('notifications')
                    .add({
                  'nurseId': 'all',
                  'title': "Bed Status Changed",
                  'message': "Bed '$name' is now ${statusText.toLowerCase()}.",
                  'createdAt': FieldValue.serverTimestamp(),
                  'isRead': false,
                });

                Navigator.pop(ctx);
                _showMessage(context, "Bed marked as $statusText");
              } catch (e) {
                _showMessage(context, "Failed to update bed: $e", isError: true);
              }
            },
            child: const Text("Update"),
          ),
        ],
      ),
    );
  }

  // Delete Bed Confirmation
  Future<void> _confirmDelete(BuildContext context, String docId) async {
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete Bed"),
        content: const Text("Are you sure you want to delete this bed?"),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () async {
              try {
                await bedsRef.doc(docId).delete();
                Navigator.pop(ctx);
                _showMessage(context, "Bed deleted successfully");
              } catch (e) {
                _showMessage(context, "Failed to delete bed: $e", isError: true);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text("Delete"),
          ),
        ],
      ),
    );
  }

  int _extractBedNumber(String name) {
    final regex = RegExp(r'(\d+)$');
    final match = regex.firstMatch(name);
    if (match != null) {
      return int.tryParse(match.group(1)!) ?? 0;
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    bool isWideScreen = MediaQuery.of(context).size.width >= 900;
    return Scaffold(
      floatingActionButton: isWideScreen ? null : FloatingActionButton(
        onPressed: () => _showAddBedDialog(context),
        tooltip: "Add Bed",
        child: const Icon(Icons.add),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isWideScreen)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "Bed Management",
                    style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87),
                  ),
                  ElevatedButton.icon(
                    onPressed: () => _showAddBedDialog(context),
                    icon: const Icon(Icons.add, color: Colors.white),
                    label: const Text("Add Bed",
                        style: TextStyle(color: Colors.white)),
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
              const Text(
                "Bed Management",
                style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87),
              ),
            const SizedBox(height: 24),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: bedsRef.snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final beds = snapshot.data!.docs;

                  beds.sort((a, b) {
                    final aData = a.data() as Map<String, dynamic>? ?? {};
                    final bData = b.data() as Map<String, dynamic>? ?? {};
                    final aIsWorking = aData['isWorking'] ?? true;
                    final bIsWorking = bData['isWorking'] ?? true;

                    // Sort working beds first
                    if (aIsWorking != bIsWorking) {
                      return aIsWorking ? -1 : 1;
                    }

                    // Then sort by bed number
                    final aNum = _extractBedNumber(aData['name'] ?? "");
                    final bNum = _extractBedNumber(bData['name'] ?? "");
                    return aNum.compareTo(bNum);
                  });

                  return GridView.builder(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: isWideScreen ? 3 : 1,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      childAspectRatio: isWideScreen ? 1.8 : 4.5,
                    ),
                    itemCount: beds.length,
                    itemBuilder: (context, index) {
                      final doc = beds[index];
                      final bedData = doc.data() as Map<String, dynamic>? ?? {};
                      final name = bedData['name'] ?? 'Unknown Bed';
                      final isWorking = bedData['isWorking'] ?? true;
                      final assignedPatients = bedData['assignedPatients'] as List? ?? [];
                      final isOccupied = assignedPatients.isNotEmpty;


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
                              Row(
                                children: [
                                  Icon(
                                    isWorking ? Icons.check_circle : Icons.error,
                                    color: isWorking ? Colors.green : Colors.red,
                                    size: 24,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      name,
                                      style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.edit, color: Colors.blue),
                                    onPressed: () => _showEditBedDialog(context, doc.id, bedData),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete, color: Colors.red),
                                    onPressed: () => _confirmDelete(context, doc.id),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Text(
                                    isWorking ? "Status: Working" : "Status: Not Working",
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: isWorking ? Colors.black54 : Colors.red,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Text(
                                    isOccupied ? "Occupied" : "Available",
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: isOccupied ? Colors.orange : Colors.green,
                                    ),
                                  ),
                                  if (isOccupied) ...[
                                    const SizedBox(width: 4),
                                    Text(
                                      '(${assignedPatients.length}/4 Patients)',
                                      style: const TextStyle(
                                        fontSize: 14,
                                        color: Colors.black54,
                                      ),
                                    ),
                                  ],
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