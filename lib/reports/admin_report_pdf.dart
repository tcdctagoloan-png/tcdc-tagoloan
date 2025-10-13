// lib/reports/report_page.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class ReportsPage extends StatefulWidget {
  final String? role;
  final String? userId;

  const ReportsPage({super.key, this.role, this.userId});

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  DateTime _selectedDate = DateTime.now();
  int _currentTab = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Reports"),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            onPressed: () async {
              switch (_currentTab) {
                case 0:
                  await _previewReport("Beds", _buildBedsPdf);
                  break;
                case 1:
                  await _previewReport("Appointments", _buildAppointmentsPdf);
                  break;
                case 2:
                  await _previewReport("Patients", _buildPatientsPdf);
                  break;
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                const Text("Selected Date: "),
                TextButton(
                  child: Text(
                    "${_selectedDate.year}-${_selectedDate.month}-${_selectedDate.day}",
                  ),
                  onPressed: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: _selectedDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2100),
                    );
                    if (date != null) {
                      setState(() => _selectedDate = date);
                    }
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
                    onTap: (index) {
                      setState(() => _currentTab = index);
                    },
                    tabs: const [
                      Tab(text: "Beds"),
                      Tab(text: "Appointments"),
                      Tab(text: "Patients"),
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

  // -------------------------- PDF PREVIEW --------------------------
  Future<void> _previewReport(
      String title, Future<pw.Document> Function() buildPdf) async {
    final pdf = await buildPdf();

    // Opens PDF preview in a new full-screen dialog
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(title: Text("$title Report Preview")),
          body: PdfPreview(
            build: (format) async => pdf.save(),
            allowPrinting: true,
            allowSharing: true,
            canChangeOrientation: false,
            canChangePageFormat: false,
          ),
        ),
      ),
    );
  }

  // -------------------------- FIRESTORE TABS --------------------------
  Widget _bedsTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('beds').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

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
                if (!snap.hasData) return const SizedBox();
                final assignedCount = snap.data!.docs.length;
                return Card(
                  child: ListTile(
                    title: Text(bedData['name'] ?? 'Unknown'),
                    subtitle: Text("Assigned Patients: $assignedCount"),
                    trailing: Text(
                      bedData['isWorking'] == true ? "Working" : "Not Working",
                      style: TextStyle(
                        color: bedData['isWorking'] == true
                            ? Colors.green
                            : Colors.red,
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
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final appointments = snapshot.data!.docs;
        return ListView.builder(
          itemCount: appointments.length,
          itemBuilder: (context, index) {
            final app = appointments[index].data() as Map<String, dynamic>;
            return Card(
              child: ListTile(
                title: Text("Patient ID: ${app['patientId'] ?? ''}"),
                subtitle: Text(
                    "Slot: ${app['slot'] ?? ''}, Bed: ${app['bedId'] ?? 'Unassigned'}, Status: ${app['status'] ?? ''}"),
              ),
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
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final patients = snapshot.data!.docs;
        return ListView.builder(
          itemCount: patients.length,
          itemBuilder: (context, index) {
            final patient = patients[index].data() as Map<String, dynamic>;
            return Card(
              child: ListTile(
                title: Text(patient['fullName'] ?? 'Unknown'),
                subtitle: Text(patient['email'] ?? ''),
              ),
            );
          },
        );
      },
    );
  }

  // -------------------------- PDF GENERATORS --------------------------
  Future<pw.Document> _buildBedsPdf() async {
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
        bedMap['name'] ?? 'Unknown',
        assignedSnap.docs.length.toString(),
        bedMap['isWorking'] == true ? 'Working' : 'Not Working',
      ]);
    }

    pdf.addPage(
      pw.MultiPage(
        build: (context) => [
          pw.Text(
            "Beds Report - ${_selectedDate.year}-${_selectedDate.month}-${_selectedDate.day}",
            style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 10),
          pw.TableHelper.fromTextArray(
            headers: ['Bed Name', 'Assigned Patients', 'Status'],
            data: bedsData,
          ),
        ],
      ),
    );

    return pdf;
  }

  Future<pw.Document> _buildAppointmentsPdf() async {
    final pdf = pw.Document();
    final appsSnap = await FirebaseFirestore.instance
        .collection('appointments')
        .where('date', isEqualTo: Timestamp.fromDate(_selectedDate))
        .get();

    final data = appsSnap.docs.map((a) {
      final ad = a.data() as Map<String, dynamic>;
      return [
        ad['patientId'] ?? '',
        ad['slot'] ?? '',
        ad['bedId'] ?? 'Unassigned',
        ad['status'] ?? '',
      ];
    }).toList();

    pdf.addPage(
      pw.MultiPage(
        build: (context) => [
          pw.Text(
            "Appointments Report - ${_selectedDate.year}-${_selectedDate.month}-${_selectedDate.day}",
            style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 10),
          pw.TableHelper.fromTextArray(
            headers: ['Patient', 'Slot', 'Bed', 'Status'],
            data: data,
          ),
        ],
      ),
    );

    return pdf;
  }

  Future<pw.Document> _buildPatientsPdf() async {
    final pdf = pw.Document();
    final patientsSnap = await FirebaseFirestore.instance
        .collection('users')
        .where('role', isEqualTo: 'patient')
        .get();

    final data = patientsSnap.docs.map((p) {
      final pd = p.data() as Map<String, dynamic>;
      return [pd['fullName'] ?? '', pd['email'] ?? ''];
    }).toList();

    pdf.addPage(
      pw.MultiPage(
        build: (context) => [
          pw.Text(
            "Patients Report",
            style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 10),
          pw.TableHelper.fromTextArray(
            headers: ['Name', 'Email'],
            data: data,
          ),
        ],
      ),
    );

    return pdf;
  }
}
