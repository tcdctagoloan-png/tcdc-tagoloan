// nurse_patients_page.dart
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// Helper class to structure patient data with their status
class PatientData {
  final String id;
  final String fullName;
  final bool isVerified;
  final bool hasActiveAppointment;
  // New flag to identify patients added as walk-in today
  final bool isWalkInToday;
  final Timestamp? userCreationDate;

  PatientData({
    required this.id,
    required this.fullName,
    required this.isVerified,
    required this.hasActiveAppointment,
    this.isWalkInToday = false,
    this.userCreationDate,
  });
}

class NursePatientsPage extends StatefulWidget {
  final String nurseId;
  const NursePatientsPage({super.key, required this.nurseId});

  @override
  State<NursePatientsPage> createState() => _NursePatientsPageState();
}

class _NursePatientsPageState extends State<NursePatientsPage> {
  final List<String> slots = [
    "06:00 - 10:00",
    "10:00 - 14:00",
    "14:00 - 18:00",
    "18:00 - 22:00"
  ];
  String searchQuery = "";
  int _selectedTabIndex = 0;

  // Define the boundary for "Walk-in Today"
  final DateTime _todayStart = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);

  // --- 1. Combined Data Fetching and Sorting (Single Source of Truth) ---
  Future<List<PatientData>> _fetchAllPatientData() async {
    // 1. Fetch all patients (Filtered to 'patient' role)
    final userSnap = await FirebaseFirestore.instance
        .collection('users')
        .where('role', isEqualTo: 'patient')
        .get();

    // 2. Fetch all active appointments in one query
    final apptSnap = await FirebaseFirestore.instance
        .collection('appointments')
        .where('status', whereIn: ['pending', 'approved', 'rescheduled'])
        .get();

    // Create a set of patient IDs who have an active appointment for quick lookup
    final Set<String> activePatientIds = apptSnap.docs
        .map((doc) => doc.data()['patientId'] as String)
        .toSet();

    List<PatientData> allPatients = [];
    for (var doc in userSnap.docs) {
      final data = doc.data() as Map<String, dynamic>;
      final patientId = doc.id;
      final hasActive = activePatientIds.contains(patientId);
      final isVerified = data['verified'] == true;
      final createdAt = data['createdAt'] as Timestamp?;

      // Determine if they are a 'Walk-in Today'
      bool isWalkInToday = false;
      if (isVerified && createdAt != null) {
        final dateAdded = createdAt.toDate();
        // If patient was verified and added today, treat as a Walk-in for the nurse's flow.
        if (dateAdded.isAfter(_todayStart)) {
          isWalkInToday = true;
        }
      }

      allPatients.add(PatientData(
        id: patientId,
        fullName: data['fullName'] ?? 'N/A',
        isVerified: isVerified,
        hasActiveAppointment: hasActive,
        isWalkInToday: isWalkInToday,
        userCreationDate: createdAt,
      ));
    }

    // Sort: Patients with NO active appointment show up first (priority for scheduling)
    allPatients.sort((a, b) => a.hasActiveAppointment == b.hasActiveAppointment
        ? a.fullName.compareTo(b.fullName) // Secondary sort by name
        : a.hasActiveAppointment ? 1 : -1);

    return allPatients;
  }

  // --- Booking Modal / Dialog (UPDATED: Handles Walk-in auto-date setting) ---
  Future<void> _openBookingForm(
      BuildContext context, String patientId, String patientName, bool isWalkIn) async {
    // Walk-in patients are scheduled for today, others default to today but can pick.
    DateTime selectedDate = isWalkIn ? DateTime.now() : DateTime.now();
    String? selectedSlot;
    String? selectedBed;
    String? selectedBedId;

    Future<void> _pickDate(StateSetter setStateInModal) async {
      final DateTime? picked = await showDatePicker(
        context: context,
        initialDate: selectedDate,
        firstDate: DateTime.now(),
        lastDate: DateTime.now().add(const Duration(days: 365)),
      );
      if (picked != null && picked != selectedDate) {
        setStateInModal(() {
          selectedDate = picked;
          selectedSlot = null;
          selectedBed = null;
          selectedBedId = null;
        });
      }
    }

    Widget form = StatefulBuilder(
      builder: (context, setStateInModal) {
        return DefaultTabController(
          length: 2,
          child: Scaffold(
            appBar: AppBar(
              title: Text("Schedule Appointment for $patientName"),
              actions: [
                // Hide date picker if it's a walk-in patient (scheduled for today)
                if (!isWalkIn)
                  TextButton.icon(
                    onPressed: () => _pickDate(setStateInModal),
                    icon: const Icon(Icons.calendar_month, color: Colors.white),
                    label: Text(
                      selectedDate.toLocal().toString().split(' ')[0],
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  )
                else
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Center(
                      child: Text(
                        "Date: ${selectedDate.toLocal().toString().split(' ')[0]} (Walk-in)",
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                const SizedBox(width: 8),
              ],
              bottom: const TabBar(
                tabs: [Tab(text: "Slots"), Tab(text: "Beds")],
              ),
            ),
            body: TabBarView(
              children: [
                _buildSlotsTab(selectedDate, slots, (slot) {
                  setStateInModal(() => selectedSlot = slot);
                }, selectedSlot),
                _buildBedsTab(selectedDate, (bedId, bedName) {
                  setStateInModal(() {
                    selectedBed = bedName;
                    selectedBedId = bedId;
                  });
                }, selectedBedId),
              ],
            ),
            bottomNavigationBar: Padding(
              padding: const EdgeInsets.all(16),
              child: ElevatedButton(
                onPressed: (selectedSlot != null &&
                    selectedBed != null &&
                    selectedBedId != null)
                    ? () async {
                  bool confirm = await showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text("Confirm Schedule"),
                      content: Text(
                        "Schedule $patientName on ${selectedDate.toLocal().toString().split(' ')[0]} "
                            "at $selectedSlot in $selectedBed?",
                      ),
                      actions: [
                        TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: const Text("Cancel")),
                        ElevatedButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            child: const Text("Confirm")),
                      ],
                    ),
                  ) ??
                      false;

                  if (!confirm) return;

                  // --- Appointment Creation ---
                  await FirebaseFirestore.instance
                      .collection('appointments')
                      .add({
                    'patientId': patientId,
                    'nurseId': widget.nurseId,
                    'date': Timestamp.fromDate(selectedDate),
                    'slot': selectedSlot,
                    'bedId': selectedBedId,
                    'bedName': selectedBed,
                    'status': 'approved',
                    'isWalkIn': isWalkIn, // Mark appointment as walk-in
                    'createdAt': FieldValue.serverTimestamp(),
                  });

                  if (!mounted) return;
                  setState(() {}); // Force refresh to update status

                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("Appointment scheduled successfully."),
                    ),
                  );
                }
                    : null,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text("Confirm Appointment"),
              ),
            ),
          ),
        );
      },
    );

    if (kIsWeb) {
      await showDialog(
        context: context,
        builder: (ctx) => Dialog(
          insetPadding: const EdgeInsets.all(32),
          child: SizedBox(width: 700, height: 600, child: form),
        ),
      );
    } else {
      await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        builder: (ctx) => SizedBox(
          height: MediaQuery.of(ctx).size.height * 0.95,
          child: form,
        ),
      );
    }
  }

  // --- Slots Tab (Kept the logic) ---
  Widget _buildSlotsTab(DateTime selectedDate, List<String> slots,
      Function(String) onSelect, String? selectedSlot) {
    // ... (Slot logic remains the same, checking for availability on selectedDate)
    return Padding(
      padding: const EdgeInsets.all(16),
      child: FutureBuilder<QuerySnapshot>(
        future: FirebaseFirestore.instance
            .collection('appointments')
            .where(
          'date',
          isGreaterThanOrEqualTo: Timestamp.fromDate(
            DateTime(selectedDate.year, selectedDate.month, selectedDate.day),
          ),
        )
            .where(
          'date',
          isLessThan: Timestamp.fromDate(
            DateTime(selectedDate.year, selectedDate.month, selectedDate.day)
                .add(const Duration(days: 1)),
          ),
        )
            .where('status', whereIn: ['pending', 'approved', 'rescheduled'])
            .get(),
        builder: (context, apptSnap) {
          if (apptSnap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!apptSnap.hasData) {
            return const Center(child: Text("No slot data available."));
          }

          const int maxSlots = 16;
          Map<String, int> slotCounts = {for (var s in slots) s: 0};
          for (var doc in apptSnap.data!.docs) {
            final data = doc.data() as Map<String, dynamic>;
            final bookedSlot =
            data.containsKey('slot') ? data['slot'] as String : null;
            if (bookedSlot != null && slotCounts.containsKey(bookedSlot)) {
              slotCounts[bookedSlot] = slotCounts[bookedSlot]! + 1;
            }
          }

          return ListView(
            children: slots.map((s) {
              int count = slotCounts[s] ?? 0;
              bool slotFull = count >= maxSlots;

              Color color = slotFull
                  ? Colors.red
                  : count >= maxSlots * 0.5
                  ? Colors.orange
                  : Colors.green;

              return Card(
                elevation: 1,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                child: ListTile(
                  title: Text(s, style: const TextStyle(fontWeight: FontWeight.w500)),
                  trailing: Text(
                    "$count/$maxSlots",
                    style: TextStyle(color: color, fontWeight: FontWeight.bold),
                  ),
                  tileColor:
                  selectedSlot == s ? Colors.blue.withOpacity(0.1) : null,
                  onTap: slotFull ? null : () => onSelect(s),
                ),
              );
            }).toList(),
          );
        },
      ),
    );
  }

  // --- Beds Tab (Kept the logic) ---
  Widget _buildBedsTab(DateTime selectedDate,
      Function(String, String) onSelect, String? selectedBedId) {
    // ... (Bed logic remains the same)
    return Padding(
      padding: const EdgeInsets.all(16),
      child: FutureBuilder<QuerySnapshot>(
        future: FirebaseFirestore.instance
            .collection('beds')
            .where('isWorking', isEqualTo: true)
            .where('assignedPatient', isEqualTo: '')
            .orderBy('name')
            .get(),
        builder: (context, bedsSnap) {
          if (bedsSnap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!bedsSnap.hasData || bedsSnap.data!.docs.isEmpty) {
            return const Center(
                child: Text("No available beds at this moment."));
          }

          return ListView(
            children: bedsSnap.data!.docs.map((bedDoc) {
              String bedId = bedDoc.id;
              String bedName = bedDoc['name'];
              return Card(
                elevation: 1,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                child: ListTile(
                  title: Text(bedName, style: const TextStyle(fontWeight: FontWeight.w500)),
                  leading: Icon(Icons.bed, color: selectedBedId == bedId ? Colors.blue : Colors.grey),
                  tileColor: selectedBedId == bedId
                      ? Colors.blue.withOpacity(0.1)
                      : null,
                  onTap: () => onSelect(bedId, bedName),
                ),
              );
            }).toList(),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<PatientData>>(
      future: _fetchAllPatientData(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: Text("No patient data found."));
        }

        final allPatients = snapshot.data!;

        // 3. Filter patients based on search and status
        final walkInTodayPatients = allPatients
            .where((p) => p.isWalkInToday && p.fullName.toLowerCase().contains(searchQuery))
            .toList();

        final verifiedPatients = allPatients
            .where((p) => p.isVerified && !p.isWalkInToday && p.fullName.toLowerCase().contains(searchQuery))
            .toList();

        final unverifiedPatients = allPatients
            .where((p) => !p.isVerified && p.fullName.toLowerCase().contains(searchQuery))
            .toList();

        final totalPatientsCount = allPatients.length;

        // --- Mobile Layout ---
        if (!kIsWeb) {
          // Mobile focuses on immediate scheduling (Walk-in and Verified)
          final mobilePatients = [...walkInTodayPatients, ...verifiedPatients]
              .where((p) => p.fullName.toLowerCase().contains(searchQuery))
              .toList();

          return _buildMobileLayout(mobilePatients);
        }

        // --- Web Layout ---
        return DefaultTabController(
          length: 3,
          initialIndex: _selectedTabIndex,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Patient Management Dashboard",
                  style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87),
                ),
                const SizedBox(height: 16),
                _buildStatCards(verifiedPatients, unverifiedPatients, walkInTodayPatients.length, totalPatientsCount),
                const SizedBox(height: 24),

                // Search bar and Tabs
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextField(
                        decoration: InputDecoration(
                          hintText: "Search patient by name...",
                          prefixIcon: const Icon(Icons.search),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          filled: true,
                          fillColor: Colors.grey.shade100,
                        ),
                        onChanged: (val) =>
                            setState(() => searchQuery = val.toLowerCase()),
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      flex: 3,
                      child: TabBar(
                        indicatorSize: TabBarIndicatorSize.label,
                        indicator: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          color: Colors.blue.shade100,
                        ),
                        labelColor: Colors.blue.shade800,
                        unselectedLabelColor: Colors.black54,
                        labelStyle: const TextStyle(fontWeight: FontWeight.bold),
                        onTap: (index) => setState(() => _selectedTabIndex = index),
                        tabs: [
                          Tab(text: "Walk-in Today (${walkInTodayPatients.length})"),
                          Tab(text: "Verified (${verifiedPatients.length})"),
                          Tab(text: "Unverified (${unverifiedPatients.length})"),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Tab Bar View (Patient Table)
                Expanded(
                  child: TabBarView(
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      // Tab 1: Walk-in Today
                      _buildPatientTable(walkInTodayPatients, context, isWalkInTab: true),
                      // Tab 2: Verified (Standard, long-term patients)
                      _buildPatientTable(verifiedPatients, context, isWalkInTab: false),
                      // Tab 3: Unverified (Cannot be scheduled)
                      _buildPatientTable(unverifiedPatients, context, isWalkInTab: false),
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

  // --- Web Layout Components ---

  // Refactored Table to handle Walk-in and Scheduling logic
  Widget _buildPatientTable(
      List<PatientData> patients, BuildContext context, {required bool isWalkInTab}) {
    if (patients.isEmpty) {
      return Center(
        child: Text(
          searchQuery.isNotEmpty
              ? "No patients match your search."
              : "No patients in this category.",
          style: const TextStyle(fontSize: 16, color: Colors.grey),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              spreadRadius: 1,
              blurRadius: 10,
              offset: const Offset(0, 3)),
        ],
      ),
      child: Column(
        children: [
          // Table Header (Kept the same)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
            decoration: const BoxDecoration(
              color: Color(0xFFF8F9FA),
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              border: Border(
                  bottom: BorderSide(color: Colors.black12, width: 1)),
            ),
            child: Row(
              children: const [
                Expanded(
                    flex: 2,
                    child: Text("PATIENT NAME",
                        style: TextStyle(
                            fontWeight: FontWeight.bold, color: Colors.black54))),
                Expanded(
                    flex: 2,
                    child: Text("APPOINTMENT STATUS",
                        style: TextStyle(
                            fontWeight: FontWeight.bold, color: Colors.black54))),
                Expanded(
                    flex: 1,
                    child: Text("ACTION",
                        textAlign: TextAlign.right,
                        style: TextStyle(
                            fontWeight: FontWeight.bold, color: Colors.black54))),
              ],
            ),
          ),
          // Table Rows
          Expanded(
            child: ListView.separated(
              itemCount: patients.length,
              separatorBuilder: (_, __) =>
              const Divider(height: 1, color: Colors.black12),
              itemBuilder: (context, index) {
                final patient = patients[index];
                final patientName = patient.fullName;
                final patientId = patient.id;
                final hasActive = patient.hasActiveAppointment;

                // Scheduling is disabled if:
                // 1. Patient already has an active appointment (hasActive == true)
                // 2. Patient is not verified (isVerified == false)
                final bool isSchedulingDisabled = hasActive || !patient.isVerified;

                String statusText;
                // FIX: Define the statusColor explicitly as a MaterialColor
                final MaterialColor statusColor;

                if (!patient.isVerified) {
                  statusText = "UNVERIFIED (No Schedule)";
                  statusColor = Colors.red;
                } else if (patient.isWalkInToday) {
                  statusText = hasActive ? "WALK-IN BOOKED TODAY" : "WALK-IN READY";
                  statusColor = hasActive ? Colors.green : Colors.purple;
                } else {
                  statusText = hasActive ? "BOOKED" : "NO APPOINTMENT";
                  statusColor = hasActive ? Colors.green : Colors.orange;
                }


                return Padding(
                  padding:
                  const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: patient.isWalkInToday ? Colors.purple : (patient.isVerified ? Colors.blueAccent : Colors.redAccent),
                              child: Icon(patient.isWalkInToday ? Icons.directions_walk : Icons.person_outline, color: Colors.white, size: 20),
                            ),
                            const SizedBox(width: 12),
                            Text(patientName,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            // This now correctly uses the MaterialColor property:
                            color: statusColor.shade100,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            statusText,
                            style: TextStyle(
                              // This now correctly uses the MaterialColor property:
                              color: statusColor.shade900,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 1,
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: ElevatedButton.icon(
                            icon: Icon(isSchedulingDisabled ? Icons.block : Icons.add_circle_outline, size: 18),
                            label: Text(hasActive ? "Booked" : "Schedule"),
                            onPressed: isSchedulingDisabled
                                ? null
                                : () =>
                                _openBookingForm(context, patientId, patientName, patient.isWalkInToday),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isSchedulingDisabled ? Colors.grey.shade400 : (patient.isWalkInToday ? Colors.purple.shade600 : Colors.blue.shade600),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8)),
                              padding: const EdgeInsets.symmetric(
                                  vertical: 12, horizontal: 16),
                              elevation: 2,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCards(List<PatientData> verified, List<PatientData> unverified, int walkInCount, int totalCount) {
    final int scheduledCount = verified.where((p) => p.hasActiveAppointment).length + walkInCount;
    final int readyToScheduleCount = verified.length - verified.where((p) => p.hasActiveAppointment).length;

    return Row(
      children: [
        _buildStatCard(
            "Total Patients",
            Icons.group,
            Colors.blue,
            totalCount.toString()),
        _buildStatCard(
            "Walk-in Today",
            Icons.directions_walk,
            Colors.purple,
            walkInCount.toString()),
        _buildStatCard(
            "Verified Ready",
            Icons.pending_actions,
            Colors.orange,
            readyToScheduleCount.toString()),
        _buildStatCard(
            "Pending Verification",
            Icons.person_off,
            Colors.redAccent,
            unverified.length.toString()),
      ],
    );
  }

  Widget _buildStatCard(
      String title, IconData icon, Color color, String value) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
                color: Colors.black12,
                blurRadius: 6,
                offset: const Offset(0, 3)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              backgroundColor: color.withOpacity(0.1),
              child: Icon(icon, color: color),
            ),
            const SizedBox(height: 16),
            Text(title, style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.black87)),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                  fontSize: 24, fontWeight: FontWeight.bold, color: color),
            ),
          ],
        ),
      ),
    );
  }

  // --- Mobile Layout (Simplified to combine walk-in and verified) ---
  Widget _buildMobileLayout(List<PatientData> patients) {
    final patientData = patients
        .where((p) => p.fullName.toLowerCase().contains(searchQuery))
        .toList();

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          TextField(
            decoration: InputDecoration(
              hintText: "Search Patient...",
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor: Colors.grey.shade100,
            ),
            onChanged: (val) =>
                setState(() => searchQuery = val.toLowerCase()),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: patientData.isEmpty
                ? Center(child: Text(searchQuery.isNotEmpty ? "No patients match '$searchQuery'." : "No verified patients found."))
                : ListView.separated(
              itemCount: patientData.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final patient = patientData[index];
                final patientName = patient.fullName;
                final patientId = patient.id;
                final hasActive = patient.hasActiveAppointment;

                final bool isSchedulingDisabled = hasActive || !patient.isVerified;
                final bool isWalkIn = patient.isWalkInToday;

                return Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: isWalkIn ? Colors.purple : Colors.blueAccent,
                      child: Icon(isWalkIn ? Icons.directions_walk : Icons.person, color: Colors.white),
                    ),
                    title: Text(patientName, style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text(isWalkIn
                        ? (hasActive ? "Walk-in Booked Today" : "Walk-in Ready")
                        : (hasActive ? "Booked" : "Ready to Schedule")),
                    trailing: ElevatedButton(
                      onPressed: isSchedulingDisabled
                          ? null
                          : () =>
                          _openBookingForm(context, patientId, patientName, isWalkIn),
                      child: Text(hasActive ? "Booked" : "Schedule"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isSchedulingDisabled ? Colors.grey : (isWalkIn ? Colors.purple : Colors.blue),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}