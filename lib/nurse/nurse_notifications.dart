import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class NurseNotificationPage extends StatelessWidget {
  final String userId;
  const NurseNotificationPage({super.key, required this.userId});

  String _formatDate(Timestamp timestamp) {
    final date = timestamp.toDate();
    return DateFormat('MMM d, yyyy • hh:mm a').format(date);
  }

  Map<String, List<QueryDocumentSnapshot>> _groupByDate(
      List<QueryDocumentSnapshot> docs) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    Map<String, List<QueryDocumentSnapshot>> grouped = {
      "Today": [],
      "Yesterday": [],
      "Older": []
    };

    for (var doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      final Timestamp ts = data['createdAt'] ?? Timestamp.now();
      final date = ts.toDate();
      final dateOnly = DateTime(date.year, date.month, date.day);

      if (dateOnly.isAtSameMomentAs(today)) {
        grouped["Today"]!.add(doc);
      } else if (dateOnly.isAtSameMomentAs(yesterday)) {
        grouped["Yesterday"]!.add(doc);
      } else {
        grouped["Older"]!.add(doc);
      }
    }
    return grouped;
  }

  Future<void> _markAllRead(BuildContext context, String nurseId) async {
    final firestore = FirebaseFirestore.instance;
    final batch = firestore.batch();

    final snap = await firestore
        .collection('notifications')
        .where('nurseId', whereIn: [nurseId, 'all'])
        .where('read', isEqualTo: false)
        .get();

    for (var doc in snap.docs) {
      batch.update(doc.reference, {'read': true});
    }

    await batch.commit();

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("All notifications marked as read")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final String? nurseId = FirebaseAuth.instance.currentUser?.uid;

    if (nurseId == null) {
      return const Scaffold(
        body: Center(
          child: Text("User not logged in."),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        actions: [
          IconButton(
            icon: const Icon(Icons.done_all),
            tooltip: "Mark all as read",
            onPressed: () => _markAllRead(context, nurseId),
          ),
        ],
        backgroundColor: Colors.green.shade600,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('notifications')
            .where('nurseId', whereIn: [nurseId, 'all'])
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return const Center(child: Text("Something went wrong!"));
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text("No notifications yet.",
                  style: TextStyle(fontSize: 16)),
            );
          }

          final grouped = _groupByDate(snapshot.data!.docs);

          return ListView(
            padding: const EdgeInsets.symmetric(vertical: 12),
            children: grouped.entries
                .where((entry) => entry.value.isNotEmpty)
                .map((entry) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (entry.value.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Text(
                          entry.key,
                          style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey[700]),
                        ),
                      ),
                    ...entry.value.map((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      final isRead = data['read'] ?? false;
                      final title = data['title'] ?? "Notification";
                      final message = data['message'] ?? "";
                      final createdAt = data['createdAt'] as Timestamp?;

                      return Dismissible(
                        key: Key(doc.id),
                        direction: DismissDirection.endToStart,
                        onDismissed: (_) async {
                          await FirebaseFirestore.instance
                              .collection('notifications')
                              .doc(doc.id)
                              .delete();

                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text("Deleted: $title")),
                          );
                        },
                        background: Container(
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          alignment: Alignment.centerRight,
                          child: const Icon(Icons.delete, color: Colors.white),
                        ),
                        child: Card(
                          margin: const EdgeInsets.symmetric(vertical: 8),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16)),
                          elevation: 4,
                          child: ListTile(
                            contentPadding: const EdgeInsets.all(16),
                            leading: CircleAvatar(
                              radius: 24,
                              backgroundColor: isRead
                                  ? Colors.grey.shade300
                                  : Colors.green,
                              child: const Icon(Icons.notifications,
                                  color: Colors.white),
                            ),
                            title: Text(
                              title,
                              style: TextStyle(
                                fontWeight: isRead
                                    ? FontWeight.normal
                                    : FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 4),
                                Text(
                                  message,
                                  style: const TextStyle(fontSize: 14),
                                ),
                                if (createdAt != null)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4.0),
                                    child: Text(
                                      _formatDate(createdAt),
                                      style: const TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey),
                                    ),
                                  ),
                              ],
                            ),
                            onTap: () async {
                              if (!isRead) {
                                await FirebaseFirestore.instance
                                    .collection('notifications')
                                    .doc(doc.id)
                                    .update({'read': true});
                              }
                            },
                          ),
                        ),
                      );
                    }).toList(),
                  ],
                ),
              );
            }).toList(),
          );
        },
      ),
    );
  }
}