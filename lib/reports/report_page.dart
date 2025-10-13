// lib/reports/report_page.dart
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';

class ReportsPage extends StatefulWidget {
  final String? role; // "admin", "nurse", "patient"
  final String? userId;

  const ReportsPage({super.key, this.role = "admin", this.userId});

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";
  DateTime _selectedDate = DateTime.now();

  late List<String> _reportTypes;
  String _selectedReport = "";

  @override
  void initState() {
    super.initState();

    final adminReports = <String>[
      "Daily Appointment Schedule",
      "Nurse Workload Summary",
      "Dialysis Machine Utilization",
      "Appointment Count by Status",
      "Patient Contact Information",
      "Machine Allocation Log",
    ];

    final nurseReports = <String>[
      "Daily Appointment Schedule",
      "Appointment Count by Status",
      "Machine Allocation Log",
      "Dialysis Machine Utilization",
    ];

    final patientReports = <String>[
      "Appointment History of Patient",
      "Upcoming Appointments per Patient",
      "Notifications per Patient",
      "Machine Allocation Log",
    ];

    if (widget.role == "patient") {
      _reportTypes = patientReports;
    } else if (widget.role == "nurse") {
      _reportTypes = nurseReports;
    } else {
      _reportTypes = adminReports;
    }

    _selectedReport = _reportTypes.first;

    _searchController.addListener(() {
      setState(() => _searchQuery = _searchController.text.toLowerCase());
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _formatDate(DateTime date) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  String _formatReportDate(dynamic dateValue) {
    DateTime date;
    if (dateValue is Timestamp) {
      date = dateValue.toDate();
    } else if (dateValue is String) {
      try {
        date = DateTime.parse(dateValue);
      } catch (_) {
        return dateValue;
      }
    } else {
      return 'N/A';
    }
    return _formatDate(date);
  }

  Future<String> _fetchUserName(String? userId) async {
    if (userId == null || userId.isEmpty || userId == 'N/A') return 'N/A';
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(userId).get();
      if (doc.exists) {
        return doc.data()?['fullName']?.toString() ?? userId;
      }
      return userId;
    } catch (_) {
      return 'N/A';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isPatient = widget.role == "patient";

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: Colors.green.shade700,
        title: const Text("Reports", style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1400),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                _buildTopControls(),
                const SizedBox(height: 16),
                Expanded(child: _buildReportContainer(isPatient)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopControls() {
    return Row(
      children: [
        Expanded(
          child: Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: TextField(
                controller: _searchController,
                decoration: const InputDecoration(
                  hintText: "Search...",
                  border: InputBorder.none,
                  icon: Icon(Icons.search),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: DropdownButton<String>(
              value: _selectedReport,
              underline: const SizedBox(),
              items: _reportTypes.map((type) {
                return DropdownMenuItem(value: type, child: Text(type));
              }).toList(),
              onChanged: (val) {
                if (val != null) setState(() => _selectedReport = val);
              },
            ),
          ),
        ),
        const SizedBox(width: 12),
        Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          child: InkWell(
            onTap: () async {
              final date = await showDatePicker(
                context: context,
                initialDate: _selectedDate,
                firstDate: DateTime(2020),
                lastDate: DateTime(2100),
              );
              if (date != null && mounted) setState(() => _selectedDate = date);
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  const Icon(Icons.calendar_today, size: 18),
                  const SizedBox(width: 8),
                  Text(_formatDate(_selectedDate),
                      style: const TextStyle(fontWeight: FontWeight.w500)),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          child: IconButton(
            tooltip: "Export PDF / Preview",
            icon: const Icon(Icons.picture_as_pdf, color: Colors.green, size: 26),
            onPressed: _onPrintPressed,
          ),
        ),
      ],
    );
  }

  Widget _buildReportContainer(bool isPatient) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 8)],
      ),
      padding: const EdgeInsets.all(16),
      child: SingleChildScrollView(
        child: Column(
          children: [
            if (_selectedReport == "Daily Appointment Schedule") _dailyAppointmentSchedule(),
            if (_selectedReport == "Appointment History of Patient") _appointmentHistoryOfPatient(),
            if (_selectedReport == "Nurse Workload Summary") _nurseWorkloadSummary(),
            if (_selectedReport == "Dialysis Machine Utilization") _dialysisMachineUtilization(),
            if (_selectedReport == "Notifications per Patient") _notificationsPerPatient(),
            if (_selectedReport == "Upcoming Appointments per Patient") _upcomingAppointmentsPerPatient(),
            if (_selectedReport == "Appointment Count by Status") _appointmentCountByStatus(),
            if (_selectedReport == "Patient Contact Information") _patientContactInformation(),
            if (_selectedReport == "Machine Allocation Log") _machineAllocationLog(),
          ],
        ),
      ),
    );
  }

  Widget _buildDataTable({
    required String title,
    required List<String> columns,
    required List<List<String>> rows,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87)),
        const SizedBox(height: 12),
        LayoutBuilder(builder: (context, constraints) {
          // Ensure the inner container has an explicit width (avoids hitTest size errors)
          final double tableWidth = constraints.maxWidth.isFinite ? constraints.maxWidth : MediaQuery.of(context).size.width;
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: tableWidth,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 6)],
                ),
                child: rows.isEmpty
                    ? Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Center(
                    child: Text("No data available.", style: TextStyle(color: Colors.grey.shade600)),
                  ),
                )
                    : DataTable(
                  columnSpacing: 30,
                  headingRowColor: MaterialStateProperty.all(Colors.green.shade100),
                  columns: columns
                      .map((col) => DataColumn(
                      label: Text(col, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))))
                      .toList(),
                  rows: List.generate(
                    rows.length,
                        (index) {
                      final row = rows[index];
                      final color = index % 2 == 0 ? Colors.white : Colors.green.shade50;
                      return DataRow(
                        color: MaterialStateProperty.all(color),
                        cells: row.map((cell) => DataCell(Text(cell, style: const TextStyle(fontSize: 14)))).toList(),
                      );
                    },
                  ),
                ),
              ),
            ),
          );
        }),
        const SizedBox(height: 30),
      ],
    );
  }

  // Reports ============================

  Widget _dailyAppointmentSchedule() => _firestoreReport(
    title: "Daily Appointment Schedule",
    collection: 'appointments',
    query: (col) {
      final start = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
      final end = start.add(const Duration(days: 1));
      return col.where('date', isGreaterThanOrEqualTo: start).where('date', isLessThan: end);
    },
    columns: ["Bed Name", "Patient Name", "Nurse Name", "Date", "Slot", "Status"],
    rowBuilder: (d) async => [
      d['bedName'] ?? 'N/A',
      await _fetchUserName(d['patientId']),
      await _fetchUserName(d['nurseId']),
      _formatReportDate(d['date']),
      d['slot'] ?? 'N/A',
      d['status'] ?? 'N/A'
    ],
  );

  Widget _appointmentHistoryOfPatient() {
    if (widget.userId == null) return const SizedBox();
    return _firestoreReport(
      title: "Appointment History",
      collection: 'appointments',
      query: (col) => col.where('patientId', isEqualTo: widget.userId).orderBy('date', descending: true),
      columns: ["Date", "Time", "Bed", "Status"],
      rowBuilder: (d) async => [
        _formatReportDate(d['date']),
        d['slot'] ?? 'N/A',
        d['bedName'] ?? 'N/A',
        d['status'] ?? 'N/A'
      ],
    );
  }

  Widget _nurseWorkloadSummary() => _firestoreReport(
    title: "Nurse Workload Summary",
    collection: 'users',
    query: (col) => col.where('role', isEqualTo: 'nurse'),
    columns: ["Nurse Name", "Assigned Patients"],
    rowBuilder: (d) async {
      final countSnapshot = await FirebaseFirestore.instance
          .collection('appointments')
          .where('nurseId', isEqualTo: d.id)
          .get();
      return [
        d['fullName'] ?? 'N/A',
        countSnapshot.docs.length.toString(),
      ];
    },
  );

  Widget _dialysisMachineUtilization() => _firestoreReport(
    title: "Dialysis Machine Utilization",
    collection: 'appointments',
    query: (col) => col,
    columns: ["Machine", "Total Appointments"],
    rowBuilder: (d) async => [],
    customRowGenerator: (snapshot) {
      Map<String, int> machineCount = {};
      for (var doc in snapshot.docs) {
        final bedName = (doc.data() as Map<String, dynamic>)['bedName'] ?? 'N/A';
        machineCount[bedName] = (machineCount[bedName] ?? 0) + 1;
      }
      return machineCount.entries.map((e) => [e.key, e.value.toString()]).toList();
    },
  );

  Widget _notificationsPerPatient() => _firestoreReport(
    title: "Notifications per Patient",
    collection: 'notifications',
    query: (col) => col.orderBy('createdAt', descending: true),
    columns: ["Title", "Message", "User", "Created At", "Read"],
    rowBuilder: (d) async => [
      d['title'] ?? 'N/A',
      d['message'] ?? 'N/A',
      await _fetchUserName(d['userId']),
      _formatReportDate(d['createdAt']),
      d['isRead'].toString(),
    ],
  );

  Widget _upcomingAppointmentsPerPatient() {
    final now = DateTime.now();
    return _firestoreReport(
      title: "Upcoming Appointments per Patient",
      collection: 'appointments',
      query: (col) => col.where('date', isGreaterThanOrEqualTo: now),
      columns: ["Patient", "Date", "Time", "Bed"],
      rowBuilder: (d) async => [
        await _fetchUserName(d['patientId']),
        _formatReportDate(d['date']),
        d['slot'] ?? 'N/A',
        d['bedName'] ?? 'N/A'
      ],
    );
  }

  Widget _appointmentCountByStatus() => _firestoreReport(
    title: "Appointment Count by Status",
    collection: 'appointments',
    query: (col) => col,
    columns: ["Status", "Count"],
    rowBuilder: (d) async => [],
    customRowGenerator: (snapshot) {
      Map<String, int> statusCount = {};
      for (var doc in snapshot.docs) {
        final status = (doc.data() as Map<String, dynamic>)['status'] ?? 'N/A';
        statusCount[status] = (statusCount[status] ?? 0) + 1;
      }
      return statusCount.entries.map((e) => [e.key, e.value.toString()]).toList();
    },
  );

  Widget _patientContactInformation() => _firestoreReport(
    title: "Patient Contact Information",
    collection: 'users',
    query: (col) => col.where('role', isEqualTo: 'patient'),
    columns: [
      "Full Name",
      "Username",
      "Email",
      "Contact Number",
      "Address",
      "Verified",
      "Created At"
    ],
    rowBuilder: (d) async => [
      d['fullName'] ?? 'N/A',
      d['username'] ?? 'N/A',
      d['email'] ?? 'N/A',
      d['contactNumber'] ?? 'N/A',
      d['address'] ?? 'N/A',
      d['verified'].toString(),
      _formatReportDate(d['createdAt']),
    ],
  );

  Widget _machineAllocationLog() => _firestoreReport(
    title: "Machine Allocation Log",
    collection: 'appointments',
    query: (col) => col.orderBy('date', descending: true),
    columns: ["Bed Name", "Patient Name", "Date", "Time"],
    rowBuilder: (d) async => [
      d['bedName'] ?? 'N/A',
      await _fetchUserName(d['patientId']),
      _formatReportDate(d['date']),
      d['slot'] ?? 'N/A'
    ],
  );

  Widget _firestoreReport({
    required String title,
    required String collection,
    required Query Function(CollectionReference col) query,
    required List<String> columns,
    required Future<List<String>> Function(Map<String, dynamic> d) rowBuilder,
    List<List<String>> Function(QuerySnapshot snapshot)? customRowGenerator,
  }) {
    return StreamBuilder<QuerySnapshot>(
      stream: query(FirebaseFirestore.instance.collection(collection)).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return _buildDataTable(title: title, columns: columns, rows: const []);
        if (customRowGenerator != null) {
          final data = customRowGenerator(snapshot.data!);
          return _buildDataTable(title: title, columns: columns, rows: data);
        }
        final futures = snapshot.data!.docs.map((doc) async {
          final d = doc.data() as Map<String, dynamic>;
          final result = await rowBuilder(d);
          return result.map((e) => e.toString()).toList();
        }).toList();
        return FutureBuilder<List<List<String>>>(
          future: Future.wait(futures),
          builder: (context, fs) {
            if (!fs.hasData) return _buildDataTable(title: title, columns: columns, rows: const []);
            // apply search filter if any
            final filtered = fs.data!
                .where((row) => row.any((cell) => cell.toLowerCase().contains(_searchQuery)))
                .toList();
            return _buildDataTable(title: title, columns: columns, rows: filtered);
          },
        );
      },
    );
  }

  // ----------------------------
  // PDF Preview + Generation
  // ----------------------------
  void _onPrintPressed() {
    showDialog(
      context: context,
      builder: (context) {
        // Provide explicit size inside dialog to avoid hitTest errors
        final width = MediaQuery.of(context).size.width * 0.9;
        final height = MediaQuery.of(context).size.height * 0.85;
        return Dialog(
          insetPadding: const EdgeInsets.all(16),
          child: SizedBox(
            width: width,
            height: height,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Row(
                    children: [
                      Expanded(child: Text("Preview: $_selectedReport", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.redAccent),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: PdfPreview(
                    canChangeOrientation: false,
                    canChangePageFormat: false,
                    build: (format) async => await _generatePdf(format),
                    allowPrinting: true,
                    allowSharing: true,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Row(
                    children: [
                      ElevatedButton.icon(
                        icon: const Icon(Icons.download),
                        label: const Text("Download PDF"),
                        onPressed: () async {
                          final bytes = await _generatePdf(PdfPageFormat.a4);
                          // The printing package exposes layoutPdf which triggers platform print/save dialog.
                          await Printing.sharePdf(bytes: bytes, filename: "${_selectedReport.replaceAll(' ', '_')}.pdf");
                        },
                      ),
                      const SizedBox(width: 12),
                      OutlinedButton(
                        child: const Text("Close"),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<Uint8List> _generatePdf(PdfPageFormat format) async {
    final pdf = pw.Document();
    final generatedOn = _formatDate(DateTime.now());

    // Headers + rows
    List<String> headers = [];
    List<List<String>> rows = [];

    // Build data per selected report
    if (_selectedReport == "Daily Appointment Schedule") {
      headers = ["Bed Name", "Patient", "Nurse", "Date", "Slot", "Status"];
      final start = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
      final end = start.add(const Duration(days: 1));
      final snap = await FirebaseFirestore.instance
          .collection('appointments')
          .where('date', isGreaterThanOrEqualTo: start)
          .where('date', isLessThan: end)
          .orderBy('slot')
          .get();
      for (var doc in snap.docs) {
        final d = doc.data();
        rows.add([
          d['bedName'] ?? 'N/A',
          await _fetchUserName(d['patientId']),
          await _fetchUserName(d['nurseId']),
          _formatReportDate(d['date']),
          d['slot'] ?? 'N/A',
          d['status'] ?? 'N/A',
        ]);
      }
    } else if (_selectedReport == "Appointment History of Patient") {
      headers = ["Date", "Time", "Bed", "Status"];
      if (widget.userId != null) {
        final snap = await FirebaseFirestore.instance
            .collection('appointments')
            .where('patientId', isEqualTo: widget.userId)
            .orderBy('date', descending: true)
            .get();
        for (var doc in snap.docs) {
          final d = doc.data();
          rows.add([
            _formatReportDate(d['date']),
            d['slot'] ?? 'N/A',
            d['bedName'] ?? 'N/A',
            d['status'] ?? 'N/A',
          ]);
        }
      } else {
        rows.add(["No patient selected", "", "", ""]);
      }
    } else if (_selectedReport == "Patient Contact Information") {
      headers = ["Full Name", "Username", "Email", "Contact Number", "Address", "Verified", "Created At"];
      final snap = await FirebaseFirestore.instance.collection('users').where('role', isEqualTo: 'patient').orderBy('fullName').get();
      for (var doc in snap.docs) {
        final d = doc.data();
        rows.add([
          d['fullName'] ?? 'N/A',
          d['username'] ?? 'N/A',
          d['email'] ?? 'N/A',
          d['contactNumber'] ?? 'N/A',
          d['address'] ?? 'N/A',
          (d['verified'] ?? false).toString(),
          _formatReportDate(d['createdAt']),
        ]);
      }
    } else if (_selectedReport == "Dialysis Machine Utilization") {
      headers = ["Machine", "Total Appointments"];
      final snap = await FirebaseFirestore.instance.collection('appointments').get();
      final Map<String, int> count = {};
      for (var doc in snap.docs) {
        final bedName = (doc.data() as Map<String, dynamic>)['bedName'] ?? 'N/A';
        count[bedName] = (count[bedName] ?? 0) + 1;
      }
      for (var e in count.entries) {
        rows.add([e.key, e.value.toString()]);
      }
    } else if (_selectedReport == "Machine Allocation Log") {
      headers = ["Bed Name", "Patient Name", "Date", "Time"];
      final snap = await FirebaseFirestore.instance.collection('appointments').orderBy('date', descending: true).get();
      for (var doc in snap.docs) {
        final d = doc.data();
        rows.add([
          d['bedName'] ?? 'N/A',
          await _fetchUserName(d['patientId']),
          _formatReportDate(d['date']),
          d['slot'] ?? 'N/A',
        ]);
      }
    } else if (_selectedReport == "Notifications per Patient") {
      headers = ["Title", "Message", "User", "Created At", "Read"];
      final snap = await FirebaseFirestore.instance.collection('notifications').orderBy('createdAt', descending: true).get();
      for (var doc in snap.docs) {
        final d = doc.data();
        rows.add([
          d['title'] ?? 'N/A',
          d['message'] ?? 'N/A',
          await _fetchUserName(d['userId']),
          _formatReportDate(d['createdAt']),
          (d['isRead'] ?? false).toString(),
        ]);
      }
    } else if (_selectedReport == "Appointment Count by Status") {
      headers = ["Status", "Count"];
      final snap = await FirebaseFirestore.instance.collection('appointments').get();
      final Map<String, int> count = {};
      for (var doc in snap.docs) {
        final status = (doc.data() as Map<String, dynamic>)['status'] ?? 'N/A';
        count[status] = (count[status] ?? 0) + 1;
      }
      for (var e in count.entries) {
        rows.add([e.key, e.value.toString()]);
      }
    } else if (_selectedReport == "Nurse Workload Summary") {
      headers = ["Nurse Name", "Assigned Patients"];
      final nurses = await FirebaseFirestore.instance.collection('users').where('role', isEqualTo: 'nurse').get();
      for (var n in nurses.docs) {
        final ndata = n.data();
        final assigned = await FirebaseFirestore.instance.collection('appointments').where('nurseId', isEqualTo: n.id).get();
        rows.add([ndata['fullName'] ?? 'N/A', assigned.docs.length.toString()]);
      }
    } else if (_selectedReport == "Upcoming Appointments per Patient") {
      headers = ["Patient", "Date", "Time", "Bed"];
      final now = DateTime.now();
      final snap = await FirebaseFirestore.instance.collection('appointments').where('date', isGreaterThanOrEqualTo: now).orderBy('date').get();
      for (var doc in snap.docs) {
        final d = doc.data();
        rows.add([
          await _fetchUserName(d['patientId']),
          _formatReportDate(d['date']),
          d['slot'] ?? 'N/A',
          d['bedName'] ?? 'N/A',
        ]);
      }
    } else {
      // fallback
      headers = [_selectedReport];
      rows = [
        ["No PDF generator implemented for this report yet."]
      ];
    }

    // Build PDF page(s)
    pdf.addPage(
      pw.MultiPage(
        pageFormat: format,
        margin: const pw.EdgeInsets.all(18),
        build: (pw.Context ctx) => [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text("TCDC Dialysis Center", style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 6),
              pw.Text(_selectedReport, style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 8),
              pw.Text("Generated on: $generatedOn"),
              pw.SizedBox(height: 12),
              if (rows.isEmpty)
                pw.Center(child: pw.Text("No data for this report"))
              else
                pw.Table.fromTextArray(
                  headers: headers,
                  data: rows,
                  headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
                  headerDecoration: const pw.BoxDecoration(color: PdfColors.green700),
                  cellAlignment: pw.Alignment.centerLeft,
                  cellPadding: const pw.EdgeInsets.all(6),
                  columnWidths: {
                    // Distribute widths evenly but allow long names room
                    for (var i = 0; i < headers.length; i++)
                      i: const pw.FlexColumnWidth(1),
                  },
                ),
            ],
          ),
        ],
      ),
    );

    return pdf.save();
  }
}

extension on Map<String, dynamic> {
  // placeholder; in the firestoreReport code we used d.id sometimes, the map itself doesn't have id.
  Object? get id => null;
}
