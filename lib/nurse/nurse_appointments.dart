// nurse_appointments_page.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

// -----------------------------------------------------------------
// CONFIG
// -----------------------------------------------------------------
const int AUTO_MISSED_HOURS = 2;
const int CLIENT_PROCESS_INTERVAL_MINUTES = 5; // client-side periodic check
const int AUTO_RESCHEDULE_SEARCH_DAYS = 30; // how far to search for a new slot
const int DEFAULT_SESSION_DURATION_MINUTES = 60; // fallback
const int MAX_SLOTS_PER_WINDOW = 16;
const int MAX_BED_CAPACITY = 4;

// -----------------------------------------------------------------
// HELPER CLASSES
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
// MAIN WIDGET
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
  Timer? _clientProcessorTimer;

  // Synchronized with patient's BookPage
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
      case 'missed':
        return Colors.redAccent;
      case 'showed':
        return Colors.purple;
      default:
        return Colors.black;
    }
  }

  @override
  void initState() {
    super.initState();
    _preloadAllPatientNames();
    _startClientAutoProcessor();
    // run once shortly after start to capture immediate items
    Future.delayed(const Duration(seconds: 2), () => _processDueAutoTasksClient());
  }

  @override
  void dispose() {
    _clientProcessorTimer?.cancel();
    super.dispose();
  }

  // -------------------- Patient name caching --------------------
  Future<void> _preloadAllPatientNames() async {
    try {
      final appointmentsSnap = await FirebaseFirestore.instance.collection('appointments').get();

      final Set<String> patientIds = appointmentsSnap.docs
          .map((doc) => (doc.data()?['patientId'] as String?))
          .where((id) => id != null)
          .toSet()
          .cast<String>();

      if (patientIds.isEmpty) return;

      for (String id in patientIds) {
        if (!_patientNamesCache.containsKey(id)) {
          final doc = await FirebaseFirestore.instance.collection('users').doc(id).get();
          final name = doc.data()?['fullName'] ?? "Unknown";
          _patientNamesCache[id] = name;
        }
      }
      if (mounted) setState(() {});
    } catch (e) {
      print("Error pre-loading patient names: $e");
    }
  }

  Future<String> _getPatientName(String uid) async {
    if (_patientNamesCache.containsKey(uid)) return _patientNamesCache[uid]!;
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
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

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;
    final snackBar = SnackBar(content: Text(message), backgroundColor: isError ? Colors.red : Colors.green);
    ScaffoldMessenger.of(context).showSnackBar(snackBar);
  }

  // -------------------- STATUS HELPERS --------------------

  DateTime? _slotStartDateTimeFor(Timestamp? dateTs, String? slot) {
    if (dateTs == null || slot == null) return null;
    final date = dateTs.toDate();
    final parts = slot.split('-');
    if (parts.length != 2) return DateTime(date.year, date.month, date.day);
    final start = parts[0].trim(); // e.g. "06:00"
    try {
      final parsed = DateFormat('HH:mm').parse(start);
      return DateTime(date.year, date.month, date.day, parsed.hour, parsed.minute);
    } catch (e) {
      // If parse fails, return start of day
      return DateTime(date.year, date.month, date.day);
    }
  }

  DateTime? _slotEndDateTimeFor(Timestamp? dateTs, String? slot) {
    if (dateTs == null || slot == null) return null;
    final date = dateTs.toDate();
    final parts = slot.split('-');
    if (parts.length != 2) return DateTime(date.year, date.month, date.day);
    final end = parts[1].trim(); // e.g. "10:00"
    try {
      final parsed = DateFormat('HH:mm').parse(end);
      return DateTime(date.year, date.month, date.day, parsed.hour, parsed.minute);
    } catch (e) {
      return DateTime(date.year, date.month, date.day);
    }
  }

  // -------------------- Compose notification --------------------
  String _composeNotificationMessage(String status, Map<String, dynamic> appointmentData, Timestamp? date, String? slot) {
    switch (status) {
      case "approved":
        return "✅ Your appointment has been approved. You have been assigned to bed ${appointmentData['bedName'] ?? 'a bed'}.";
      case "rejected":
        return "❌ Your appointment has been rejected. Please schedule a new one.";
      case "completed":
        return "🎉 Your appointment has been marked as completed. Thank you for using our service.";
      case "rescheduled":
        final newDate = date != null ? DateFormat('MMM d, yyyy').format(date.toDate()) : (appointmentData['date'] != null ? DateFormat('MMM d, yyyy').format((appointmentData['date'] as Timestamp).toDate()) : 'a new date');
        return "📅 Your appointment has been rescheduled to $newDate, Slot: ${slot ?? appointmentData['slot'] ?? 'N/A'}. Please check the new details.";
      case "removed":
        return "🗑 Your appointment has been removed. Please contact the clinic for more information.";
      case "missed":
        return "⏰ Your appointment was marked as MISSED. We attempted to auto-reschedule it — check your appointments for details.";
      case "showed":
        return "👋 Your nurse marked you as showed. Your session is now in progress.";
      default:
        return "📅 Your appointment status changed to $status.";
    }
  }

  // -------------------- BASIC _updateStatus (nurse manual) --------------------
  // NOTE: for approve/reschedule auto-assign we use transactional functions below.
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
      final beforeData = beforeSnap.data() as Map<String, dynamic>? ?? {};
      final String patientId = beforeData['patientId'] ?? '';
      final String? oldBedId = beforeData['bedId'];

      Map<String, dynamic> updateData = {
        'status': status,
        'nurseId': widget.nurseId,
        'lastUpdatedBy': 'nurse',
        'lastUpdatedAt': FieldValue.serverTimestamp(),
      };
      if (bedId != null) updateData['bedId'] = bedId;
      if (date != null) updateData['date'] = date;
      if (slot != null) updateData['slot'] = slot;

      if (bedId != null && status == 'approved') {
        final bedDoc = await firestore.collection('beds').doc(bedId).get();
        updateData['bedName'] = bedDoc.data()?['name'] ?? 'a bed';
      } else if (status != 'approved' && oldBedId != null && oldBedId.isNotEmpty) {
        updateData.remove('bedId');
        updateData.remove('bedName');
      }

      await firestore.collection('appointments').doc(appointmentId).update(updateData);

      // sync bed assignment (nurse action) - best-effort (non-transactional)
      try {
        if (oldBedId != null && oldBedId.isNotEmpty && oldBedId != bedId) {
          await firestore.collection('beds').doc(oldBedId).update({
            'assignedPatients': FieldValue.arrayRemove([patientId]),
          });
        }
        if (status == 'approved' && bedId != null) {
          await firestore.collection('beds').doc(bedId).update({
            'assignedPatients': FieldValue.arrayUnion([patientId]),
          });
        }
      } catch (e) {
        print("Error updating bed status (nurse): $e");
      }

      // create notification
      final updatedDoc = await firestore.collection('appointments').doc(appointmentId).get();
      final updatedData = updatedDoc.data() as Map<String, dynamic>? ?? {};
      final updatedPatientId = updatedData['patientId'];
      final notif = {
        'title': "Appointment Update",
        'message': _composeNotificationMessage(status, updatedData, date, slot),
        'userId': updatedPatientId,
        'appointmentId': appointmentId,
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
        'type': 'patient',
        'origin': 'nurse',
      };
      await firestore.collection('notifications').add(notif);

      if (!mounted) return;
      _showMessage("Appointment status updated to $status");
      setState(() {});
    } catch (e) {
      _showMessage("Failed to update status: $e", isError: true);
    }
  }

  // -------------------- SYSTEM UPDATE (non-bed or when bedId == null) --------------------
  Future<void> _systemUpdateStatus(
      String appointmentId,
      String status, {
        String? bedId,
        Timestamp? date,
        String? slot,
        Map<String, dynamic>? extraFields,
      }) async {
    final firestore = FirebaseFirestore.instance;

    // If bedId is provided we should do the assign in a transaction
    if (bedId != null) {
      // try transactional update and bed assign
      final ok = await _assignBedAndUpdateAppointmentTransaction(
        appointmentId,
        status: status,
        date: date,
        slot: slot,
        preferredBedId: bedId,
        origin: 'system',
        extraFields: extraFields,
      );
      if (!ok) {
        print("systemUpdateStatus: transaction failed for appointment $appointmentId with bed $bedId");
      }
      return;
    }

    try {
      final beforeSnap = await firestore.collection('appointments').doc(appointmentId).get();
      final beforeData = beforeSnap.data() as Map<String, dynamic>? ?? {};
      final String patientId = beforeData['patientId'] ?? '';
      final String? oldBedId = beforeData['bedId'];

      Map<String, dynamic> updateData = {
        'status': status,
        'lastUpdatedBy': 'system',
        'lastUpdatedAt': FieldValue.serverTimestamp(),
      };
      if (date != null) updateData['date'] = date;
      if (slot != null) updateData['slot'] = slot;
      if (extraFields != null) updateData.addAll(extraFields);

      if (status != 'approved' && oldBedId != null && oldBedId.isNotEmpty) {
        updateData.remove('bedId');
        updateData.remove('bedName');
      }

      await firestore.collection('appointments').doc(appointmentId).update(updateData);

      // sync bed assignment (system) best-effort when bed removed
      try {
        if (status != 'approved' && oldBedId != null && oldBedId.isNotEmpty) {
          await firestore.collection('beds').doc(oldBedId).update({
            'assignedPatients': FieldValue.arrayRemove([patientId]),
          });
        }
      } catch (e) {
        print("Error updating bed status (system): $e");
      }

      // create notification
      final updatedDoc = await firestore.collection('appointments').doc(appointmentId).get();
      final updatedData = updatedDoc.data() as Map<String, dynamic>? ?? {};
      final updatedPatientId = updatedData['patientId'];
      final notif = {
        'title': "Appointment Update",
        'message': _composeNotificationMessage(status, updatedData, date, slot),
        'userId': updatedPatientId,
        'appointmentId': appointmentId,
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
        'type': 'patient',
        'origin': 'system',
      };
      await firestore.collection('notifications').add(notif);
    } catch (e) {
      print("System update failed for $appointmentId: $e");
    }
  }

  // -------------------- BED COUNTS (for UI & capacity checks) --------------------
  // Count appointments for the specific date+slot with relevant active statuses.
  Future<Map<String, int>> _fetchBedAssignmentCounts(dynamic dateData, dynamic slotData) async {
    if (dateData == null || slotData == null) return {};

    DateTime targetDate;
    if (dateData is Timestamp) {
      targetDate = dateData.toDate();
    } else if (dateData is DateTime) {
      targetDate = dateData;
    } else {
      targetDate = DateTime.now();
    }

    final startOfDay = DateTime(targetDate.year, targetDate.month, targetDate.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    // Active statuses that should occupy bed slots
    final activeStatuses = ['approved', 'showed', 'in_process', 'rescheduled'];

    final snap = await FirebaseFirestore.instance
        .collection('appointments')
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
        .where('date', isLessThan: Timestamp.fromDate(endOfDay))
        .where('slot', isEqualTo: slotData)
        .where('status', whereIn: activeStatuses)
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

  // -------------------- Transactional assign & update --------------------
  // This transaction finds a bed (if preferredBedId null) and atomically:
  // - verifies capacity (no more than MAX_BED_CAPACITY)
  // - updates appointment with new status/date/slot/bedId/bedName and lastUpdatedBy=origin
  // - updates bed.assignedPatients (arrayUnion)
  // - removes patient from previous bed if applicable
  Future<bool> _assignBedAndUpdateAppointmentTransaction(
      String appointmentId, {
        required String status,
        Timestamp? date,
        String? slot,
        String? preferredBedId,
        String origin = 'system', // or 'nurse'
        Map<String, dynamic>? extraFields,
      }) async {
    final firestore = FirebaseFirestore.instance;

    try {
      return await firestore.runTransaction<bool>((tx) async {
        final apptRef = firestore.collection('appointments').doc(appointmentId);
        final apptSnap = await tx.get(apptRef);
        if (!apptSnap.exists) return false;
        final appt = apptSnap.data() as Map<String, dynamic>? ?? {};
        final String patientId = appt['patientId'] ?? '';
        final String? oldBedId = appt['bedId'] as String?;
        final Timestamp effectiveDate = date ?? (appt['date'] as Timestamp? ?? Timestamp.now());
        final String effectiveSlot = slot ?? (appt['slot']?.toString() ?? _slots.first);

        // Determine candidate bed if none provided by checking appointment counts
        String? bedToAssign = preferredBedId;

        if (bedToAssign == null) {
          // get counts per bed for this date+slot
          final bedCounts = <String,int>{};
          final DateTime dateOnly = effectiveDate.toDate();
          final tsStart = Timestamp.fromDate(DateTime(dateOnly.year, dateOnly.month, dateOnly.day));
          final tsEnd = Timestamp.fromDate(DateTime(dateOnly.year, dateOnly.month, dateOnly.day).add(const Duration(days: 1)));

          final apptsForDay = await firestore
              .collection('appointments')
              .where('date', isGreaterThanOrEqualTo: tsStart)
              .where('date', isLessThan: tsEnd)
              .where('slot', isEqualTo: effectiveSlot)
              .where('status', whereIn: ['approved','showed','in_process','rescheduled'])
              .get();

          for (var d in apptsForDay.docs) {
            final dd = d.data() as Map<String, dynamic>? ?? {};
            final b = dd['bedId']?.toString();
            if (b != null && b.isNotEmpty) {
              bedCounts[b] = (bedCounts[b] ?? 0) + 1;
            }
          }

          // iterate working beds and pick first with capacity
          // IMPORTANT: order by 'name' to ensure FCFS (Bed 01, Bed 02, ...)
          final bedsSnap = await firestore.collection('beds').where('isWorking', isEqualTo: true).orderBy('name').get();
          for (var bdoc in bedsSnap.docs) {
            final id = bdoc.id;
            final count = bedCounts[id] ?? 0;
            if (count < MAX_BED_CAPACITY) {
              bedToAssign = id;
              break;
            }
          }
        } else {
          // if preferred provided, verify capacity first
          final DateTime dateOnly = effectiveDate.toDate();
          final tsStart = Timestamp.fromDate(DateTime(dateOnly.year, dateOnly.month, dateOnly.day));
          final tsEnd = Timestamp.fromDate(DateTime(dateOnly.year, dateOnly.month, dateOnly.day).add(const Duration(days: 1)));

          final assignedSnap = await firestore.collection('appointments')
              .where('date', isGreaterThanOrEqualTo: tsStart)
              .where('date', isLessThan: tsEnd)
              .where('slot', isEqualTo: slot ?? appt['slot'])
              .where('status', whereIn: ['approved','showed','in_process','rescheduled'])
              .where('bedId', isEqualTo: preferredBedId)
              .get();

          if (assignedSnap.docs.length >= MAX_BED_CAPACITY) {
            // cannot assign preferred bed
            bedToAssign = null;
          }
        }

        // Build appointment update
        final Map<String, dynamic> updateData = {
          'status': status,
          'lastUpdatedBy': origin,
          'lastUpdatedAt': FieldValue.serverTimestamp(),
        };
        if (date != null) updateData['date'] = date;
        if (slot != null) updateData['slot'] = slot;
        if (extraFields != null) updateData.addAll(extraFields);

        if (bedToAssign != null) {
          final bedDoc = await tx.get(firestore.collection('beds').doc(bedToAssign));
          final bedName = bedDoc.data()?['name'] ?? 'a bed';
          updateData['bedId'] = bedToAssign;
          updateData['bedName'] = bedName;
        } else {
          // ensure appointment reflects no bed if status not approved
          if (status != 'approved') {
            updateData.remove('bedId');
            updateData.remove('bedName');
          }
        }

        // Update appointment
        tx.update(apptRef, updateData);

        // Update beds atomically: remove from old bed, add to new if applicable
        if (oldBedId != null && oldBedId.isNotEmpty && oldBedId != bedToAssign) {
          final oldBedRef = firestore.collection('beds').doc(oldBedId);
          tx.update(oldBedRef, {
            'assignedPatients': FieldValue.arrayRemove([patientId]),
          });
        }
        if (bedToAssign != null) {
          final bedRef = firestore.collection('beds').doc(bedToAssign);
          tx.update(bedRef, {
            'assignedPatients': FieldValue.arrayUnion([patientId]),
          });
        }

        return true;
      });
    } catch (e) {
      print("assignBedAndUpdateAppointmentTransaction error: $e");
      return false;
    }
  }

  // -------------------- Find available bed (non-transactional helper) --------------------
  Future<String?> _findAvailableBedFor(DateTime date, String slot) async {
    // This helper attempts to find a bed quickly (non-transactional).
    // The final assignment should still use a transaction to avoid races.
    final DateTime onlyDate = DateTime(date.year, date.month, date.day);
    final tsStart = Timestamp.fromDate(onlyDate);
    final tsEnd = Timestamp.fromDate(onlyDate.add(const Duration(days: 1)));

    // Build counts per bed using appointments
    final appts = await FirebaseFirestore.instance
        .collection('appointments')
        .where('date', isGreaterThanOrEqualTo: tsStart)
        .where('date', isLessThan: tsEnd)
        .where('slot', isEqualTo: slot)
        .where('status', whereIn: ['approved','showed','in_process','rescheduled'])
        .get();

    final Map<String,int> counts = {};
    for (var d in appts.docs) {
      final b = (d.data()?['bedId'] as String?) ?? '';
      if (b.isNotEmpty) counts[b] = (counts[b] ?? 0) + 1;
    }

    // order beds by name to enforce FCFS (Bed 01 first)
    final bedsSnap = await FirebaseFirestore.instance.collection('beds').where('isWorking', isEqualTo: true).orderBy('name').get();
    for (var bdoc in bedsSnap.docs) {
      final id = bdoc.id;
      final c = counts[id] ?? 0;
      if (c < MAX_BED_CAPACITY) return id;
    }
    return null;
  }

  // -------------------- APPROVE FLOW (dialog -> transactional assignment) --------------------
  Future<void> _approveWithBed(BuildContext context, String appointmentId, dynamic dateData, dynamic slotData) async {
    // Attempt quick auto-assign first
    String? candidateBedId;
    if (dateData is Timestamp && slotData is String) {
      candidateBedId = await _findAvailableBedFor(dateData.toDate(), slotData);
    }

    // We still show a dialog to confirm approve action with info, but no bed-selection required.
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Approve Appointment"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("Approve this appointment? Bed will be assigned automatically if available."),
            const SizedBox(height: 12),
            if (candidateBedId == null)
              const Text("No bed appears available right now. System will try to find one during approval or reschedule.", style: TextStyle(color: Colors.orange)),
            if (candidateBedId != null)
              FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance.collection('beds').doc(candidateBedId).get(),
                builder: (context, snap) {
                  if (!snap.hasData) return const SizedBox.shrink();
                  final bed = snap.data!;
                  final name = (bed.data() as Map<String, dynamic>?)?['name'] ?? 'a bed';
                  return Text("Auto-selected bed: $name");
                },
              ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text("Approve"),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      // Use transaction to assign bed and mark approved
      final ok = await _assignBedAndUpdateAppointmentTransaction(
        appointmentId,
        status: 'approved',
        date: (dateData is Timestamp) ? dateData : null,
        slot: (slotData is String) ? slotData : null,
        preferredBedId: candidateBedId,
        origin: 'nurse',
      );

      if (!ok) {
        _showMessage("Could not assign bed (might be full). Appointment approved but bed not assigned.", isError: true);
        // fallback: try non-transactional update to set status to approved without bed
        await _updateStatus(appointmentId, 'approved');
      }
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

    DateTime initialDate = oldDateData is Timestamp ? oldDateData.toDate() : DateTime.now();
    String? initialSlot = oldSlot?.trim();
    String? initialBedId = oldBedId;

    // Pass a wrapper to the dialog so the dialog only chooses date+slot.
    await showDialog(
      context: context,
      builder: (ctx) => RescheduleDialog(
        appointmentId: appointmentId,
        patientId: patientId,
        patientName: patientName,
        initialDate: initialDate,
        initialSlot: initialSlot,
        initialBedId: initialBedId,
        slots: _slots,
        isWideScreen: _isWideScreen(context),
        onConfirm: (String apptId, String newStatus, {String? bedId, Timestamp? date, String? slot}) async {
          // When reschedule dialog confirms, run transactional reschedule+assign
          final ok = await _assignBedAndUpdateAppointmentTransaction(
            apptId,
            status: newStatus, // expected "rescheduled" or "approved" if bed assigned
            date: date,
            slot: slot,
            preferredBedId: null, // let system choose bed
            origin: 'nurse',
          );
          if (!ok) {
            // fallback to non-transactional reschedule update
            await _updateStatus(apptId, newStatus, date: date, slot: slot);
          }
        },
        //slots: _slots,
        //isWideScreen: _isWideScreen(context),
        fetchBedAssignmentCounts: _fetchBedAssignmentCounts,
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

  // -------------------- UI --------------------
  Widget _buildStatCards(BuildContext context) {
    return FutureBuilder<_AppointmentStats>(
      future: _fetchAppointmentStats(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final stats = snapshot.data!;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _buildStatCard("Total", stats.total, Colors.blueGrey),
            _buildStatCard("Pending", stats.pending, Colors.orange),
            _buildStatCard("Approved", stats.approved, Colors.green),
            _buildStatCard("Rescheduled", stats.rescheduled, Colors.blue),
            _buildStatCard("Rejected", stats.rejected, Colors.red),
            _buildStatCard("Completed", stats.completed, Colors.teal),
          ],
        );
      },
    );
  }

  Widget _buildStatCard(String title, int count, Color color) {
    return Card(
      elevation: 2,
      color: color.withOpacity(0.1),
      child: Container(
        width: 150,
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Text(title, style: TextStyle(fontSize: 16, color: color, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(count.toString(), style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterButtons() {
    final filters = ["All", "Pending", "Approved", "Rescheduled", "Rejected", "Completed", "Missed", "Showed"];
    return Wrap(
      spacing: 6,
      children: filters.map((f) {
        final selected = _selectedStatusFilter == f;
        return ChoiceChip(
          label: Text(f),
          selected: selected,
          onSelected: (_) {
            setState(() => _selectedStatusFilter = f);
          },
          selectedColor: Colors.green,
          labelStyle: TextStyle(color: selected ? Colors.white : Colors.black),
        );
      }).toList(),
    );
  }

  // Table row widget for narrow view (list-like)
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
    final dateStr = dateTimestamp != null
        ? DateFormat('MMM d, yyyy').format(dateTimestamp.toDate())
        : "N/A";

    final statusColor = _getStatusColor(status);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      elevation: 2,
      child: ListTile(
        leading: CircleAvatar(child: Text(patientName.isNotEmpty ? patientName[0].toUpperCase() : "?")),
        title: Text(patientName, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text("Date: $dateStr • Slot: $slot\nBed: ${bedName ?? 'Unassigned'}"),
        trailing: PopupMenuButton<String>(
          onSelected: (value) async {
            switch (value) {
              case 'approve':
                await _approveWithBed(context, appointmentId, dateTimestamp, slot);
                break;
              case 'reject':
                await _confirmAction(context, "Reject", () => _updateStatus(appointmentId, "rejected"));
                break;
              case 'reschedule':
                await _rescheduleAppointment(context, appointmentId, patientId, patientName, dateTimestamp, slot, oldBedId);
                break;
              case 'showed':
                await _updateStatus(appointmentId, "showed");
                break;
              case 'missed':
                await _updateStatus(appointmentId, "missed");
                break;
              case 'completed':
                await _updateStatus(appointmentId, "completed");
                break;
            }
          },
          itemBuilder: (context) => [
            if (status == 'pending' || status == 'rescheduled')
              const PopupMenuItem(value: 'approve', child: Text('Approve')),
            if (status == 'pending' || status == 'approved')
              const PopupMenuItem(value: 'reject', child: Text('Reject')),
            const PopupMenuItem(value: 'reschedule', child: Text('Reschedule')),
            const PopupMenuItem(value: 'showed', child: Text('Mark as Showed')),
            const PopupMenuItem(value: 'missed', child: Text('Mark as Missed')),
            const PopupMenuItem(value: 'completed', child: Text('Mark as Completed')),
          ],
        ),
        tileColor: Colors.white,
      ),
    );
  }

  // Table row for wide screens using DataRow
  DataRow _buildDataRowFromDoc(QueryDocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    final appointmentId = doc.id;
    final patientId = data['patientId'] ?? '';
    final patientName = _getPatientNameSync(patientId);
    final status = (data['status'] ?? '').toString();
    final slot = (data['slot'] ?? '').toString();
    final bedName = data['bedName']?.toString() ?? 'Unassigned';
    final Timestamp? dateTimestamp = data['date'] as Timestamp?;
    final dateStr = dateTimestamp != null ? DateFormat('MMM d, yyyy').format(dateTimestamp.toDate()) : 'N/A';
    final statusColor = _getStatusColor(status);

    return DataRow(cells: [
      DataCell(Text(patientName)),
      DataCell(Text(dateStr)),
      DataCell(Text(slot)),
      DataCell(Text(bedName)),
      DataCell(Row(children: [Icon(Icons.circle, size: 10, color: statusColor), const SizedBox(width: 8), Text(status.toUpperCase())])),
      DataCell(_buildActionButtonsForRow(appointmentId, patientId, patientName, status, dateTimestamp, slot, bedName)),
    ]);
  }

  Widget _buildActionButtonsForRow(String appointmentId, String patientId, String patientName, String status, Timestamp? dateTimestamp, String slot, String bedName) {
    final lower = status.toLowerCase();
    if (lower == 'pending' || lower == 'rescheduled') {
      return Row(
        children: [
          ElevatedButton(
            onPressed: () => _approveWithBed(context, appointmentId, dateTimestamp, slot),
            child: const Text("Approve"),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
          ),
          const SizedBox(width: 8),
          OutlinedButton(
            onPressed: () => _confirmAction(context, "Reject", () => _updateStatus(appointmentId, "rejected")),
            child: const Text("Reject"),
          ),
        ],
      );
    } else if (lower == 'approved') {
      return ElevatedButton(
        onPressed: () => _updateStatus(appointmentId, "showed"),
        child: const Text("Showed"),
        style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
      );
    } else {
      return Text("-", style: TextStyle(color: Colors.grey[600]));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isWide = _isWideScreen(context);

    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header + Run button
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Appointments", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                Row(
                  children: [
                    ElevatedButton.icon(
                      onPressed: _processDueAutoTasksClient,
                      icon: const Icon(Icons.refresh),
                      label: const Text("Run Auto Processor"),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: () => _autoRescheduleMissedAppointments(),
                      icon: const Icon(Icons.schedule),
                      label: const Text("Auto-Reschedule Missed"),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildStatCards(context),
            const SizedBox(height: 12),

            // Search + Filters row
            Row(
              children: [
                // Search bar
                Expanded(
                  flex: isWide ? 2 : 1,
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: "Search by patient name...",
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                    ),
                    onChanged: (v) => setState(() => _searchQuery = v.trim()),
                  ),
                ),
                const SizedBox(width: 12),
                // Filters
                Expanded(
                  flex: isWide ? 3 : 2,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: _buildFilterButtons(),
                  ),
                ),
              ],
            ),
            const Divider(height: 24),

            // Appointment list/table
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection('appointments').orderBy('date', descending: false).snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const Center(child: Text("No appointments found."));

                  final allDocs = snapshot.data!.docs;
                  final filteredDocs = allDocs.where((doc) {
                    final d = doc.data() as Map<String, dynamic>? ?? {};
                    final status = (d['status'] ?? '').toString();
                    final patientName = _getPatientNameSync(d['patientId'] ?? '');
                    final matchesFilter = _selectedStatusFilter == "All" || status.toLowerCase() == _selectedStatusFilter.toLowerCase();
                    final matchesSearch = _searchQuery.isEmpty || patientName.toLowerCase().contains(_searchQuery.toLowerCase());
                    return matchesFilter && matchesSearch;
                  }).toList();

                  if (filteredDocs.isEmpty) return const Center(child: Text("No matching appointments."));

                  if (isWide) {
                    return SingleChildScrollView(
                      child: DataTable(
                        columnSpacing: 24,
                        columns: const [
                          DataColumn(label: Text("Patient")),
                          DataColumn(label: Text("Date")),
                          DataColumn(label: Text("Slot")),
                          DataColumn(label: Text("Bed")),
                          DataColumn(label: Text("Status")),
                          DataColumn(label: Text("Actions")),
                        ],
                        rows: filteredDocs.map((d) => _buildDataRowFromDoc(d)).toList(),
                      ),
                    );
                  } else {
                    return ListView.builder(
                      itemCount: filteredDocs.length,
                      itemBuilder: (context, idx) {
                        final doc = filteredDocs[idx];
                        final data = doc.data() as Map<String, dynamic>? ?? {};
                        final appointmentId = doc.id;
                        final patientId = data['patientId'] ?? '';
                        final patientName = _getPatientNameSync(patientId);
                        final status = (data['status'] ?? '').toString();
                        final slot = (data['slot'] ?? '').toString();
                        final bedName = data['bedName']?.toString();
                        final bedId = data['bedId']?.toString();
                        final dateTimestamp = data['date'] as Timestamp?;

                        return _buildAppointmentCard(
                          appointmentId: appointmentId,
                          patientId: patientId,
                          patientName: patientName,
                          status: status,
                          dateTimestamp: dateTimestamp,
                          slot: slot,
                          bedName: bedName,
                          oldBedId: bedId,
                        );
                      },
                    );
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // -------------------- AUTO PROCESSOR (CLIENT) --------------------
  void _startClientAutoProcessor() {
    // run once immediately
    _processDueAutoTasksClient();

    // then schedule periodic runs
    _clientProcessorTimer?.cancel();
    _clientProcessorTimer = Timer.periodic(const Duration(minutes: CLIENT_PROCESS_INTERVAL_MINUTES), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      _processDueAutoTasksClient();
    });
  }

  Future<void> _processDueAutoTasksClient() async {
    try {
      final now = DateTime.now();
      final snap = await FirebaseFirestore.instance
          .collection('appointments')
          .where('status', whereIn: ['pending', 'approved', 'rescheduled', 'showed'])
          .get();

      for (var doc in snap.docs) {
        final data = doc.data() as Map<String, dynamic>? ?? {};
        final appointmentId = doc.id;
        final status = (data['status'] ?? '').toString().toLowerCase();
        final Timestamp? dateTs = data['date'] as Timestamp?;
        final String slot = (data['slot'] as String?) ?? _slots.first;
        final int durationMinutes = (data['durationMinutes'] as int?) ?? DEFAULT_SESSION_DURATION_MINUTES;
        final String lastUpdatedBy = (data['lastUpdatedBy'] as String?) ?? 'unknown';

        // compute accurate slot start using date + slot
        final DateTime startDt = _slotStartDateTimeFor(dateTs, slot) ?? (dateTs?.toDate() ?? DateTime.fromMillisecondsSinceEpoch(0));

        // auto-missed: if now >= start + AUTO_MISSED_HOURS and no nurse action
        final missedTriggerTime = startDt.add(Duration(hours: AUTO_MISSED_HOURS));
        final alreadyFinal = status == 'missed' || status == 'completed' || status == 'rejected' || status == 'removed';

        if ((status == 'pending' || status == 'approved' || status == 'rescheduled') &&
            now.isAfter(missedTriggerTime) &&
            !alreadyFinal &&
            lastUpdatedBy != 'nurse') {
          // mark missed and attempt auto-reschedule
          await _handleAutoMissAndRescheduleClient(appointmentId, data);
        }

        // auto-complete: if status == 'showed' and now >= start + duration
        if (status == 'showed') {
          final completeTriggerTime = startDt.add(Duration(minutes: durationMinutes));
          if (now.isAfter(completeTriggerTime) && lastUpdatedBy != 'nurse') {
            await _systemUpdateStatus(appointmentId, 'completed');
          }
        }
      }
    } catch (e) {
      print("Client auto-processor error: $e");
    }
  }

  Future<void> _handleAutoMissAndRescheduleClient(String appointmentId, Map<String, dynamic> appointmentData) async {
    final firestore = FirebaseFirestore.instance;
    try {
      // mark missed (system origin)
      await _systemUpdateStatus(appointmentId, 'missed', extraFields: {'autoMissedAt': FieldValue.serverTimestamp()});

      final DateTime originalDate = (appointmentData['date'] as Timestamp?)?.toDate() ?? DateTime.now();
      final String currentSlot = appointmentData['slot'] ?? _slots.first;

      DateTime? selectedDate;
      String? selectedSlot;
      String? selectedBedId;

      for (int dayOffset = 1; dayOffset <= AUTO_RESCHEDULE_SEARCH_DAYS; dayOffset++) {
        final candidate = DateTime(originalDate.year, originalDate.month, originalDate.day).add(Duration(days: dayOffset));
        final onlyDate = DateTime(candidate.year, candidate.month, candidate.day);

        // fetch admin session statuses
        final adminSnap = await firestore.collection('session')
            .where('sessionDate', isEqualTo: Timestamp.fromDate(onlyDate))
            .get();
        final Map<String, bool> enabledMap = {for (var s in _slots) s: true};
        for (var d in adminSnap.docs) {
          final m = d.data() as Map<String, dynamic>? ?? {};
          final slot = m['slot']?.toString();
          final enabled = m['isActive'] as bool? ?? true;
          if (slot != null && enabledMap.containsKey(slot)) enabledMap[slot] = enabled;
        }

        for (String slot in _slots) {
          if (!(enabledMap[slot] ?? true)) continue;

          final tsStart = Timestamp.fromDate(onlyDate);
          final tsEnd = Timestamp.fromDate(onlyDate.add(const Duration(days: 1)));
          final slotSnap = await firestore.collection('appointments')
              .where('date', isGreaterThanOrEqualTo: tsStart)
              .where('date', isLessThan: tsEnd)
              .where('slot', isEqualTo: slot)
              .where('status', whereIn: ['pending','approved','rescheduled'])
              .get();

          if (slotSnap.docs.length >= MAX_SLOTS_PER_WINDOW) continue;

          // find bed with capacity
          final bedCounts = await _fetchBedAssignmentCounts(Timestamp.fromDate(onlyDate), slot);
          final bedsSnap = await firestore.collection('beds').where('isWorking', isEqualTo: true).orderBy('name').get();
          String? foundBedId;
          for (var b in bedsSnap.docs) {
            final bedId = b.id;
            final count = bedCounts[bedId] ?? 0;
            if (count < MAX_BED_CAPACITY) {
              foundBedId = bedId;
              break;
            }
          }

          selectedDate = onlyDate;
          selectedSlot = slot;
          selectedBedId = foundBedId;
          break;
        }
        if (selectedDate != null) break;
      }

      if (selectedDate != null && selectedSlot != null) {
        // Do transactional reschedule + optional bed assign
        final ok = await _assignBedAndUpdateAppointmentTransaction(
          appointmentId,
          status: 'rescheduled',
          date: Timestamp.fromDate(selectedDate),
          slot: selectedSlot,
          preferredBedId: selectedBedId,
          origin: 'system',
          extraFields: {'autoRescheduled': true},
        );
        if (!ok) {
          // if transaction fails, fallback to marking rescheduled without bed
          await _systemUpdateStatus(appointmentId, 'rescheduled', date: Timestamp.fromDate(selectedDate), slot: selectedSlot, extraFields: {'autoRescheduled': true});
        }
      } else {
        // unable to find slot; leave as missed (notification already created when marking missed)
      }
    } catch (e) {
      print("Auto-reschedule client failed for $appointmentId: $e");
    }
  }

  // Manual button to run auto-reschedule missed appointments
  Future<void> _autoRescheduleMissedAppointments() async {
    final snap = await FirebaseFirestore.instance.collection('appointments').where('status', isEqualTo: 'missed').get();
    for (var doc in snap.docs) {
      final data = doc.data() as Map<String, dynamic>? ?? {};
      await _handleAutoMissAndRescheduleClient(doc.id, data);
    }
    _showMessage("Auto-reschedule pass completed.");
  }
}

// -----------------------------------------------------------------
// RESCHEDULE DIALOG WIDGET
// Removed bed selection – dialog only picks date + slot. System auto-assigns bed.
// -----------------------------------------------------------------
class RescheduleDialog extends StatefulWidget {
  final String appointmentId;
  final String patientId;
  final String patientName;
  final DateTime initialDate;
  final String? initialSlot;
  final String? initialBedId;
  final List<String> slots;
  final bool isWideScreen;
  final Future<void> Function(String, String, {String? bedId, Timestamp? date, String? slot}) onConfirm;
  final Future<Map<String,int>> Function(dynamic, dynamic) fetchBedAssignmentCounts;

  const RescheduleDialog({
    super.key,
    required this.appointmentId,
    required this.patientId,
    required this.patientName,
    required this.initialDate,
    required this.initialSlot,
    required this.initialBedId,
    required this.slots,
    required this.isWideScreen,
    required this.onConfirm,
    required this.fetchBedAssignmentCounts,
  });

  @override
  State<RescheduleDialog> createState() => _RescheduleDialogState();
}

class _RescheduleDialogState extends State<RescheduleDialog> with SingleTickerProviderStateMixin {
  late DateTime _selectedDate;
  String? _selectedSlot;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.initialDate;
    _selectedSlot = widget.initialSlot;
    _tabController = TabController(length: 2, vsync: this);

    if (_selectedSlot != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _tabController.index = 1;
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final newDate = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (newDate != null && newDate != _selectedDate) {
      setState(() {
        _selectedDate = newDate;
        _selectedSlot = null;
        _tabController.index = 0;
      });
    }
  }

  void _onSlotSelect(String slot) {
    setState(() {
      _selectedSlot = slot;
      _tabController.animateTo(1);
    });
  }

  Future<Map<String, bool>> _fetchAdminSessionStatus(DateTime date) async {
    final DateTime onlyDate = DateTime(date.year, date.month, date.day);
    final snap = await FirebaseFirestore.instance
        .collection('session')
        .where('sessionDate', isEqualTo: Timestamp.fromDate(onlyDate))
        .get();

    final Map<String, bool> enabledMap = {for (var s in widget.slots) s: true};

    for (var doc in snap.docs) {
      final data = doc.data() as Map<String, dynamic>? ?? {};
      final slot = data['slot']?.toString();
      final enabled = data['isActive'] as bool? ?? true;
      if (slot != null && widget.slots.contains(slot)) {
        enabledMap[slot] = enabled;
      }
    }
    return enabledMap;
  }

  Future<Map<String, int>> _fetchAppointmentCounts(DateTime date) async {
    final DateTime onlyDate = DateTime(date.year, date.month, date.day);
    final Timestamp startOfDay = Timestamp.fromDate(onlyDate);
    final Timestamp endOfDay = Timestamp.fromDate(onlyDate.add(const Duration(days: 1)));

    final snap = await FirebaseFirestore.instance
        .collection('appointments')
        .where('date', isGreaterThanOrEqualTo: startOfDay)
        .where('date', isLessThan: endOfDay)
        .where('status', whereIn: ['pending', 'approved', 'rescheduled'])
        .get();

    final Map<String, int> slotCounts = {for (var s in widget.slots) s: 0};

    for (var doc in snap.docs) {
      final data = doc.data() as Map<String, dynamic>? ?? {};
      final slot = data['slot']?.toString();
      if (slot != null && slotCounts.containsKey(slot)) {
        slotCounts[slot] = slotCounts[slot]! + 1;
      }
    }
    return slotCounts;
  }

  Widget _buildSlotsTab() {
    final futureData = Future.wait([
      _fetchAdminSessionStatus(_selectedDate),
      _fetchAppointmentCounts(_selectedDate),
    ]);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: FutureBuilder<List<dynamic>>(
        future: futureData,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          if (!snapshot.hasData || snapshot.hasError) return Center(child: Text("Error loading slot data: ${snapshot.error ?? 'Unknown error'}", style: const TextStyle(color: Colors.red)));

          final Map<String, bool> enabledMap = snapshot.data![0] as Map<String, bool>;
          final Map<String, int> slotCounts = snapshot.data![1] as Map<String, int>;
          const int maxSlots = MAX_SLOTS_PER_WINDOW;

          return ListView(
            children: widget.slots.map((s) {
              int count = slotCounts[s] ?? 0;
              bool slotFull = count >= maxSlots;
              bool adminDisabled = !(enabledMap[s] ?? true);
              bool isAvailable = !slotFull && !adminDisabled;
              bool isSelected = _selectedSlot == s;

              String statusText = isAvailable ? "AVAILABLE" : (slotFull ? "FULL" : "CLOSED (Admin)");

              return Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
                child: Card(
                  elevation: 2,
                  child: ListTile(
                    leading: Icon(isSelected ? Icons.check_circle : (isAvailable ? Icons.check_circle_outline : Icons.cancel)),
                    title: Text(s, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text("Booked: $count / $maxSlots | Status: $statusText"),
                    trailing: ElevatedButton(
                      onPressed: isAvailable ? () => _onSlotSelect(s) : null,
                      child: Text(isSelected ? "Selected" : "Select"),
                    ),
                  ),
                ),
              );
            }).toList(),
          );
        },
      ),
    );
  }

  Widget _buildBedsTab() {
    // This tab is informational only now – no bed selection allowed.
    if (_selectedSlot == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.access_time_filled, color: Colors.red[400], size: 40),
              const SizedBox(height: 16),
              const Text("Slot Selection Required", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text("Please select a time slot first in the 'Slots' tab to check real-time bed availability."),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: FutureBuilder<Map<String, int>>(
        future: widget.fetchBedAssignmentCounts(_selectedDate, _selectedSlot!),
        builder: (context, assignmentSnap) {
          if (assignmentSnap.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          final bedCounts = assignmentSnap.data ?? {};

          return FutureBuilder<QuerySnapshot>(
            future: FirebaseFirestore.instance.collection('beds').where('isWorking', isEqualTo: true).orderBy('name').get(),
            builder: (context, bedsSnap) {
              if (bedsSnap.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
              if (!bedsSnap.hasData || bedsSnap.data!.docs.isEmpty) return const Center(child: Text("No working beds are registered."));

              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0, bottom: 16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Date: ${DateFormat('MMM d, yyyy').format(_selectedDate)}", style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                        Text("Slot: $_selectedSlot (Capacity: $MAX_BED_CAPACITY/Bed)", style: const TextStyle(fontSize: 14, color: Colors.grey)),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView(
                      children: bedsSnap.data!.docs.map((bedDoc) {
                        final bedId = bedDoc.id;
                        final bedData = bedDoc.data() as Map<String, dynamic>? ?? {};
                        final bedName = bedData['name'] ?? 'Bed ID: $bedId';
                        final assignedCount = bedCounts[bedId] ?? 0;
                        final isFull = assignedCount >= MAX_BED_CAPACITY;

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8.0),
                          child: Card(
                            child: ListTile(
                              title: Text(bedName, style: TextStyle(fontWeight: FontWeight.bold, color: isFull ? Colors.grey : Colors.black87)),
                              subtitle: Text("Assigned: $assignedCount / $MAX_BED_CAPACITY"),
                              trailing: isFull ? const Icon(Icons.block) : const Icon(Icons.check_circle_outline),
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
    final bool canConfirm = _selectedSlot != null;
    final dialogWidth = widget.isWideScreen ? 700.0 : MediaQuery.of(context).size.width * 0.9;
    final dialogHeight = widget.isWideScreen ? 600.0 : MediaQuery.of(context).size.height * 0.85;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: dialogWidth,
        height: dialogHeight,
        child: Column(
          children: [
            AppBar(
              backgroundColor: Colors.blue,
              title: Text("Reschedule Appointment for ${widget.patientName}"),
              leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.of(context).pop()),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text("Selected Date:", style: TextStyle(color: Colors.grey, fontSize: 13)),
                    Text(DateFormat('yyyy-MM-dd').format(_selectedDate), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: Colors.green)),
                  ]),
                  ElevatedButton.icon(
                    onPressed: () => _selectDate(context),
                    icon: const Icon(Icons.calendar_month),
                    label: const Text("Change Date"),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            TabBar(controller: _tabController, labelColor: Colors.blue, unselectedLabelColor: Colors.grey, tabs: const [Tab(text: "Slots"), Tab(text: "Beds")]),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildSlotsTab(),
                  _buildBedsTab(),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: ElevatedButton(
                onPressed: canConfirm ? () async {
                  final newStatus = "rescheduled";
                  await widget.onConfirm(widget.appointmentId, newStatus, date: Timestamp.fromDate(_selectedDate), slot: _selectedSlot);
                  if (mounted) Navigator.of(context).pop(true);
                } : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  minimumSize: const Size(double.infinity, 50),
                ),
                child: const Text("Confirm Reschedule (bed will be auto-assigned)"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
