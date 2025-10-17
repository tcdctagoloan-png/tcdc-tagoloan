// lib/nurse/nurse_patients_page.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class NursePatientsPage extends StatefulWidget {
  const NursePatientsPage({super.key, required String nurseId});

  @override
  State<NursePatientsPage> createState() => _NursePatientsPageState();
}

class _NursePatientsPageState extends State<NursePatientsPage> {
  String _searchQuery = '';
  String _filterStatus = 'All';
  bool _isWide = false;

  @override
  Widget build(BuildContext context) {
    _isWide = MediaQuery.of(context).size.width > 900;
    return Scaffold(
      appBar: AppBar(
        title: const Text("Patients List"),
        backgroundColor: Colors.blue,
        elevation: 2,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Search and filter bar
            Row(
              children: [
                Expanded(
                  flex: _isWide ? 2 : 1,
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: "Search patient name...",
                      prefixIcon: const Icon(Icons.search),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onChanged: (v) => setState(() => _searchQuery = v.trim()),
                  ),
                ),
                const SizedBox(width: 12),
                DropdownButton<String>(
                  value: _filterStatus,
                  items: const [
                    DropdownMenuItem(value: 'All', child: Text("All")),
                    DropdownMenuItem(value: 'Verified', child: Text("Verified")),
                    DropdownMenuItem(value: 'Unverified', child: Text("Unverified")),
                  ],
                  onChanged: (v) => setState(() => _filterStatus = v!),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection('users').where('role', isEqualTo: 'patient').snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return const Center(child: Text("No patients found."));
                  }

                  final allPatients = snapshot.data!.docs;
                  final filteredPatients = allPatients.where((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    final name = (data['fullName'] ?? '').toString().toLowerCase();
                    final verified = data['verified'] == true;
                    final matchesSearch = name.contains(_searchQuery.toLowerCase());
                    final matchesFilter = _filterStatus == 'All' ||
                        (_filterStatus == 'Verified' && verified) ||
                        (_filterStatus == 'Unverified' && !verified);
                    return matchesSearch && matchesFilter;
                  }).toList();

                  if (filteredPatients.isEmpty) {
                    return const Center(child: Text("No matching patients."));
                  }

                  return _isWide
                      ? _buildWideTable(filteredPatients)
                      : _buildMobileCards(filteredPatients);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWideTable(List<QueryDocumentSnapshot> patients) {
    return Expanded(
      child: SingleChildScrollView(
        scrollDirection: Axis.vertical,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingRowColor: MaterialStateProperty.all(Colors.blue[50]),
            columnSpacing: 22,
            border: TableBorder.all(color: Colors.grey[300]!),
            columns: const [
              DataColumn(label: Text("Name")),
              DataColumn(label: Text("Gender")),
              DataColumn(label: Text("Age")),
              DataColumn(label: Text("Contact")),
              DataColumn(label: Text("Address")),
              DataColumn(label: Text("Status")),
              DataColumn(label: Text("Last Appointment")),
              DataColumn(label: Text("Actions")),
            ],
            rows: patients.map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              final fullName = data['fullName'] ?? 'N/A';
              final gender = data['gender'] ?? 'N/A';
              final age = data['age']?.toString() ?? '-';
              final contact = data['contact'] ?? '-';
              final address = data['address'] ?? '-';
              final verified = data['verified'] == true;

              return DataRow(
                cells: [
                  DataCell(Text(fullName)),
                  DataCell(Text(gender)),
                  DataCell(Text(age)),
                  DataCell(Text(contact)),
                  DataCell(Text(address)),
                  DataCell(Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: verified ? Colors.green[100] : Colors.red[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      verified ? 'Verified' : 'Unverified',
                      style: TextStyle(color: verified ? Colors.green[900] : Colors.red[900]),
                    ),
                  )),
                  DataCell(FutureBuilder<String>(
                    future: _fetchLastAppointmentInfo(doc.id),
                    builder: (context, snap) {
                      if (snap.connectionState == ConnectionState.waiting) {
                        return const Text("Loading...");
                      }
                      return Text(snap.data ?? "No record");
                    },
                  )),
                  DataCell(Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.history, color: Colors.blue),
                        tooltip: "View History",
                        onPressed: () => _showHistoryDialog(doc.id, fullName),
                      ),
                      IconButton(
                        icon: const Icon(Icons.bed, color: Colors.teal),
                        tooltip: "Current Bed",
                        onPressed: () => _showBedUsageDialog(doc.id),
                      ),
                    ],
                  )),
                ],
              );
            }).toList(),
          ),
        ),
      ),
    );
  }


  Widget _buildMobileCards(List<QueryDocumentSnapshot> patients) {
    return ListView.builder(
      itemCount: patients.length,
      itemBuilder: (context, idx) {
        final data = patients[idx].data() as Map<String, dynamic>;
        final fullName = data['fullName'] ?? 'N/A';
        final gender = data['gender'] ?? 'N/A';
        final age = data['age']?.toString() ?? '-';
        final verified = data['verified'] == true;

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: 2,
          child: ListTile(
            title: Text(fullName, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text("$gender, $age years old\nStatus: ${verified ? 'Verified' : 'Unverified'}"),
            trailing: IconButton(
              icon: const Icon(Icons.more_vert),
              onPressed: () => _showHistoryDialog(patients[idx].id, fullName),
            ),
          ),
        );
      },
    );
  }

  Future<String> _fetchLastAppointmentInfo(String patientId) async {
    final snap = await FirebaseFirestore.instance
        .collection('appointments')
        .where('patientId', isEqualTo: patientId)
        .orderBy('date', descending: true)
        .limit(1)
        .get();

    if (snap.docs.isEmpty) return "No recent appointment";

    final data = snap.docs.first.data();
    final date = (data['date'] as Timestamp?)?.toDate();
    final bed = data['bedName'] ?? 'Unknown Bed';
    return "${DateFormat('MMM d, yyyy').format(date!)} ($bed)";
  }

  Future<void> _showHistoryDialog(String patientId, String patientName) async {
    final snap = await FirebaseFirestore.instance
        .collection('appointments')
        .where('patientId', isEqualTo: patientId)
        .orderBy('date', descending: true)
        .get();

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text("Appointment History - $patientName"),
        content: SizedBox(
          width: 400,
          height: 400,
          child: snap.docs.isEmpty
              ? const Center(child: Text("No appointments found."))
              : ListView(
            children: snap.docs.map((d) {
              final data = d.data();
              final date = (data['date'] as Timestamp?)?.toDate();
              final slot = data['slot'] ?? '-';
              final bed = data['bedName'] ?? '-';
              final status = data['status'] ?? '-';
              return ListTile(
                leading: const Icon(Icons.event_note),
                title: Text(DateFormat('MMM d, yyyy').format(date!)),
                subtitle: Text("Slot: $slot | Bed: $bed | Status: $status"),
              );
            }).toList(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Close")),
        ],
      ),
    );
  }

  Future<void> _showBedUsageDialog(String patientId) async {
    final snap = await FirebaseFirestore.instance
        .collection('appointments')
        .where('patientId', isEqualTo: patientId)
        .orderBy('date', descending: true)
        .limit(5)
        .get();

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Recent Bed Usage"),
        content: SizedBox(
          width: 400,
          height: 300,
          child: snap.docs.isEmpty
              ? const Center(child: Text("No bed usage records found."))
              : ListView(
            children: snap.docs.map((d) {
              final data = d.data();
              final date = (data['date'] as Timestamp?)?.toDate();
              final bed = data['bedName'] ?? '-';
              return ListTile(
                title: Text(bed),
                subtitle: Text(DateFormat('MMM d, yyyy').format(date!)),
                leading: const Icon(Icons.bed),
              );
            }).toList(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Close")),
        ],
      ),
    );
  }
}
