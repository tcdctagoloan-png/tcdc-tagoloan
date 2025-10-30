import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
// Assuming 'book_page.dart' is in the correct location
import 'book_page.dart';

class PatientAppointmentsPage extends StatelessWidget {
  final String userId;
  const PatientAppointmentsPage({super.key, required this.userId});

  // --- Helper Functions (Static methods for utility) ---

  static Future<void> _cancelAppointment(
      String appointmentId, String? nurseId, DateTime date, String slot) async {
    await FirebaseFirestore.instance
        .collection('appointments')
        .doc(appointmentId)
        .update({'status': 'cancelled'});

    await FirebaseFirestore.instance.collection('notifications').add({
      'nurseId': nurseId ?? 'all',
      'title': "Appointment Cancelled",
      'message':
      "A patient cancelled their appointment on ${_formatDate(date)} at $slot.",
      'appointmentId': appointmentId,
      'read': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  static Future<void> _deleteAppointment(
      String appointmentId, String? nurseId, DateTime date, String slot) async {
    await FirebaseFirestore.instance
        .collection('appointments')
        .doc(appointmentId)
        .delete();

    await FirebaseFirestore.instance.collection('notifications').add({
      'nurseId': nurseId ?? 'all',
      'title': "Appointment Record Deleted",
      'message':
      "A patient deleted their appointment record on ${_formatDate(date)} at $slot.",
      'appointmentId': appointmentId,
      'read': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  static String _formatDate(DateTime date) {
    return "${date.month}/${date.day}/${date.year}";
  }

  // --- UI Build ---

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 900;

    // FIX: Use a SingleChildScrollView to wrap the content for all sizes
    // and rely on padding for spacing. This eliminates the AppBar overlap issue.
    return SingleChildScrollView(
      padding: isWide
          ? const EdgeInsets.fromLTRB(32, 24, 32, 24) // Generous padding for web
          : const EdgeInsets.all(16.0), // Standard padding for mobile
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800), // Max width for content consistency
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title and Description (mimics the style in your image)
              const Text(
                "My Appointments",
                style: TextStyle(
                    fontSize: 32, // Professional, large title
                    fontWeight: FontWeight.bold,
                    color: Colors.black87),
              ),
              const SizedBox(height: 8),
              Text(
                "View, reschedule, cancel, or review your dialysis appointments.",
                style: TextStyle(fontSize: 16, color: Colors.grey.shade700),
              ),
              const Divider(height: 30),

              // The main appointment list view
              _AppointmentListView(
                userId: userId,
                cancelAppointment: _cancelAppointment,
                deleteAppointment: _deleteAppointment,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------
// Appointment List View (Handles StreamBuilder)
// ---------------------------------------------------

class _AppointmentListView extends StatelessWidget {
  final String userId;
  final Function(String, String?, DateTime, String) cancelAppointment;
  final Function(String, String?, DateTime, String) deleteAppointment;

  const _AppointmentListView({
    required this.userId,
    required this.cancelAppointment,
    required this.deleteAppointment,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('appointments')
          .where('patientId', isEqualTo: userId)
          .orderBy('date', descending: true)
          .snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(
              child: Padding(
                  padding: EdgeInsets.only(top: 50),
                  child: CircularProgressIndicator(color: Colors.blue)));
        }
        if (!snap.hasData || snap.data!.docs.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(60.0),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.calendar_today_outlined, size: 50, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    "No appointments scheduled.",
                    style: TextStyle(fontSize: 18, color: Colors.black54),
                  ),
                  SizedBox(height: 8),
                  Text("Book your first session now!"),
                ],
              ),
            ),
          );
        }

        final appointments = snap.data!.docs;
        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(), // Handled by parent SingleChildScrollView
          itemCount: appointments.length,
          itemBuilder: (context, index) {
            final doc = appointments[index];
            final data = doc.data()! as Map<String, dynamic>;

            final date = (data['date'] as Timestamp).toDate();
            final status = data['status'] ?? "pending";

            return _AppointmentCard(
              docId: doc.id,
              data: data,
              date: date,
              status: status,
              cancelAppointment: cancelAppointment,
              deleteAppointment: deleteAppointment,
              userId: userId,
            );
          },
        );
      },
    );
  }
}

