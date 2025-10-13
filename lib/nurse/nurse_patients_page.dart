import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

// Helper class to structure patient data with their status
class PatientData {
  final String id;
  final String fullName;
  final bool isVerified;
  final bool hasActiveAppointment;
  // Removed: isWalkInToday
  final Timestamp? userCreationDate;

  PatientData({
    required this.id,
    required this.fullName,
    required this.isVerified,
    required this.hasActiveAppointment,
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
  // Changed from 0 to 0 (Verified)
  int _selectedTabIndex = 0;

  // --- 1. Combined Data Fetching and Sorting (Walk-in logic removed) ---
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

      allPatients.add(PatientData(
        id: patientId,
        fullName: data['fullName'] ?? 'N/A',
        isVerified: isVerified,
        hasActiveAppointment: hasActive,
        userCreationDate: createdAt,
        // Removed: isWalkInToday flag
      ));
    }

    // Sort: Patients with NO active appointment show up first (priority for scheduling)
    allPatients.sort((a, b) => a.hasActiveAppointment == b.hasActiveAppointment
        ? a.fullName.compareTo(b.fullName) // Secondary sort by name
        : a.hasActiveAppointment ? 1 : -1);

    return allPatients;
  }

  // --- CAPACITY CHECK HELPER (Checks bed availability for a specific date/slot) ---
  Future<Map<String, int>> _fetchBedAssignmentCounts(DateTime dateData, String slotData) async {
    final DateTime dateOnly = DateTime(dateData.year, dateData.month, dateData.day);
    final Timestamp startOfDay = Timestamp.fromDate(dateOnly);
    final Timestamp endOfDay = Timestamp.fromDate(dateOnly.add(const Duration(days: 1)));

    final snap = await FirebaseFirestore.instance
        .collection('appointments')
        .where('date', isGreaterThanOrEqualTo: startOfDay)
        .where('date', isLessThan: endOfDay)
        .where('slot', isEqualTo: slotData.trim())
        .where('status', isEqualTo: 'approved')
        .get();

    final Map<String, int> bedCounts = {};

    for (var doc in snap.docs) {
      final data = doc.data() as Map<String, dynamic>? ?? {};
      final bedId = data['bedId']?.toString();

      if (bedId != null && bedId.isNotEmpty) {
        bedCounts[bedId] = (bedCounts[bedId] ?? 0) + 1;
      }
    }

    return bedCounts;
  }
  // --- END CAPACITY CHECK HELPER ---

