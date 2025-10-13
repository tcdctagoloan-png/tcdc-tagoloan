// lib/reports/report_page.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';

class ReportsPage extends StatefulWidget {
  final String? role; // "admin" or "patient"
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
      "Appointment History of Patient",
      "Nurse Workload Summary",
      "Dialysis Machine Utilization",
      "Notifications per Patient",
      "Upcoming Appointments per Patient",
      "Appointment Count by Status",
      "Patient Contact Information",
      "Machine Allocation Log",
    ];

    final patientReports = <String>[
      "Appointment History of Patient",
      "Upcoming Appointments per Patient",
      "Notifications per Patient",
      "Machine Allocation Log",
      "Appointment Count by Status",
    ];

    _reportTypes = (widget.role == "patient") ? patientReports : adminReports;
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
          constraints: const BoxConstraints(maxWidth: 1200),
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
                  Text(
                    "${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}",
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
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
            tooltip: "Export PDF",
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
    if (rows.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.black87)),
          const SizedBox(height: 8),
          const Text("No data available.", style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 24),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.black87)),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: Colors.grey.shade300),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 3, offset: const Offset(0, 1)),
            ],
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              dataRowHeight: 48,
              headingRowHeight: 48,
              horizontalMargin: 20,
              columnSpacing: 36,
              headingRowColor: MaterialStateProperty.all(Colors.grey.shade100),
              border: TableBorder.symmetric(
                inside: BorderSide(color: Colors.grey.shade300, width: 0.5),
                outside: BorderSide(color: Colors.grey.shade400, width: 0.8),
              ),
              columns: columns
                  .map((col) => DataColumn(
                label: Text(col,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, color: Colors.black87, fontSize: 14)),
              ))
                  .toList(),
              rows: List.generate(rows.length, (index) {
                final row = rows[index];
                final isEven = index % 2 == 0;
                return DataRow(
                  color: MaterialStateProperty.all(isEven ? Colors.grey.shade50 : Colors.white),
                  cells: row
                      .map((cell) => DataCell(Text(cell, style: const TextStyle(fontSize: 13, color: Colors.black87))))
                      .toList(),
                );
              }),
            ),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  // ====== PDF / Print Logic ======
  Future<void> _onPrintPressed() async {
    final pdf = pw.Document();
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4.landscape,
        build: (context) => pw.Center(
          child: pw.Text("PDF for $_selectedReport is not fully implemented"),
        ),
      ),
    );

    await Printing.layoutPdf(onLayout: (format) => pdf.save());
  }

  // ====== Report Widgets with Live Data ======

  Widget _dailyAppointmentSchedule() {
    final start = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
    final end = start.add(const Duration(days: 1));

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('appointments')
          .where('date', isGreaterThanOrEqualTo: start)
          .where('date', isLessThan: end)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final data = snapshot.data!.docs.map((doc) {
          final d = doc.data() as Map<String, dynamic>;
          return [
            d['bedName'] ?? 'N/A',
            d['patientId'] ?? 'N/A',
            d['nurseId'] ?? 'N/A',
            d['slot'] ?? 'N/A',
            d['status'] ?? 'N/A',
          ];
        }).where((row) => row.any((cell) => cell.toLowerCase().contains(_searchQuery))).toList();

        return _buildDataTable(
          title: "Daily Appointment Schedule",
          columns: ["Bed Name", "Patient ID", "Nurse ID", "Slot", "Status"],
          rows: data.cast<List<String>>(),
        );
      },
    );
  }

  Widget _appointmentHistoryOfPatient() {
    if (widget.userId == null) return const SizedBox();
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('appointments')
          .where('patientId', isEqualTo: widget.userId)
          .orderBy('date', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final data = snapshot.data!.docs.map((doc) {
          final d = doc.data() as Map<String, dynamic>;
          return [
            d['bedName'] ?? 'N/A',
            d['slot'] ?? 'N/A',
            d['status'] ?? 'N/A',
            (d['date'] as Timestamp).toDate().toString().split(' ')[0],
          ];
        }).where((row) => row.any((cell) => cell.toLowerCase().contains(_searchQuery))).toList();

        return _buildDataTable(
          title: "Appointment History",
          columns: ["Bed", "Slot", "Status", "Date"],
          rows: data.cast<List<String>>(),
        );
      },
    );
  }

  Widget _nurseWorkloadSummary() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('appointments').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final docs = snapshot.data!.docs;
        final Map<String, int> counts = {};
        for (var doc in docs) {
          final d = doc.data() as Map<String, dynamic>;
          final nurseId = d['nurseId'] ?? 'N/A';
          counts[nurseId] = (counts[nurseId] ?? 0) + 1;
        }
        final data = counts.entries.map((e) => [e.key, e.value.toString()]).where((row) => row.any((cell) => cell.toLowerCase().contains(_searchQuery))).toList();

        return _buildDataTable(
          title: "Nurse Workload Summary",
          columns: ["Nurse ID", "Appointment Count"],
          rows: data,
        );
      },
    );
  }

  Widget _dialysisMachineUtilization() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('beds').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final data = snapshot.data!.docs.map((doc) {
          final d = doc.data() as Map<String, dynamic>;
          return [
            d['name'] ?? 'N/A',
            d['isWorking'] == true ? 'Yes' : 'No',
            ((d['assignedPatients'] ?? []).length).toString(),
          ];
        }).where((row) => row.any((cell) => cell.toLowerCase().contains(_searchQuery))).toList();

        return _buildDataTable(
          title: "Dialysis Machine Utilization",
          columns: ["Bed Name", "Is Working", "Assigned Patients"],
          rows: data.cast<List<String>>(),
        );
      },
    );
  }

  Widget _notificationsPerPatient() {
    if (widget.userId == null) return const SizedBox();
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('notifications')
          .where('userId', isEqualTo: widget.userId)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final data = snapshot.data!.docs.map((doc) {
          final d = doc.data() as Map<String, dynamic>;
          return [
            d['title'] ?? 'N/A',
            d['message'] ?? 'N/A',
            d['isRead'] == true ? 'Read' : 'Unread',
            (d['createdAt'] as Timestamp).toDate().toString().split(' ')[0],
          ];
        }).where((row) => row.any((cell) => cell.toLowerCase().contains(_searchQuery))).toList();

        return _buildDataTable(
          title: "Notifications",
          columns: ["Title", "Message", "Status", "Date"],
          rows: data.cast<List<String>>(),
        );
      },
    );
  }

  Widget _upcomingAppointmentsPerPatient() {
    if (widget.userId == null) return const SizedBox();
    final now = DateTime.now();
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('appointments')
          .where('patientId', isEqualTo: widget.userId)
          .where('date', isGreaterThanOrEqualTo: now)
          .orderBy('date')
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final data = snapshot.data!.docs.map((doc) {
          final d = doc.data() as Map<String, dynamic>;
          return [
            d['bedName'] ?? 'N/A',
            d['slot'] ?? 'N/A',
            d['status'] ?? 'N/A',
            (d['date'] as Timestamp).toDate().toString().split(' ')[0],
          ];
        }).where((row) => row.any((cell) => cell.toLowerCase().contains(_searchQuery))).toList();

        return _buildDataTable(
          title: "Upcoming Appointments",
          columns: ["Bed", "Slot", "Status", "Date"],
          rows: data.cast<List<String>>(),
        );
      },
    );
  }

  Widget _appointmentCountByStatus() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('appointments').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final docs = snapshot.data!.docs;
        final Map<String, int> counts = {};
        for (var doc in docs) {
          final d = doc.data() as Map<String, dynamic>;
          final status = d['status'] ?? 'N/A';
          counts[status] = (counts[status] ?? 0) + 1;
        }
        final data = counts.entries.map((e) => [e.key, e.value.toString()]).where((row) => row.any((cell) => cell.toLowerCase().contains(_searchQuery))).toList();

        return _buildDataTable(
          title: "Appointment Count by Status",
          columns: ["Status", "Count"],
          rows: data,
        );
      },
    );
  }

  Widget _patientContactInformation() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('users').where('role', isEqualTo: 'patient').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final data = snapshot.data!.docs.map((doc) {
          final d = doc.data() as Map<String, dynamic>;
          return [
            d['fullName'] ?? 'N/A',
            d['username'] ?? 'N/A',
            d['email'] ?? 'N/A',
            d['contactNumber'] ?? 'N/A',
          ];
        }).where((row) => row.any((cell) => cell.toLowerCase().contains(_searchQuery))).toList();

        return _buildDataTable(
          title: "Patient Contact Information",
          columns: ["Full Name", "Username", "Email", "Contact"],
          rows: data.cast<List<String>>(),
        );
      },
    );
  }

  Widget _machineAllocationLog() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('beds').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final data = snapshot.data!.docs.map((doc) {
          final d = doc.data() as Map<String, dynamic>;
          return [
            d['name'] ?? 'N/A',
            ((d['assignedPatients'] ?? []) as List).join(', '),
            d['isWorking'] == true ? 'Yes' : 'No',
          ];
        }).where((row) => row.any((cell) => cell.toLowerCase().contains(_searchQuery))).toList();

        return _buildDataTable(
          title: "Machine Allocation Log",
          columns: ["Bed Name", "Assigned Patients", "Is Working"],
          rows: data.cast<List<String>>(),
        );
      },
    );
  }
}
