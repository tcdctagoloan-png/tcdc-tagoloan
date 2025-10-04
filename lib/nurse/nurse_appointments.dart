import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

// -----------------------------------------------------------------
// 1. HELPER CLASSES AND FUNCTIONS (OUTSIDE STATE CLASS)
// -----------------------------------------------------------------

class _AppointmentStats {
  final int total;
  final int pending;
  final int approved;
  final int rescheduled;
  final int rejected;
  final int completed;

  _AppointmentStats({
    required this.total,
    required this.pending,
    required this.approved,
    required this.rescheduled,
    required this.rejected,
    required this.completed,
  });
}

Future<_AppointmentStats> _fetchAppointmentStats() async {
  final snap = await FirebaseFirestore.instance
      .collection('appointments')
      .where('status', isNotEqualTo: 'removed')
      .get();

  final docs = snap.docs;
  int pending = 0;
  int approved = 0;
  int rescheduled = 0;
  int rejected = 0;
  int completed = 0;
  int total = 0;

  for (var doc in docs) {
    // FIX 1: Safely retrieve data as Map, defaulting to empty map if null
    final data = doc.data() as Map<String, dynamic>? ?? {};
    final status = data['status']?.toString().toLowerCase() ?? '';

    if (status != 'removed') {
      total++;
    }

    switch (status) {
      case 'pending':
        pending++;
        break;
      case 'approved':
        approved++;
        break;
      case 'rescheduled':
        rescheduled++;
        break;
      case 'rejected':
        rejected++;
        break;
      case 'completed':
        completed++;
        break;
      default:
        break;
    }
  }

  return _AppointmentStats(
    total: total,
    pending: pending,
    approved: approved,
    rescheduled: rescheduled,
    rejected: rejected,
    completed: completed,
  );
}

// -----------------------------------------------------------------
// 2. MAIN WIDGET
// -----------------------------------------------------------------

class NurseAppointmentsPage extends StatefulWidget {
  final String nurseId;
  const NurseAppointmentsPage({super.key, required this.nurseId});

  @override
  State<NurseAppointmentsPage> createState() => _NurseAppointmentsPageState();
}

class _NurseAppointmentsPageState extends State<NurseAppointmentsPage> {
  String _searchQuery = "";
  final Map<String, String> _patientNamesCache = {};
  String _selectedStatusFilter = "All";

  // --- Bed & Slot selection state for dialogs ---
  String? _selectedBedId;
  DateTime? _rescheduleDate;
  String? _rescheduleSlot;

  // FIX: Synchronized slots with patient's BookPage
  final List<String> _slots = [
    "06:00 - 10:00",
    "10:00 - 14:00",
    "14:00 - 18:00",
    "18:00 - 22:00"
  ];


  bool _isWideScreen(BuildContext context) => MediaQuery.of(context).size.width >= 900;

  Color _getStatusColor(String status) {
    switch(status.toLowerCase()) {
      case 'approved':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'rejected':
      case 'removed':
        return Colors.red;
      case 'rescheduled':
        return Colors.blue;
      case 'completed':
        return Colors.teal;
      default:
        return Colors.black;
    }
  }

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;

    bool isWideScreen = _isWideScreen(context);

