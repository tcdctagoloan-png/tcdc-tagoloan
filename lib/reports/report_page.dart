import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'admin_report_pdf.dart'; // contains all PDF generators

class ReportsPage extends StatefulWidget {
  final String role; // "admin", "nurse", "patient"
  final String? userId; // only required for patient

  const ReportsPage({
    super.key,
    required this.role,
    this.userId,
  });

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  String _searchQuery = "";
  DateTime _selectedDate = DateTime.now();

  // ------------ PRINT REPORT PLACEHOLDER ------------
  void _printReport(String type) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Printing $type report...")),
    );
    // Hook this to admin_report_pdf.dart functions
  }

  @override
  Widget build(BuildContext context) {
    return _buildReportList(widget.role);
  }

  Widget _buildReportList(String role) {
    switch (role) {
      case "admin":
        return _adminTabs();
      case "nurse":
        return _bedsReport();
      case "patient":
        return _myAppointments();
      default:
        return const Center(child: Text("Unauthorized access"));
    }
  }

  // ---------------- ADMIN REPORTS ----------------
  Widget _adminTabs() {
    return DefaultTabController(
      length: 4,
      child: Column(
        children: [
          const TabBar(
            labelColor: Colors.blueAccent,
            tabs: [
              Tab(text: "Patients"),
              Tab(text: "Nurses"),
              Tab(text: "Appointments"),
              Tab(text: "Beds"),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                Column(children: [
                  _buildSearchBar("Search Patients...", "Patients"),
                  Expanded(child: _patientsReport()),
                ]),
                Column(children: [
                  _buildSearchBar("Search Nurses...", "Nurses"),
                  Expanded(child: _nursesReport()),
                ]),
                Column(children: [
                  _buildSearchBar("Search Appointments...", "Appointments"),
                  Expanded(child: _appointmentsReport()),
                ]),
                Column(children: [
                  _buildSearchBar("Search Beds...", "Beds"),
                  _buildDatePicker(),
                  Expanded(child: _bedsReport()),
                ]),
              ],
            ),
          )
        ],
      ),
    );
  }

  // ---------------- SEARCH BAR + PRINT ----------------
  Widget _buildSearchBar(String hint, String type) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              decoration: InputDecoration(
                hintText: hint,
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onChanged: (val) {
                setState(() {
                  _searchQuery = val.toLowerCase();
                });
              },
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.print, color: Colors.blue),
            onPressed: () => _printReport(type),
          ),
        ],
      ),
    );
  }

  // ---------------- DATE PICKER FOR BEDS ----------------
  Widget _buildDatePicker() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          Text(
            "Date: ${_selectedDate.year}-${_selectedDate.month}-${_selectedDate.day}",
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _selectedDate,
                firstDate: DateTime(2020),
                lastDate: DateTime(2100),
              );
              if (picked != null && mounted) {
                setState(() => _selectedDate = picked);
              }
            },
            child: const Text("Pick Date"),
          ),
        ],
      ),
    );
  }

  // ---------------- PATIENT REPORT ----------------
  Widget _myAppointments() {
    if (widget.userId == null) {
      return const Center(child: Text("No user ID provided"));
    }

    return Column(
      children: [
        _buildSearchBar("Search My Appointments...", "MyAppointments"),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('appointments')
                .where('patientId', isEqualTo: widget.userId)
                .orderBy('date', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final docs = snapshot.data!.docs.where((doc) {
                final d = doc.data() as Map<String, dynamic>;
                final dateStr =
                (d['date'] as Timestamp).toDate().toIso8601String();
                return d['slot']
                    .toString()
                    .toLowerCase()
                    .contains(_searchQuery) ||
                    d['status']
                        .toString()
                        .toLowerCase()
                        .contains(_searchQuery) ||
                    (d['bedId'] ?? '')
                        .toString()
                        .toLowerCase()
                        .contains(_searchQuery) ||
                    dateStr.toLowerCase().contains(_searchQuery);
              }).toList();

              if (docs.isEmpty) {
                return const Center(child: Text("No appointments found"));
              }

              return ListView(
                children: docs.map((doc) {
                  final d = doc.data() as Map<String, dynamic>;
                  final date = (d['date'] as Timestamp).toDate();
                  return Card(
                    margin: const EdgeInsets.all(8),
                    child: ListTile(
                      leading: const Icon(Icons.event, color: Colors.blue),
                      title: Text(
                        "Date: ${date.year}-${date.month}-${date.day}",
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      subtitle: Text(
                        "Slot: ${d['slot']} | Status: ${d['status']} | Bed: ${d['bedId'] ?? 'Unassigned'}",
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ),
      ],
    );
  }

  // ---------------- NURSE/ADMIN: Beds ----------------
  Widget _bedsReport() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('beds').snapshots(),
      builder: (context, bedSnapshot) {
        if (!bedSnapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final bedDocs = bedSnapshot.data!.docs;

        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('appointments')
              .where('status', isEqualTo: 'approved')
              .snapshots(),
          builder: (context, apptSnapshot) {
            if (!apptSnapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final apptDocs = apptSnapshot.data!.docs;

            // Count only appointments on selected date
            final Map<String, int> bedCounts = {};
            for (var a in apptDocs) {
              final aData = a.data() as Map<String, dynamic>;
              final bedId = aData['bedId'];
              final date = (aData['date'] as Timestamp).toDate();
              if (bedId != null &&
                  date.year == _selectedDate.year &&
                  date.month == _selectedDate.month &&
                  date.day == _selectedDate.day) {
                bedCounts[bedId] = (bedCounts[bedId] ?? 0) + 1;
              }
            }

            // Sort beds by name
            final sortedBeds = bedDocs.toList()
              ..sort((a, b) {
                final aName = (a['name'] ?? '').toString();
                final bName = (b['name'] ?? '').toString();
                return aName.compareTo(bName);
              });

            final filtered = sortedBeds.where((doc) {
              final data = doc.data() as Map<String, dynamic>;
              final bedName = (data['name'] ?? '').toString().toLowerCase();
              return bedName.contains(_searchQuery) ||
                  doc.id.toLowerCase().contains(_searchQuery);
            }).toList();

            return ListView(
              children: filtered.map((doc) {
                final data = doc.data() as Map<String, dynamic>;
                final count = bedCounts[doc.id] ?? 0;
                return Card(
                  margin: const EdgeInsets.all(8),
                  child: ListTile(
                    leading: Icon(
                      Icons.bed,
                      color: data['isWorking']?.toString() == "true"
                          ? Colors.green
                          : Colors.red,
                    ),
                    title: Text(data['name'] ?? 'Unknown Bed'),
                    subtitle: Text("Assigned Patients on selected date: $count"),
                  ),
                );
              }).toList(),
            );
          },
        );
      },
    );
  }

  // ---------------- ADMIN: Patients ----------------
  Widget _patientsReport() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'patient')
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snapshot.data!.docs.where((doc) {
          final d = doc.data() as Map<String, dynamic>;
          return (d['fullName'] ?? '')
              .toString()
              .toLowerCase()
              .contains(_searchQuery) ||
              (d['email'] ?? '')
                  .toString()
                  .toLowerCase()
                  .contains(_searchQuery);
        }).toList();

        if (docs.isEmpty) {
          return const Center(child: Text("No patients found"));
        }

        return ListView(
          children: docs.map((doc) {
            final d = doc.data() as Map<String, dynamic>;
            return Card(
              margin: const EdgeInsets.all(8),
              child: ListTile(
                title: Text(d['fullName'] ?? 'No Name'),
                subtitle: Text("Email: ${d['email'] ?? 'N/A'}"),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  // ---------------- ADMIN: Nurses ----------------
  Widget _nursesReport() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'nurse')
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snapshot.data!.docs.where((doc) {
          final d = doc.data() as Map<String, dynamic>;
          return (d['fullName'] ?? '')
              .toString()
              .toLowerCase()
              .contains(_searchQuery) ||
              (d['email'] ?? '')
                  .toString()
                  .toLowerCase()
                  .contains(_searchQuery);
        }).toList();

        if (docs.isEmpty) {
          return const Center(child: Text("No nurses found"));
        }

        return ListView(
          children: docs.map((doc) {
            final d = doc.data() as Map<String, dynamic>;
            return Card(
              margin: const EdgeInsets.all(8),
              child: ListTile(
                title: Text(d['fullName'] ?? 'No Name'),
                subtitle: Text("Email: ${d['email'] ?? 'N/A'}"),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  // ---------------- ADMIN: Appointments ----------------
  Widget _appointmentsReport() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('appointments')
          .orderBy('date', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snapshot.data!.docs.where((doc) {
          final d = doc.data() as Map<String, dynamic>;
          final dateStr = (d['date'] as Timestamp).toDate().toIso8601String();
          return d['slot']
              .toString()
              .toLowerCase()
              .contains(_searchQuery) ||
              d['status']
                  .toString()
                  .toLowerCase()
                  .contains(_searchQuery) ||
              (d['bedId'] ?? '')
                  .toString()
                  .toLowerCase()
                  .contains(_searchQuery) ||
              dateStr.toLowerCase().contains(_searchQuery);
        }).toList();

        if (docs.isEmpty) {
          return const Center(child: Text("No appointments found"));
        }

        return ListView(
          children: docs.map((doc) {
            final d = doc.data() as Map<String, dynamic>;
            final date = (d['date'] as Timestamp).toDate();
            return Card(
              margin: const EdgeInsets.all(8),
              child: ListTile(
                leading: const Icon(Icons.event, color: Colors.blue),
                title: Text("Date: ${date.year}-${date.month}-${date.day}"),
                subtitle: Text(
                    "Slot: ${d['slot']} | Status: ${d['status']} | Bed: ${d['bedId'] ?? 'Unassigned'}"),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}