// ---------------------------------------------------
// Appointment Card (Individual Item UI/UX)
// ---------------------------------------------------

class _AppointmentCard extends StatelessWidget {
  final String docId;
  final Map<String, dynamic> data;
  final DateTime date;
  final String status;
  final String userId;
  final Function(String, String?, DateTime, String) cancelAppointment;
  final Function(String, String?, DateTime, String) deleteAppointment;

  const _AppointmentCard({
    required this.docId,
    required this.data,
    required this.date,
    required this.status,
    required this.userId,
    required this.cancelAppointment,
    required this.deleteAppointment,
  });

  // Helper: Reschedule logic
  void _reschedule(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Reschedule Appointment"),
        content: const Text(
          "Your current appointment will be marked as 'rescheduled'. You will be redirected to the booking page to pick a new date and time.",
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("Cancel")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.shade700, foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.pop(ctx);
              await FirebaseFirestore.instance
                  .collection('appointments')
                  .doc(docId)
                  .update({
                'status': 'rescheduled',
                'rescheduledAt': FieldValue.serverTimestamp(),
              });
              if (context.mounted) {
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => BookPage(userId: userId)));
              }
            },
            child: const Text("Proceed"),
          ),
        ],
      ),
    );
  }

  // Helper: Format time for AM/PM display
  String _formatTime(String timeSlot) {
    final originalSlot = data['slot'] ?? "N/A";
    if (originalSlot.contains("AM") || originalSlot.contains("PM")) {
      return originalSlot;
    }
    try {
      final parts = originalSlot.split(' - ');
      final start = _toAMPM(parts[0]);
      final end = _toAMPM(parts[1]);
      return "$start - $end";
    } catch (_) {
      return originalSlot;
    }
  }

  String _toAMPM(String time24) {
    try {
      final hour = int.parse(time24.split(':')[0]);
      final minute = time24.split(':')[1];
      final isPM = hour >= 12;
      final displayHour = hour == 0
          ? 12
          : (hour > 12 ? hour - 12 : hour);
      return "$displayHour:$minute ${isPM ? "PM" : "AM"}";
    } catch (_) {
      return time24;
    }
  }

  // Helper: Get status display properties
  Map<String, dynamic> _getStatusProps(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
        return {'color': Colors.green.shade700, 'icon': Icons.check_circle_outline, 'text': 'Approved'};
      case 'cancelled':
        return {'color': Colors.grey.shade500, 'icon': Icons.block, 'text': 'Cancelled'};
      case 'rejected':
        return {'color': Colors.red.shade700, 'icon': Icons.error_outline, 'text': 'Rejected'};
      case 'completed':
        return {'color': Colors.blue.shade700, 'icon': Icons.done_all, 'text': 'Completed'};
      case 'rescheduled':
        return {'color': Colors.purple.shade700, 'icon': Icons.schedule_send, 'text': 'Rescheduled'};
      default:
        return {'color': Colors.orange.shade700, 'icon': Icons.hourglass_empty, 'text': 'Pending'};
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusProps = _getStatusProps(status);
    final statusColor = statusProps['color'] as Color;
    final statusIcon = statusProps['icon'] as IconData;
    final statusText = statusProps['text'] as String;
    final slot = _formatTime(data['slot'] ?? "N/A");
    final nurseId = data['nurseId'] as String?;

    final isActionable = status == 'pending' || status == 'approved';
    final isDeletable = status == 'cancelled' || status == 'rejected' || status == 'rescheduled' || status == 'completed';

    final screenWidth = MediaQuery.of(context).size.width;
    // Buttons switch to vertical when screen is less than 600px wide
    final isWideEnoughForHorizontalButtons = screenWidth > 600;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 10),
      elevation: 3,
      // Use border color for visual status cue
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: statusColor.withOpacity(0.3), width: 2)
      ),
      child: Padding(
        padding: const EdgeInsets.all(18.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- Row 1: Status, Date, and Visual separation ---
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Icon and Status Text wrapped in a flexible container
                Flexible(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(statusIcon, color: statusColor, size: 24),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          statusText.toUpperCase(),
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: statusColor,
                              letterSpacing: 0.5),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                // Date Text
                Text(
                  "${date.month}/${date.day}/${date.year}",
                  style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.black87),
                ),
              ],
            ),

            // Thin line to separate header from details
            const Divider(height: 20, thickness: 0.5),

            // --- Row 2: Details (Time Slot, Bed, etc.) ---
            _detailRow(Icons.access_time, "Time Slot", slot),
            _detailRow(Icons.local_hospital, "Bed", data['bedName'] ?? 'Unassigned'),
            if (data['nurseName'] != null && data['nurseName'].isNotEmpty)
              _detailRow(Icons.person, "Nurse", data['nurseName']),

            // --- Row 3: Action Buttons (Responsive Layout) ---
            if (isActionable || isDeletable)
              Padding(
                padding: const EdgeInsets.only(top: 16.0),
                // Button layout changes based on screen width
                child: isWideEnoughForHorizontalButtons
                    ? Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (isActionable)
                      _ActionButton(
                        label: 'Reschedule',
                        icon: Icons.refresh,
                        color: Colors.blue.shade600,
                        onPressed: () => _reschedule(context),
                      ),
                    if (isActionable)
                      const SizedBox(width: 8),
                    if (isActionable)
                      _ActionButton(
                        label: 'Cancel',
                        icon: Icons.cancel_schedule_send,
                        color: Colors.red.shade600,
                        onPressed: () => _showCancelDialog(context, nurseId, slot),
                      ),
                    if (isDeletable) // Delete is a secondary action, so it's placed last.
                      const SizedBox(width: 8),
                    if (isDeletable)
                      _ActionButton(
                        label: 'Delete Record',
                        icon: Icons.delete_forever,
                        color: Colors.grey.shade600,
                        onPressed: () => _showDeleteDialog(context, nurseId, slot),
                      ),
                  ],
                )
                    : Column( // Vertical layout for smaller screens
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (isActionable) ...[
                      _ActionButton(
                        label: 'Reschedule',
                        icon: Icons.refresh,
                        color: Colors.blue.shade600,
                        onPressed: () => _reschedule(context),
                      ),
                      const SizedBox(height: 8),
                      _ActionButton(
                        label: 'Cancel',
                        icon: Icons.cancel_schedule_send,
                        color: Colors.red.shade600,
                        onPressed: () => _showCancelDialog(context, nurseId, slot),
                      ),
                      const SizedBox(height: 8),
                    ],
                    if (isDeletable)
                      _ActionButton(
                        label: 'Delete Record',
                        icon: Icons.delete_forever,
                        color: Colors.grey.shade600,
                        onPressed: () => _showDeleteDialog(context, nurseId, slot),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.black54),
          const SizedBox(width: 8),
          SizedBox(
            width: 90, // Fixed width for label for better alignment
            child: Text(
              "$label:",
              style: const TextStyle(fontWeight: FontWeight.w500, color: Colors.black87),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.w400),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  // Helper: Show cancel confirmation dialog (unchanged)
  Future<void> _showCancelDialog(BuildContext context, String? nurseId, String slot) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Confirm Cancellation"),
        content: const Text(
            "Are you sure you want to cancel this appointment? This action cannot be undone."),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text("Keep Appointment")),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade700, foregroundColor: Colors.white),
            child: const Text("Yes, Cancel"),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await cancelAppointment(docId, nurseId, date, slot);
    }
  }

  // Helper: Show delete confirmation dialog (unchanged)
  Future<void> _showDeleteDialog(BuildContext context, String? nurseId, String slot) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete Record"),
        content: const Text(
            "Are you sure you want to permanently delete this appointment record?"),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text("No")),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade700, foregroundColor: Colors.white),
            child: const Text("Yes, Delete"),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await deleteAppointment(docId, nurseId, date, slot);
    }
  }
}

// ---------------------------------------------------
// Custom Action Button Widget (unchanged for consistency)
// ---------------------------------------------------

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onPressed;

  const _ActionButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: color,
        side: BorderSide(color: color.withOpacity(0.5)),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}