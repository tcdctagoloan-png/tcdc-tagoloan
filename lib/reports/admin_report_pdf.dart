// lib/reports/report_page.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'dart:async';

class ReportsPage extends StatefulWidget {
  final String? role; // "admin" or "patient"
  final String? userId;

  const ReportsPage({super.key, this.role, this.userId});

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  DateTime _selectedDate = DateTime.now();
  int _currentTab = 0;

  // Format date as "Month Day, Year"
  String _formatDate(DateTime date) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  // Fetch user name
  Future<String> _fetchUserName(String? userId) async {
    if (userId == null || userId.isEmpty) return 'N/A';
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(userId).get();
      return doc.data()?['fullName'] ?? 'Unknown User';
    } catch (_) {
      return 'Error';
    }
  }

  // Fetch bed name
  Future<String> _fetchBedName(String? bedId) async {
    if (bedId == null || bedId.isEmpty) return 'Unassigned';
    try {
      final doc = await FirebaseFirestore.instance.collection('beds').doc(bedId).get();
      return doc.data()?['name'] ?? 'Unknown Bed';
    } catch (_) {
      return 'Error';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Reports"),
        actions: [
          IconButton(
            icon: const Icon(Icons.print),
            onPressed: () async {
              switch (_currentTab) {
                case 0:
                  await _printBedsReport();
                  break;
                case 1:
                  await _printAppointmentsReport();
                  break;
                case 2:
                  await _printPatientsReport();
                  break;
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                const Text("Selected Date: ", style: TextStyle(fontWeight: FontWeight.w500)),
                TextButton(
                  child: Text(_formatDate(_selectedDate),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  onPressed: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: _selectedDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2100),
                    );
                    if (date != null) setState(() => _selectedDate = date);
                  },
                ),
              ],
            ),
          ),
          Expanded(
            child: DefaultTabController(
              length: 3,
              child: Column(
                children: [
                  TabBar(
                    onTap: (index) => setState(() => _currentTab = index),
                    tabs: const [
                      Tab(text: "Beds Utilization"),
                      Tab(text: "Daily Appointments"),
                      Tab(text: "Patient Directory"),
                    ],
                  ),
                  Expanded(
                    child: TabBarView(
                      children: [
                        _bedsTab(),
                        _appointmentsTab(),
                        _patientsTab(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _bedsTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('beds').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const Center(child: Text("No beds found."));
        final beds = snapshot.data!.docs;
        return ListView.builder(
          itemCount: beds.length,
          itemBuilder: (context, index) {
            final bed = beds[index];
            final bedData = bed.data() as Map<String, dynamic>;
            return FutureBuilder<QuerySnapshot>(
              future: FirebaseFirestore.instance
                  .collection('appointments')
                  .where('bedId', isEqualTo: bed.id)
                  .where('status', isEqualTo: 'approved')
                  .where('date', isEqualTo: Timestamp.fromDate(_selectedDate))
                  .get(),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) return const ListTile(title: Text('Loading Bed Data...'));
                final assignedCount = snap.data?.docs.length ?? 0;
                return Card(
                  elevation: 2,
                  margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                  child: ListTile(
                    title: Text(bedData['name'] ?? 'Unknown Bed', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    subtitle: Text("Assigned Appointments for ${_formatDate(_selectedDate)}: $assignedCount"),
                    trailing: Text(
                      bedData['isWorking'] == true ? "🟢 Working" : "🔴 Not Working",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: bedData['isWorking'] == true ? Colors.green : Colors.red,
                      ),
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _appointmentsTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('appointments')
          .where('date', isEqualTo: Timestamp.fromDate(_selectedDate))
          .orderBy('slot')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const Center(child: Text("No appointments scheduled for this date."));
        final appointments = snapshot.data!.docs;
        return ListView.builder(
          itemCount: appointments.length,
          itemBuilder: (context, index) {
            final app = appointments[index].data() as Map<String, dynamic>;
            final patientId = app['patientId'] as String?;
            final bedId = app['bedId'] as String?;
            return FutureBuilder<List<String>>(
              future: Future.wait([_fetchUserName(patientId), _fetchBedName(bedId)]),
              builder: (context, nameSnapshot) {
                if (nameSnapshot.connectionState == ConnectionState.waiting) return const ListTile(title: Text('Loading Appointment Details...'));
                final patientName = nameSnapshot.data?[0] ?? 'Unknown Patient';
                final bedName = nameSnapshot.data?[1] ?? 'Unassigned Bed';
                final status = app['status'] ?? 'N/A';
                final slot = app['slot'] ?? 'N/A';
                return Card(
                  elevation: 2,
                  margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                  child: ListTile(
                    leading: Text(slot, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    title: Text("Patient: $patientName", style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text("Bed: $bedName"),
                    trailing: Text(status, style: TextStyle(color: status == 'approved' ? Colors.blue : Colors.grey)),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _patientsTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'patient')
          .orderBy('fullName')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const Center(child: Text("No patient data found."));
        final patients = snapshot.data!.docs;
        return ListView.builder(
          itemCount: patients.length,
          itemBuilder: (context, index) {
            final patient = patients[index].data() as Map<String, dynamic>;
            return Card(
              elevation: 2,
              margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
              child: ListTile(
                title: Text(patient['fullName'] ?? 'Unknown Patient', style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text("Email: ${patient['email'] ?? 'N/A'} | Contact: ${patient['contactNumber'] ?? 'N/A'}"),
              ),
            );
          },
        );
      },
    );
  }

  // ================= PDF PRINT FUNCTIONS =================

  Future<void> _printBedsReport() async {
    final pdf = pw.Document();
    final bedsSnap = await FirebaseFirestore.instance.collection('beds').get();
    final bedsData = <List<String>>[];
    for (var bed in bedsSnap.docs) {
      final bedMap = bed.data() as Map<String, dynamic>;
      final assignedSnap = await FirebaseFirestore.instance
          .collection('appointments')
          .where('bedId', isEqualTo: bed.id)
          .where('status', isEqualTo: 'approved')
          .where('date', isEqualTo: Timestamp.fromDate(_selectedDate))
          .get();
      bedsData.add([
        bedMap['name'] ?? 'Unknown Bed',
        assignedSnap.docs.length.toString(),
        bedMap['isWorking'] == true ? 'Working' : 'Not Working',
      ]);
    }

    pdf.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      build: (context) => [
        pw.Center(child: pw.Text("Beds Utilization Report", style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold))),
        pw.Center(child: pw.Text("Date: ${_formatDate(_selectedDate)}")),
        pw.SizedBox(height: 15),
        pw.TableHelper.fromTextArray(
          context: context,
          headers: ['Bed Name', 'Assigned Appointments', 'Status'],
          data: bedsData,
          cellAlignment: pw.Alignment.centerLeft,
          headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
          headerDecoration: const pw.BoxDecoration(color: PdfColors.indigo900),
          columnWidths: {0: const pw.FlexColumnWidth(3), 1: const pw.FlexColumnWidth(2), 2: const pw.FlexColumnWidth(1.5)},
          cellPadding: const pw.EdgeInsets.all(8),
        ),
      ],
    ));

    await Printing.layoutPdf(onLayout: (format) async => pdf.save());
  }

  Future<void> _printAppointmentsReport() async {
    final pdf = pw.Document();
    final appsSnap = await FirebaseFirestore.instance
        .collection('appointments')
        .where('date', isEqualTo: Timestamp.fromDate(_selectedDate))
        .orderBy('slot')
        .get();

    final futures = appsSnap.docs.map((a) async {
      final ad = a.data() as Map<String, dynamic>;
      final patientName = await _fetchUserName(ad['patientId']);
      final bedName = await _fetchBedName(ad['bedId']);
      return [
        patientName,
        ad['slot'] ?? 'N/A',
        bedName,
        ad['status'] ?? 'N/A',
      ];
    }).toList();

    final data = await Future.wait(futures);

    pdf.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4.landscape,
      build: (context) => [
        pw.Center(child: pw.Text("Daily Appointment Report", style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold))),
        pw.Center(child: pw.Text("Date: ${_formatDate(_selectedDate)}")),
        pw.SizedBox(height: 15),
        pw.TableHelper.fromTextArray(
          context: context,
          headers: ['Patient Full Name', 'Slot', 'Bed Name', 'Status'],
          data: data,
          cellAlignment: pw.Alignment.centerLeft,
          headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
          headerDecoration: const pw.BoxDecoration(color: PdfColors.indigo900),
          columnWidths: {0: const pw.FlexColumnWidth(3), 1: const pw.FlexColumnWidth(1.5), 2: const pw.FlexColumnWidth(2), 3: const pw.FlexColumnWidth(1.5)},
          cellPadding: const pw.EdgeInsets.all(8),
        ),
      ],
    ));

    await Printing.layoutPdf(onLayout: (format) async => pdf.save());
  }

  Future<void> _printPatientsReport() async {
    final pdf = pw.Document();
    final patientsSnap = await FirebaseFirestore.instance
        .collection('users')
        .where('role', isEqualTo: 'patient')
        .orderBy('fullName')
        .get();

    final data = patientsSnap.docs.map((p) {
      final pd = p.data() as Map<String, dynamic>;
      return [
        pd['fullName'] ?? 'Unknown Patient',
        pd['email'] ?? 'N/A',
        pd['contactNumber'] ?? 'N/A',
      ];
    }).toList();

    pdf.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      build: (context) => [
        pw.Center(child: pw.Text("Patient Contact Directory", style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold))),
        pw.SizedBox(height: 15),
        pw.TableHelper.fromTextArray(
          context: context,
          headers: ['Full Name', 'Email Address', 'Contact Number'],
          data: data,
          cellAlignment: pw.Alignment.centerLeft,
          headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
          headerDecoration: const pw.BoxDecoration(color: PdfColors.indigo900),
          columnWidths: {0: const pw.FlexColumnWidth(2.5), 1: const pw.FlexColumnWidth(3.5), 2: const pw.FlexColumnWidth(2)},
          cellPadding: const pw.EdgeInsets.all(8),
        ),
      ],
    ));

    await Printing.layoutPdf(onLayout: (format) async => pdf.save());
  }
}
