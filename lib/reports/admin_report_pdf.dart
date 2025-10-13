// lib/reports/report_page.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'dart:async';
import 'package:intl/intl.dart'; // Add intl for consistent date formatting

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
    // Using DateFormat from intl package for reliable formatting
    return DateFormat('MMMM d, yyyy').format(date);
  }

  // Fetch user name
  Future<String> _fetchUserName(String? userId) async {
    if (userId == null || userId.isEmpty) return 'N/A (No ID)';
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(userId).get();
      if (!doc.exists) return 'N/A (Deleted User)';
      return doc.data()?['fullName'] ?? 'Unknown User';
    } catch (_) {
      return 'Error Fetching Name';
    }
  }

  // Fetch bed name
  Future<String> _fetchBedName(String? bedId) async {
    if (bedId == null || bedId.isEmpty) return 'Unassigned';
    try {
      final doc = await FirebaseFirestore.instance.collection('beds').doc(bedId).get();
      if (!doc.exists) return 'Unassigned (Deleted Bed)';
      return doc.data()?['name'] ?? 'Unknown Bed';
    } catch (_) {
      return 'Error Fetching Bed';
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Reports"),
          actions: [
            IconButton(
              icon: const Icon(Icons.print),
              tooltip: 'Print Current Report',
              onPressed: () async {
                try {
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
                } catch (e) {
                  // Show an error message to the user if printing fails
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Failed to generate report: $e')),
                    );
                  }
                }
              },
            ),
          ],
          // TabBar placed in AppBar bottom for cleaner layout (Standard practice)
          bottom: TabBar(
            onTap: (index) => setState(() => _currentTab = index),
            tabs: const [
              Tab(text: "Beds Utilization"),
              Tab(text: "Daily Appointments"),
              Tab(text: "Patient Directory"),
            ],
          ),
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Row(
                children: [
                  const Text("Reporting Date: ", style: TextStyle(fontWeight: FontWeight.w500)),
                  TextButton.icon(
                    icon: const Icon(Icons.calendar_today, size: 16),
                    label: Text(_formatDate(_selectedDate),
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
            const Divider(height: 1),
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
    );
  }

  // --- UI Tab Views ---

  Widget _bedsTab() {
    // Only fetch beds once, then use FutureBuilder for appointments based on date
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

            // FutureBuilder is now nested to react to _selectedDate changes
            return FutureBuilder<QuerySnapshot>(
              // Key change: Query on the selected date
              future: FirebaseFirestore.instance
                  .collection('appointments')
                  .where('bedId', isEqualTo: bed.id)
                  .where('status', isEqualTo: 'approved')
                  .where('date', isEqualTo: Timestamp.fromDate(_selectedDate))
                  .get(),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) return const ListTile(title: Text('Loading Bed Utilization...'));

                final assignedCount = snap.data?.docs.length ?? 0;

                return Card(
                  elevation: 2,
                  margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                  child: ListTile(
                    title: Text(bedData['name'] ?? 'Unknown Bed', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    subtitle: Text("Appointments on ${_formatDate(_selectedDate)}: $assignedCount"),
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

            // Fetch patient and bed name concurrently
            return FutureBuilder<List<String>>(
              future: Future.wait([_fetchUserName(patientId), _fetchBedName(bedId)]),
              builder: (context, nameSnapshot) {
                if (nameSnapshot.connectionState == ConnectionState.waiting) return const ListTile(title: Text('Loading Appointment Details...'));

                final patientName = nameSnapshot.data?[0] ?? 'Unknown Patient';
                final bedName = nameSnapshot.data?[1] ?? 'Unassigned Bed';
                final status = app['status'] ?? 'N/A';
                final slot = app['slot'] ?? 'N/A';

                Color statusColor = Colors.grey;
                if (status == 'approved') statusColor = Colors.blue;
                else if (status == 'completed') statusColor = Colors.green;
                else if (status == 'cancelled') statusColor = Colors.red;

                return Card(
                  elevation: 2,
                  margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                  child: ListTile(
                    leading: Text(slot, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    title: Text("Patient: $patientName", style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text("Bed: $bedName"),
                    trailing: Text(status, style: TextStyle(color: statusColor)),
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

  /// Prints the Beds Utilization Report for the selected date.
  Future<void> _printBedsReport() async {
    final pdf = pw.Document();
    final bedsSnap = await FirebaseFirestore.instance.collection('beds').get();
    final bedsData = <List<String>>[];

    for (var bed in bedsSnap.docs) {
      final bedMap = bed.data() as Map<String, dynamic>;
      // Fetch only approved appointments for the selected date
      final assignedSnap = await FirebaseFirestore.instance
          .collection('appointments')
          .where('bedId', isEqualTo: bed.id)
          .where('status', isEqualTo: 'approved')
          .where('date', isEqualTo: Timestamp.fromDate(_selectedDate))
          .get();

      bedsData.add([
        bedMap['name'] ?? 'Unknown Bed',
        assignedSnap.docs.length.toString(),
        (bedMap['isWorking'] == true ? 'Working 🟢' : 'Not Working 🔴'),
      ]);
    }

    pdf.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      build: (context) => [
        pw.Center(child: pw.Text("BEDS UTILIZATION REPORT", style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold))),
        pw.Center(child: pw.Text("Date: ${_formatDate(_selectedDate)}", style: const pw.TextStyle(fontSize: 16))),
        pw.SizedBox(height: 20),

        // Check if there's data to display
        if (bedsData.isEmpty)
          pw.Center(child: pw.Text("No bed data available.", style: const pw.TextStyle(fontSize: 14, color: PdfColors.grey)))
        else
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

  /// Prints the Daily Appointments Report for the selected date.
  Future<void> _printAppointmentsReport() async {
    final pdf = pw.Document();
    final appsSnap = await FirebaseFirestore.instance
        .collection('appointments')
        .where('date', isEqualTo: Timestamp.fromDate(_selectedDate))
        .orderBy('slot')
        .get();

    final data = await Future.wait(appsSnap.docs.map((a) async {
      final ad = a.data() as Map<String, dynamic>;
      // Fetch patient and bed name concurrently and wait for results
      final details = await Future.wait([
        _fetchUserName(ad['patientId']),
        _fetchBedName(ad['bedId'])
      ]);

      return [
        details[0], // Patient Name
        ad['slot'] ?? 'N/A',
        details[1], // Bed Name
        ad['status'] ?? 'N/A',
      ];
    }));

    pdf.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4.landscape,
      build: (context) => [
        pw.Center(child: pw.Text("DAILY APPOINTMENT REPORT", style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold))),
        pw.Center(child: pw.Text("Date: ${_formatDate(_selectedDate)}", style: const pw.TextStyle(fontSize: 16))),
        pw.SizedBox(height: 20),

        if (data.isEmpty)
          pw.Center(child: pw.Text("No appointments found for this date.", style: const pw.TextStyle(fontSize: 14, color: PdfColors.grey)))
        else
          pw.TableHelper.fromTextArray(
            context: context,
            headers: ['Patient Full Name', 'Slot', 'Assigned Bed', 'Status'],
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

  /// Prints the Patient Contact Directory Report.
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
        pw.Center(child: pw.Text("PATIENT CONTACT DIRECTORY", style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold))),
        pw.SizedBox(height: 20),

        if (data.isEmpty)
          pw.Center(child: pw.Text("No patient records found.", style: const pw.TextStyle(fontSize: 14, color: PdfColors.grey)))
        else
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