  // --- Booking Modal / Dialog (Simplified) ---
  Future<void> _openBookingForm(
      BuildContext context, String patientId, String patientName) async {
    // Standard patients default to today
    DateTime selectedDate = DateTime.now();
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
          selectedSlot = null; // Reset slot/bed on date change
          selectedBed = null;
          selectedBedId = null;
        });
      }
    }

    Widget form = StatefulBuilder(
      builder: (context, setStateInModal) {
        // The walk-in specific display has been removed

        return DefaultTabController(
          length: 2,
          child: Scaffold(
            appBar: AppBar(
              title: Text("Schedule Appointment for $patientName"),
              backgroundColor: Colors.blue[700],
              foregroundColor: Colors.white,
            ),
            body: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("Selected Date:", style: TextStyle(fontSize: 14, color: Colors.grey)),
                          Text(
                            DateFormat('yyyy-MM-dd').format(selectedDate),
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.green[700],
                            ),
                          ),
                        ],
                      ),
                      // Allow date picking for all
                      ElevatedButton.icon(
                        onPressed: () => _pickDate(setStateInModal),
                        icon: const Icon(Icons.calendar_month, size: 18),
                        label: const Text("Change Date"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green[600],
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      )
                    ],
                  ),
                ),
                // Tab Bar for Slots and Beds
                const TabBar(
                  tabs: [Tab(text: "Slots"), Tab(text: "Beds")],
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      _buildSlotsTab(selectedDate, slots, (slot) {
                        setStateInModal(() {
                          selectedSlot = slot;
                          selectedBed = null;
                          selectedBedId = null;
                        });
                      }, selectedSlot),

                      _buildBedsTab(selectedDate, selectedSlot, (bedId, bedName) {
                        setStateInModal(() {
                          selectedBed = bedName;
                          selectedBedId = bedId;
                        });
                      }, selectedBedId),
                    ],
                  ),
                ),
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
                        "Schedule $patientName on ${DateFormat('MMM d, yyyy').format(selectedDate)} "
                            "at $selectedSlot in $selectedBed?",
                      ),
                      actions: [
                        TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: const Text("Cancel")),
                        ElevatedButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue[600], foregroundColor: Colors.white),
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
                    'createdAt': FieldValue.serverTimestamp(),
                  });

                  if (!mounted) return;
                  setState(() {}); // Force refresh to update status

                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("Appointment scheduled successfully."),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
                    : null,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  backgroundColor: Colors.blue[600],
                  foregroundColor: Colors.white,
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
          child: SizedBox(width: 700, height: 650, child: form),
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

  // --- Slots Tab (No change needed, logic is independent of walk-in) ---
  Widget _buildSlotsTab(DateTime selectedDate, List<String> slots,
      Function(String) onSelect, String? selectedSlot) {
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
              bool isSelected = selectedSlot == s;
              // int available = maxSlots - count; // available variable removed as it's not used in this scope

              final MaterialColor color = slotFull
                  ? Colors.red
                  : Colors.green;

              String statusText = slotFull ? "FULL" : "AVAILABLE";

              return Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
                child: Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                        color: isSelected ? Colors.blue[700]! : color[300]!,
                        width: isSelected ? 3 : 1
                    ),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                    leading: Icon(
                      isSelected ? Icons.check_circle : (slotFull ? Icons.cancel : Icons.check_circle_outline),
                      color: isSelected ? Colors.blue[700] : color,
                      size: 30,
                    ),
                    title: Text(s, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    subtitle: Text(
                      "Booked: $count / $maxSlots | Status: $statusText",
                      style: TextStyle(color: color[700], fontSize: 13),
                    ),
                    trailing: ElevatedButton.icon(
                      icon: const Icon(Icons.arrow_forward_ios, size: 16),
                      label: Text(isSelected ? "Selected" : "Select"),
                      onPressed: slotFull ? null : () => onSelect(s),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isSelected ? Colors.blue[700] : color[600],
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                    onTap: slotFull ? null : () => onSelect(s),
                    tileColor: isSelected ? Colors.blue.withOpacity(0.05) : null,
                  ),
                ),
              );
            }).toList(),
          );
        },
      ),
    );
  }

  // --- Beds Tab (No change needed, logic is independent of walk-in) ---
  Widget _buildBedsTab(DateTime selectedDate, String? selectedSlot,
      Function(String, String) onSelect, String? selectedBedId) {

    if (selectedSlot == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.access_time_filled, color: Colors.red[400], size: 40),
              const SizedBox(height: 16),
              const Text(
                "Slot Selection Required",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
              ),
              const SizedBox(height: 8),
              const Text(
                "Please select a **time slot** first in the 'Slots' tab to accurately check real-time bed availability for that period.",
                style: TextStyle(color: Colors.grey, fontSize: 15),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: FutureBuilder<Map<String, int>>(
        future: _fetchBedAssignmentCounts(selectedDate, selectedSlot),
        builder: (context, assignmentSnap) {
          if (assignmentSnap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final bedCounts = assignmentSnap.data ?? {};
          const int maxCapacityPerBed = 4;

          return FutureBuilder<QuerySnapshot>(
            future: FirebaseFirestore.instance
                .collection('beds')
                .where('isWorking', isEqualTo: true)
                .orderBy('name')
                .get(),
            builder: (context, bedsSnap) {
              if (bedsSnap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (!bedsSnap.hasData || bedsSnap.data!.docs.isEmpty) {
                return const Center(
                    child: Text("No working beds are registered in the system."));
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0, bottom: 16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Date: ${DateFormat('MMM d, yyyy').format(selectedDate)}", style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                        Text("Slot: $selectedSlot (Capacity: $maxCapacityPerBed/Bed)", style: TextStyle(color: Colors.grey[700], fontSize: 14)),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView(
                      children: bedsSnap.data!.docs.map((bedDoc) {
                        String bedId = bedDoc.id;
                        String bedName = (bedDoc.data() as Map<String, dynamic>)['name'] ?? 'Bed ID: $bedId';
                        final assignedCount = bedCounts[bedId] ?? 0;
                        final isFull = assignedCount >= maxCapacityPerBed;
                        final isSelected = selectedBedId == bedId;

                        final MaterialColor color = isFull ? Colors.red : Colors.green;

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8.0),
                          child: Card(
                            elevation: 1,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                              side: BorderSide(
                                  color: isSelected ? Colors.blue[700]! : Colors.transparent,
                                  width: isSelected ? 2 : 1
                              ),
                            ),
                            child: RadioListTile<String>(
                              title: Text(bedName, style: TextStyle(fontWeight: FontWeight.bold, color: isFull ? Colors.grey : Colors.black87)),
                              subtitle: Text(
                                "Assigned: $assignedCount / $maxCapacityPerBed",
                                style: TextStyle(color: color[700], fontSize: 13),
                              ),
                              value: bedId,
                              groupValue: selectedBedId,
                              onChanged: isFull ? null : (String? value) {
                                if (value != null) {
                                  onSelect(value, bedName);
                                }
                              },
                              secondary: Icon(
                                isFull ? Icons.block : Icons.bed,
                                color: isFull ? Colors.red[300] : (isSelected ? Colors.blue[700] : Colors.grey),
                              ),
                              activeColor: Colors.blue[700],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              );
            },
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

        // 2. Filter patients into only Verified and Unverified (Walk-in removed)
        final verifiedPatients = allPatients
            .where((p) => p.isVerified && p.fullName.toLowerCase().contains(searchQuery))
            .toList();

        final unverifiedPatients = allPatients
            .where((p) => !p.isVerified && p.fullName.toLowerCase().contains(searchQuery))
            .toList();

        final totalPatientsCount = allPatients.length;

        // --- Mobile Layout ---
        if (!kIsWeb) {
          // Mobile focuses on verified patients
          return _buildMobileLayout(verifiedPatients);
        }

        // --- Web Layout ---
        return DefaultTabController(
          // Only two tabs now: Verified and Unverified
          length: 2,
          initialIndex: _selectedTabIndex.clamp(0, 1), // Clamp to prevent index error
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
                // Pass 0 for the now-removed walkInCount
                _buildStatCards(verifiedPatients, unverifiedPatients, 0, totalPatientsCount),
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
                          color: Colors.blue[100],
                        ),
                        labelColor: Colors.blue[800],
                        unselectedLabelColor: Colors.black54,
                        labelStyle: const TextStyle(fontWeight: FontWeight.bold),
                        onTap: (index) => setState(() => _selectedTabIndex = index),
                        tabs: [
                          // Tab 1: Verified
                          Tab(text: "Verified (${verifiedPatients.length})"),
                          // Tab 2: Unverified
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
                      // Tab 1: Verified (Standard, long-term patients)
                      _buildPatientTable(verifiedPatients, context),
                      // Tab 2: Unverified (Cannot be scheduled)
                      _buildPatientTable(unverifiedPatients, context),
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

  // Refactored Table to handle ONLY Verified and Unverified
  Widget _buildPatientTable(
      List<PatientData> patients, BuildContext context) {
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
          // Table Header
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
                final MaterialColor statusColor;

                // SIMPLIFIED STATUS LOGIC
                if (!patient.isVerified) {
                  statusText = "UNVERIFIED (No Schedule)";
                  statusColor = Colors.red;
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
                              // SIMPLIFIED AVATAR COLOR/ICON
                              backgroundColor: patient.isVerified ? Colors.blueAccent : Colors.redAccent,
                              child: const Icon(Icons.person_outline, color: Colors.white, size: 20),
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
                            color: statusColor[100],
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            statusText,
                            style: TextStyle(
                              color: statusColor[900],
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
                            // REMOVED WALK-IN ARGUMENT
                            _openBookingForm(context, patientId, patientName),
                            style: ElevatedButton.styleFrom(
                              // SIMPLIFIED BUTTON COLOR
                              backgroundColor: isSchedulingDisabled ? Colors.grey[400] : Colors.blue[600],
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
    // walkInCount is now 0
    final int scheduledCount = verified.where((p) => p.hasActiveAppointment).length;
    final int readyToScheduleCount = verified.length - scheduledCount;

    return Row(
      children: [
        _buildStatCard(
            "Total Patients",
            Icons.group,
            Colors.blue,
            totalCount.toString()),
        // REMOVED WALK-IN CARD
        _buildStatCard(
            "Scheduled Sessions",
            Icons.calendar_month,
            Colors.green,
            scheduledCount.toString()),
        _buildStatCard(
            "Ready to Schedule",
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

  // --- Mobile Layout (Simplified) ---
  Widget _buildMobileLayout(List<PatientData> patients) {
    // Only verified patients are passed to this view
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
                ? Center(child: Text(searchQuery.isNotEmpty ? "No verified patients match '$searchQuery'." : "No verified patients found."))
                : ListView.separated(
              itemCount: patientData.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final patient = patientData[index];
                final patientName = patient.fullName;
                final patientId = patient.id;
                final hasActive = patient.hasActiveAppointment;

                final bool isSchedulingDisabled = hasActive || !patient.isVerified;
                // Removed: isWalkIn logic

                return Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  child: ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: Colors.blueAccent, // Simplified color
                      child: Icon(Icons.person, color: Colors.white),
                    ),
                    title: Text(patientName, style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text(hasActive ? "Booked" : "Ready to Schedule"), // Simplified subtitle
                    trailing: ElevatedButton(
                      onPressed: isSchedulingDisabled
                          ? null
                          : () =>
                      // REMOVED WALK-IN ARGUMENT
                      _openBookingForm(context, patientId, patientName),
                      child: Text(hasActive ? "Booked" : "Schedule"),
                      style: ElevatedButton.styleFrom(
                        // SIMPLIFIED BUTTON COLOR
                        backgroundColor: isSchedulingDisabled ? Colors.grey : Colors.blue,
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