    Future.delayed(const Duration(milliseconds: 100), () {
      if (!mounted) return;
      if (isWideScreen) {
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
        final snackBar = SnackBar(
          content: Text(message),
          backgroundColor: isError ? Colors.red : Colors.green,
        );
        ScaffoldMessenger.of(context).showSnackBar(snackBar);
      }
    });
  }

  Future<String> _getPatientName(String uid) async {
    if (_patientNamesCache.containsKey(uid)) {
      return _patientNamesCache[uid]!;
    }
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      // FIX 2: Use null-aware access for safety
      final name = doc.data()?['fullName'] ?? "Unknown";
      _patientNamesCache[uid] = name;
      return name;
    } catch (_) {
      _patientNamesCache[uid] = "Unknown";
      return "Unknown";
    }
  }

  String _getPatientNameSync(String uid) {
    return _patientNamesCache[uid] ?? "Unknown";
  }

  @override
  void initState() {
    super.initState();
    _preloadAllPatientNames();
  }

  Future<void> _preloadAllPatientNames() async {
    try {
      final appointmentsSnap = await FirebaseFirestore.instance
          .collection('appointments')
          .get();

      final Set<String> patientIds = appointmentsSnap.docs
          .map((doc) => doc.data()?['patientId'] as String?) // Added ? for data()
          .where((id) => id != null)
          .toSet()
          .cast<String>();

      if (patientIds.isEmpty) return;

      for (String id in patientIds) {
        if (!_patientNamesCache.containsKey(id)) {
          final doc = await FirebaseFirestore.instance.collection('users').doc(id).get();
          // FIX 3: Use null-aware access for safety
          final name = doc.data()?['fullName'] ?? "Unknown";
          _patientNamesCache[id] = name;
        }
      }
      if (mounted) setState(() {});
    } catch (e) {
      print("Error pre-loading patient names: $e");
    }
  }


  Future<void> _updateStatus(
      String appointmentId,
      String status, {
        String? bedId,
        Timestamp? date,
        String? slot,
      }) async {
    final firestore = FirebaseFirestore.instance;

    try {
      final beforeSnap = await firestore.collection('appointments').doc(appointmentId).get();
      // FIX 4: Safely access data map
      final beforeData = beforeSnap.data() as Map<String, dynamic>? ?? {};
      final String patientId = beforeData['patientId'] ?? '';
      final String? oldBedId = beforeData['bedId'];

      Map<String, dynamic> updateData = {
        'status': status,
        'nurseId': widget.nurseId,
      };
      if (bedId != null) updateData['bedId'] = bedId;
      if (date != null) updateData['date'] = date;
      if (slot != null) updateData['slot'] = slot;

      if (bedId != null && status == 'approved') {
        final bedDoc = await firestore.collection('beds').doc(bedId).get();
        // FIX 5: Safely check and access bed data
        updateData['bedName'] = bedDoc.data()?['name'] ?? 'a bed';
      } else if (status != 'approved' && oldBedId != null && oldBedId.isNotEmpty) {
        // Clear bed assignment if rejecting/rescheduling/completing/removing
        updateData.remove('bedId');
        updateData.remove('bedName');
      }


      await firestore.collection('appointments').doc(appointmentId).update(updateData);

      // Sync patient assignment with beds
      try {
        // Remove patient from old bed
        if (oldBedId != null && oldBedId.isNotEmpty && oldBedId != bedId) {
          await firestore.collection('beds').doc(oldBedId).update({
            'assignedPatients': FieldValue.arrayRemove([patientId]),
          });
        }

        // Add patient to new bed if approved
        if (status == 'approved' && bedId != null) {
          await firestore.collection('beds').doc(bedId).update({
            'assignedPatients': FieldValue.arrayUnion([patientId]),
          });
        }
      } catch (e) {
        print("Error updating bed status: $e");
      }

      final updatedDoc = await firestore.collection('appointments').doc(appointmentId).get();
      // FIX 6: Safely access data for notification message
      final updatedData = updatedDoc.data() as Map<String, dynamic>? ?? {};
      final updatedPatientId = updatedData['patientId'];
      String notificationMessage = "";

      switch (status) {
        case "approved":
          notificationMessage = "✅ Your appointment has been approved. You have been assigned to bed ${updatedData['bedName'] ?? 'a bed'}.";
          break;
        case "rejected":
          notificationMessage = "❌ Your appointment has been rejected. Please schedule a new one.";
          break;
        case "completed":
          notificationMessage = "🎉 Your appointment has been marked as completed. Thank you for using our service.";
          break;
        case "rescheduled":
          final newDate = date != null ? DateFormat('MMM d, yyyy').format(date.toDate()) : 'a new date';
          notificationMessage = "📅 Your appointment has been rescheduled to $newDate, Slot: ${slot ?? 'N/A'}. Please check the new details.";
          break;
        case "removed":
          notificationMessage = "🗑 Your appointment has been removed. Please contact the clinic for more information.";
          break;
        default:
          notificationMessage = "📅 Your appointment status changed to $status.";
      }

      await firestore.collection('notifications').add({
        'title': "Appointment Update",
        'message': notificationMessage,
        'userId': updatedPatientId,
        'appointmentId': appointmentId,
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
        'type': 'patient',
      });
      if (!mounted) return;
      _showMessage("Appointment status updated to $status");
      setState(() {});
    } catch (e) {
      _showMessage("Failed to update status: $e", isError: true);
    }
  }

  // --- CAPACITY CHECK HELPER ---
  Future<Map<String, int>> _fetchBedAssignmentCounts(dynamic dateData, dynamic slotData) async {
    if (dateData is! Timestamp || slotData is! String) {
      return {};
    }

    // Ensure the timestamp is for the start of the day for consistent query
    final DateTime dateOnly = DateTime(dateData.toDate().year, dateData.toDate().month, dateData.toDate().day);
    final Timestamp startOfDay = Timestamp.fromDate(dateOnly);
    final Timestamp endOfDay = Timestamp.fromDate(dateOnly.add(const Duration(days: 1)));

    final snap = await FirebaseFirestore.instance
        .collection('appointments')
        .where('date', isGreaterThanOrEqualTo: startOfDay)
        .where('date', isLessThan: endOfDay)
        .where('slot', isEqualTo: slotData)
        .where('status', isEqualTo: 'approved') // Only count approved assignments
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


  // --- ACTION DIALOGS (Implemented) ---

  Future<void> _approveWithBed(BuildContext context, String appointmentId, dynamic dateData, dynamic slotData) async {
    _selectedBedId = null; // Reset selection

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateSB) {
          return AlertDialog(
            title: const Text("Select Bed for Appointment"),
            content: SizedBox(
              width: _isWideScreen(context) ? 400 : double.maxFinite,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Date: ${dateData is Timestamp ? DateFormat('MMM d, yyyy').format(dateData.toDate()) : 'N/A'}"),
                    Text("Slot: ${slotData ?? 'N/A'}"),
                    const Divider(),
                    const Text("Available Beds (Capacity: 4/Bed):", style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),

                    FutureBuilder<Map<String, int>>( // Fetches {bedId: count}
                      future: _fetchBedAssignmentCounts(dateData, slotData),
                      builder: (context, assignmentSnap) {
                        if (assignmentSnap.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator());
                        }

                        final bedCounts = assignmentSnap.data ?? {};

                        return FutureBuilder<QuerySnapshot>(
                          // Fetch all beds
                          future: FirebaseFirestore.instance.collection('beds').get(),
                          builder: (context, bedSnap) {
                            if (bedSnap.connectionState == ConnectionState.waiting) {
                              return const Center(child: CircularProgressIndicator());
                            }
                            if (!bedSnap.hasData || bedSnap.data!.docs.isEmpty) {
                              return const Text("No beds found.", style: TextStyle(color: Colors.red));
                            }

                            final beds = bedSnap.data!.docs;

                            return Column(
                              children: beds.map((doc) {
                                final bedId = doc.id;
                                // FIX 7: Safe data retrieval inside FutureBuilder
                                final bedData = doc.data() as Map<String, dynamic>? ?? {};
                                final bedName = bedData['name'] ?? 'Bed ID: $bedId';
                                final assignedCount = bedCounts[bedId] ?? 0;

                                // CAPACITY CHECK
                                final isFull = assignedCount >= 4;

                                return RadioListTile<String>(
                                  title: Text(bedName),
                                  subtitle: Text(
                                    "Assigned: $assignedCount / 4",
                                    style: TextStyle(color: isFull ? Colors.red : Colors.green),
                                  ),
                                  value: bedId,
                                  groupValue: _selectedBedId,
                                  // Disable if the bed is full
                                  onChanged: isFull ? null : (value) {
                                    setStateSB(() {
                                      _selectedBedId = value;
                                    });
                                  },
                                  dense: true,
                                );
                              }).toList(),
                            );
                          },
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel")),
              FutureBuilder<Map<String, int>>(
                  future: _fetchBedAssignmentCounts(dateData, slotData),
                  builder: (context, assignmentSnap) {
                    final bedCounts = assignmentSnap.data ?? {};
                    final isButtonEnabled = _selectedBedId != null && (bedCounts[_selectedBedId] ?? 0) < 4;

                    return ElevatedButton(
                      onPressed: isButtonEnabled
                          ? () => Navigator.pop(ctx, true)
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text("Approve"),
                    );
                  }
              ),
            ],
          );
        },
      ),
    );

    if (confirmed == true && _selectedBedId != null) {
      await _updateStatus(appointmentId, "approved", bedId: _selectedBedId);
    }
  }

  Future<void> _rescheduleAppointment(
      BuildContext context,
      String appointmentId,
      String patientId,
      String patientName,
      dynamic oldDateData,
      String? oldSlot,
      String? oldBedId,
      ) async {
    // Initialize with current values
    _rescheduleDate = oldDateData is Timestamp ? oldDateData.toDate() : DateTime.now();
    _rescheduleSlot = oldSlot?.trim();
    _selectedBedId = oldBedId;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateSB) {
          return AlertDialog(
            title: Text("Reschedule and Assign Bed for $patientName"),
            content: SizedBox(
              width: _isWideScreen(context) ? 600 : double.maxFinite,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // --- Date Picker ---
                    ListTile(
                      leading: const Icon(Icons.date_range),
                      title: Text("Date: ${DateFormat('MMM d, yyyy').format(_rescheduleDate!)}"),
                      trailing: const Icon(Icons.edit),
                      onTap: () async {
                        final newDate = await showDatePicker(
                          context: context,
                          initialDate: _rescheduleDate ?? DateTime.now(),
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(const Duration(days: 365)),
                        );
                        if (newDate != null) {
                          setStateSB(() {
                            _rescheduleDate = newDate;
                            _selectedBedId = null; // reset bed when date changes
                          });
                        }
                      },
                    ),
                    const Divider(),

                    // --- Slot Dropdown ---
                    DropdownButtonFormField<String>(
                      decoration: const InputDecoration(
                        labelText: "Select Slot",
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      ),
                      value: _rescheduleSlot,
                      hint: const Text("Select new time slot"),
                      items: _slots.map((String slot) {
                        return DropdownMenuItem<String>(
                          value: slot.trim(),
                          child: Text(slot),
                        );
                      }).toList(),
                      onChanged: (String? newValue) {
                        setStateSB(() {
                          _rescheduleSlot = newValue;
                          _selectedBedId = null; // reset bed when slot changes
                        });
                      },
                    ),

                    const SizedBox(height: 16),

                    // --- Bed Selection (only when date & slot are picked) ---
                    if (_rescheduleDate != null && _rescheduleSlot != null) ...[
                      const Divider(height: 24),
                      const Text(
                        "Optional Bed Assignment (4 per bed):",
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),

                      FutureBuilder<Map<String, int>>(
                        future: _fetchBedAssignmentCounts(
                          Timestamp.fromDate(_rescheduleDate!),
                          _rescheduleSlot!,
                        ),
                        builder: (context, assignmentSnap) {
                          if (assignmentSnap.connectionState == ConnectionState.waiting) {
                            return const Center(child: LinearProgressIndicator());
                          }

                          final bedCounts = assignmentSnap.data ?? {};

                          return FutureBuilder<QuerySnapshot>(
                            future: FirebaseFirestore.instance.collection('beds').get(),
                            builder: (context, bedSnap) {
                              if (bedSnap.connectionState == ConnectionState.waiting) {
                                return const Center(child: CircularProgressIndicator());
                              }
                              if (!bedSnap.hasData || bedSnap.data!.docs.isEmpty) {
                                return const Text(
                                  "No beds found.",
                                  style: TextStyle(color: Colors.red),
                                );
                              }

                              final beds = bedSnap.data!.docs;

                              return Column(
                                children: beds.map((doc) {
                                  final bedId = doc.id;
                                  final bedData = doc.data() as Map<String, dynamic>? ?? {};
                                  final bedName = bedData['name'] ?? 'Bed $bedId';

                                  final assignedCount = bedCounts[bedId] ?? 0;
                                  final isFull = assignedCount >= 4;

                                  return RadioListTile<String>(
                                    title: Text(bedName),
                                    subtitle: Text(
                                      "Assigned: $assignedCount / 4",
                                      style: TextStyle(color: isFull ? Colors.red : Colors.green),
                                    ),
                                    value: bedId,
                                    groupValue: _selectedBedId,
                                    onChanged: isFull && _selectedBedId != bedId
                                        ? null
                                        : (value) {
                                      setStateSB(() {
                                        _selectedBedId = value;
                                      });
                                    },
                                    dense: true,
                                  );
                                }).toList(),
                              );
                            },
                          );
                        },
                      ),
                    ],

                    const SizedBox(height: 16),
                    const Text(
                      "Note: Selecting a bed will set status to 'Approved'.\nNot selecting a bed will set status to 'Rescheduled'.",
                      style: TextStyle(color: Colors.blueGrey, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text("Cancel"),
              ),
              ElevatedButton(
                onPressed: _rescheduleDate != null && _rescheduleSlot != null
                    ? () => Navigator.pop(ctx, true)
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _selectedBedId != null ? Colors.green : Colors.blue,
                  foregroundColor: Colors.white,
                ),
                child: Text(
                  _selectedBedId != null ? "Reschedule & Approve" : "Reschedule Only",
                ),
              ),
            ],
          );
        },
      ),
    );

    if (confirmed == true && _rescheduleDate != null && _rescheduleSlot != null) {
      // Determine the final status based on whether a bed was selected
      final newStatus = _selectedBedId != null ? "approved" : "rescheduled";

      await _updateStatus(
        appointmentId,
        newStatus,
        date: Timestamp.fromDate(_rescheduleDate!),
        slot: _rescheduleSlot,
        bedId: _selectedBedId, // This is null if the nurse didn't select one
      );
    }
  }
  Widget _buildSlotsTab(DateTime selectedDate, List<String> slots,
      Function(String) onSelect, String? selectedSlot) {
    // Filters appointments by selectedDate and status 'pending', 'approved', 'rescheduled'
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

          const int maxSlots = 16; // Maximum slots available per time window
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
              int available = maxSlots - count;

              // Use MaterialColor constants which have shades defined
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
                      // FIX: Use [] accessor for MaterialColor
                        color: isSelected ? Colors.blue[700]! : color[300]!,
                        width: isSelected ? 3 : 1
                    ),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                    leading: Icon(
                      isSelected ? Icons.check_circle : (slotFull ? Icons.cancel : Icons.check_circle_outline),
                      color: isSelected ? Colors.blue[700] : color, // Use [] accessor for MaterialColor
                      size: 30,
                    ),
                    title: Text(s, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    subtitle: Text(
                      "Booked: $count / $maxSlots | Status: $statusText",
                      // FIX: Use [] accessor for MaterialColor
                      style: TextStyle(color: color[700], fontSize: 13),
                    ),
                    trailing: ElevatedButton.icon(
                      icon: const Icon(Icons.arrow_forward_ios, size: 16),
                      label: Text(isSelected ? "Selected" : "Select"),
                      onPressed: slotFull ? null : () => onSelect(s),
                      style: ElevatedButton.styleFrom(
                        // FIX: Use [] accessor for MaterialColor
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

  // --- Beds Tab (UPDATED to match design and fix errors) ---
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
        // 1. Fetch capacity counts for the specific date/slot
        future: _fetchBedAssignmentCounts(selectedDate, selectedSlot),
        builder: (context, assignmentSnap) {
          if (assignmentSnap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final bedCounts = assignmentSnap.data ?? {};
          const int maxCapacityPerBed = 4; // Max capacity per bed per slot

          return FutureBuilder<QuerySnapshot>(
            // 2. Fetch ALL working beds
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
                        Text("Slot: $selectedSlot (Capacity: $maxCapacityPerBed/Bed)", style: TextStyle(color: Colors.grey[700], fontSize: 14)), // Using [] for safety
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
                                  color: isSelected ? Colors.blue[700]! : Colors.transparent, // Using [] for safety
                                  width: isSelected ? 2 : 1
                              ),
                            ),
                            child: RadioListTile<String>(
                              title: Text(bedName, style: TextStyle(fontWeight: FontWeight.bold, color: isFull ? Colors.grey : Colors.black87)),
                              subtitle: Text(
                                "Assigned: $assignedCount / $maxCapacityPerBed",
                                // FIX: Use [] accessor for MaterialColor
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
                                // FIX: Changed 'bed_time' to 'block'
                                isFull ? Icons.block : Icons.bed,
                                color: isFull ? Colors.red[300] : (isSelected ? Colors.blue[700] : Colors.grey),
                              ),
                              activeColor: Colors.blue[700], // Using [] for safety
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

  Future<void> _confirmAction(BuildContext context, String action, Function onConfirm) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("Confirm $action"),
        content: Text("Are you sure you want to ${action.toLowerCase()} this appointment?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              // Use a specific color for 'Remove'
              backgroundColor: action == "Approve" || action == "Complete" ? Colors.green : (action == "Remove" ? Colors.black54 : Colors.red),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text("Yes, ${action}"),
          ),
        ],
      ),
    );
    if (confirmed == true) await onConfirm();
  }


  // --- UI WIDGETS ---

  Widget _buildStatCards(BuildContext context) {
    return FutureBuilder<_AppointmentStats>(
      future: _fetchAppointmentStats(),
      builder: (context, snapshot) {
        final stats = snapshot.data;
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(
            height: 80,
            child: Center(child: LinearProgressIndicator()),
          );
        }

        final currentStats = snapshot.data ?? _AppointmentStats(total: 0, pending: 0, approved: 0, rescheduled: 0, rejected: 0, completed: 0);

        final List<Map<String, dynamic>> statCards = [
          {"label": "Total", "count": currentStats.total, "color": Colors.blueGrey, "icon": Icons.list_alt},
          {"label": "Pending", "count": currentStats.pending, "color": Colors.orange, "icon": Icons.pending},
          {"label": "Approved", "count": currentStats.approved, "color": Colors.green, "icon": Icons.check_circle},
          {"label": "Completed", "count": currentStats.completed, "color": Colors.teal, "icon": Icons.done_all},
          {"label": "Rescheduled", "count": currentStats.rescheduled, "color": Colors.blue, "icon": Icons.calendar_month},
          {"label": "Rejected", "count": currentStats.rejected, "color": Colors.red, "icon": Icons.close},
        ];

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: statCards.map((card) {
              final Color color = card["color"];
              final int count = card["count"];
              final String label = card["label"];

              return Padding(
                padding: const EdgeInsets.only(right: 12.0),
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedStatusFilter = label;
                      _searchQuery = "";
                    });
                  },
                  child: Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: _selectedStatusFilter == label
                          ? BorderSide(color: color, width: 2.5)
                          : BorderSide.none,
                    ),
                    child: Container(
                      width: 150,
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(card["icon"], size: 24, color: color),
                              const Spacer(),
                              Text(
                                count.toString(),
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: color,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            label,
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.black87,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }

  Widget _buildFilterButtons() {
    final List<String> statuses = ["All", "Pending", "Approved", "Rescheduled", "Rejected", "Completed"];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Wrap(
        spacing: 8.0,
        children: statuses.map((status) {
          final isSelected = _selectedStatusFilter == status;
          final color = _getStatusColor(status.toLowerCase() == "all" ? "pending" : status.toLowerCase());

          return ChoiceChip(
            label: Text(status),
            selected: isSelected,
            onSelected: (selected) {
              if (selected) {
                setState(() {
                  _selectedStatusFilter = status;
                  _searchQuery = "";
                });
              }
            },
            selectedColor: color.withOpacity(0.2),
            labelStyle: TextStyle(
              color: isSelected ? color : Colors.black87,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
            backgroundColor: Colors.grey.shade100,
            side: isSelected ? BorderSide(color: color, width: 1.5) : BorderSide.none,
          );
        }).toList(),
      ),
    );
  }

  // --- Card Widget with Scrollable Buttons at the bottom (INCLUDES isPast FIX) ---
  Widget _buildAppointmentCard({
    required String appointmentId,
    required String patientId,
    required String patientName,
    required String status,
    required Timestamp? dateTimestamp,
    required String slot,
    required String? bedName,
    required String? oldBedId,
  }) {
    final date = dateTimestamp?.toDate() ?? DateTime(1970);
    final statusLower = status.toLowerCase();
    final statusColor = _getStatusColor(statusLower);

    // Status Flags
    final isPending = statusLower == 'pending';
    final isApproved = statusLower == 'approved';
    final isCompleted = statusLower == 'completed';
    final isRescheduled = statusLower == 'rescheduled';
    final isRejected = statusLower == 'rejected';

    // FIX: Check if the appointment date has passed
    final now = DateTime.now();
    // Compare dates based on day, month, and year for 'past'
    final isPast = date.isBefore(DateTime(now.year, now.month, now.day));


    // --- Primary Action Buttons ---
    List<Widget> primaryActions = [];

    if (isPending) {
      // Pending appointments need to be Approved or Rejected/Rescheduled
      primaryActions.addAll([
        ElevatedButton.icon(
          onPressed: () => _approveWithBed(context, appointmentId, dateTimestamp, slot),
          icon: const Icon(Icons.check),
          label: const Text("Approve"),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
        const SizedBox(width: 8),
        OutlinedButton.icon(
          onPressed: () => _rescheduleAppointment(context, appointmentId, patientId, patientName, dateTimestamp, slot, oldBedId),
          icon: const Icon(Icons.calendar_month),
          label: const Text("Reschedule"),
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.blue,
            side: const BorderSide(color: Colors.blue),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
      ]);
    } else if (isApproved && !isPast) {
      // Approved appointments in the future can only be rescheduled or rejected
      primaryActions.addAll([
        ElevatedButton.icon(
          onPressed: () => _rescheduleAppointment(context, appointmentId, patientId, patientName, dateTimestamp, slot, oldBedId),
          icon: const Icon(Icons.calendar_month),
          label: const Text("Reschedule"),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
      ]);
    } else if (isApproved && isPast) {
      // Approved appointments in the past must be marked as Completed
      primaryActions.add(
        ElevatedButton.icon(
          onPressed: () => _confirmAction(context, "Complete", () => _updateStatus(appointmentId, "completed")),
          icon: const Icon(Icons.done_all),
          label: const Text("Mark Complete"),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.teal,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
      );
    } else if (isRescheduled) {
      // Rescheduled can be Approved or Rejected (or Rescheduled again)
      primaryActions.addAll([
        ElevatedButton.icon(
          onPressed: () => _approveWithBed(context, appointmentId, dateTimestamp, slot),
          icon: const Icon(Icons.check),
          label: const Text("Approve"),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
        const SizedBox(width: 8),
        OutlinedButton.icon(
          onPressed: () => _rescheduleAppointment(context, appointmentId, patientId, patientName, dateTimestamp, slot, oldBedId),
          icon: const Icon(Icons.calendar_month),
          label: const Text("Re-Reschedule"),
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.blue,
            side: const BorderSide(color: Colors.blue),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
      ]);
    }

    // --- Secondary Actions (Dropdown Menu) ---
    final secondaryActions = <PopupMenuEntry<String>>[
      if (!isRejected && !isCompleted)
        const PopupMenuItem<String>(
          value: 'Reject',
          child: ListTile(
            leading: Icon(Icons.close, color: Colors.red),
            title: Text('Reject Appointment'),
          ),
        ),
      const PopupMenuItem<String>(
        value: 'Remove',
        child: ListTile(
          leading: Icon(Icons.delete_forever, color: Colors.black54),
          title: Text('Remove (Archive)'),
        ),
      ),
      if (isPending || isRescheduled)
        const PopupMenuItem<String>(
          value: 'Reassign',
          child: ListTile(
            leading: Icon(Icons.local_hospital_outlined, color: Colors.indigo),
            title: Text('Re-Assign Bed'),
          ),
        ),
    ];

    // --- Card UI ---
    return Card(
      elevation: 4,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Row 1: Status and Patient Name
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    status.toUpperCase(),
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (String result) async {
                    switch (result) {
                      case 'Reject':
                        await _confirmAction(context, "Reject", () => _updateStatus(appointmentId, "rejected"));
                        break;
                      case 'Remove':
                        await _confirmAction(context, "Remove", () => _updateStatus(appointmentId, "removed"));
                        break;
                      case 'Reassign':
                      // Use the existing approve dialog logic to select a new bed
                        await _approveWithBed(context, appointmentId, dateTimestamp, slot);
                        break;
                    }
                  },
                  itemBuilder: (BuildContext context) => secondaryActions,
                  icon: const Icon(Icons.more_vert, color: Colors.grey),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Row 2: Patient and Details
            Text(
              "Patient: $patientName",
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            // Row 3: Date, Slot, Bed
            Row(
              children: [
                const Icon(Icons.calendar_today, size: 18, color: Colors.grey),
                const SizedBox(width: 8),
                Text(
                  DateFormat('MMM d, yyyy').format(date),
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(width: 20),
                const Icon(Icons.access_time, size: 18, color: Colors.grey),
                const SizedBox(width: 8),
                Text(
                  slot,
                  style: const TextStyle(fontSize: 16),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.king_bed_outlined, size: 18, color: isApproved ? Colors.green : Colors.grey),
                const SizedBox(width: 8),
                Text(
                  bedName != null ? "Bed: $bedName" : "Bed: Unassigned",
                  style: TextStyle(
                    fontSize: 16,
                    color: bedName != null ? Colors.black : Colors.red,
                    fontWeight: bedName != null ? FontWeight.normal : FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Divider(height: 1, thickness: 1),
            const SizedBox(height: 15),

            // --- Action Buttons (Fixed Visibility) ---
            // Wrapped in a Row for desktop/wide screen, or Wrap for mobile/narrow screen
            if (primaryActions.isNotEmpty)
              _isWideScreen(context)
                  ? Row(
                mainAxisAlignment: MainAxisAlignment.start,
                children: primaryActions,
              )
                  : Wrap(
                spacing: 8.0,
                runSpacing: 8.0,
                children: primaryActions,
              ),
            if (primaryActions.isEmpty)
              Text(
                isCompleted || isRejected
                    ? "No further actions for ${status.toLowerCase()} appointments."
                    : (isApproved && isPast ? "Action Required: Mark Complete" : "No primary actions available."),
                style: const TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
              ),
          ],
        ),
      ),
    );
  }

  // --- MAIN BUILD METHOD ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            const Text(
              "Appointments Management",
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF4CAF50)),
            ),
            const SizedBox(height: 16),

            // Stat Cards (Filter by tapping)
            _buildStatCards(context),
            const SizedBox(height: 16),

            // Search and Filter Row
            Row(
              children: [
                // Search Field
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(right: _isWideScreen(context) ? 16.0 : 0),
                    child: TextField(
                      decoration: InputDecoration(
                        hintText: "Search by patient name...",
                        prefixIcon: const Icon(Icons.search),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: Colors.grey.shade100,
                        contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 10),
                      ),
                      onChanged: (value) {
                        setState(() {
                          _searchQuery = value.toLowerCase();
                        });
                      },
                    ),
                  ),
                ),
                // Filter Buttons (visible on wide screens or if space allows)
                if (_isWideScreen(context))
                  SizedBox(width: _isWideScreen(context) ? 400 : 0, child: _buildFilterButtons()),
              ],
            ),
            const SizedBox(height: 16),

            // If not wide screen, show filter buttons below search
            if (!_isWideScreen(context)) ...[
              _buildFilterButtons(),
              const SizedBox(height: 16),
            ],

            // Appointment List (StreamBuilder)
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('appointments')
                    .where('status', isNotEqualTo: 'removed') // Exclude removed appointments from main view
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return const Center(child: Text("No active appointments found."));
                  }

                  final allAppointments = snapshot.data!.docs;

                  final filteredAppointments = allAppointments.where((doc) {
                    final data = doc.data() as Map<String, dynamic>? ?? {};
                    final status = data['status']?.toString().toLowerCase() ?? '';
                    final patientId = data['patientId']?.toString() ?? '';
                    final patientName = _getPatientNameSync(patientId).toLowerCase();

                    // Apply status filter
                    bool statusMatch = _selectedStatusFilter == "All" ||
                        status.toLowerCase() == _selectedStatusFilter.toLowerCase();

                    // Apply search filter
                    bool searchMatch = _searchQuery.isEmpty || patientName.contains(_searchQuery);

                    return statusMatch && searchMatch;
                  }).toList();

                  if (filteredAppointments.isEmpty) {
                    return Center(
                        child: Text("No appointments match the current filter and search criteria: '$_selectedStatusFilter' and '$_searchQuery'")
                    );
                  }

                  return ListView.builder(
                    itemCount: filteredAppointments.length,
                    itemBuilder: (context, index) {
                      final doc = filteredAppointments[index];
                      // FIX 8: Safely handle data retrieval
                      final data = doc.data() as Map<String, dynamic>? ?? {};
                      final appointmentId = doc.id;
                      final patientId = data['patientId']?.toString() ?? 'N/A';
                      final patientName = _getPatientNameSync(patientId);
                      final status = data['status']?.toString() ?? 'Pending';
                      final dateTimestamp = data['date'] as Timestamp?;
                      final slot = data['slot']?.toString() ?? 'N/A';
                      final bedName = data['bedName']?.toString();
                      final oldBedId = data['bedId']?.toString();

                      return _buildAppointmentCard(
                        appointmentId: appointmentId,
                        patientId: patientId,
                        patientName: patientName,
                        status: status,
                        dateTimestamp: dateTimestamp,
                        slot: slot,
                        bedName: bedName,
                        oldBedId: oldBedId,
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
