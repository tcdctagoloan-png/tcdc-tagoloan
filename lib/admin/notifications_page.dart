import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class AdminNotificationPage extends StatefulWidget {
  final String userId;
  final Function(int)? onUnreadCountChanged;

  const AdminNotificationPage({Key? key, required this.userId, this.onUnreadCountChanged}) : super(key: key);

  @override
  State<AdminNotificationPage> createState() => _AdminNotificationPageState();
}

class _AdminNotificationPageState extends State<AdminNotificationPage> {
  final Map<String, String> _userNamesCache = {};
  String _selectedFilter = 'all';

  @override
  void initState() {
    super.initState();
    _updateUnreadCount();
  }

  bool _isWideScreen(BuildContext context) => MediaQuery.of(context).size.width >= 900;

  void _showMessage(String message, {bool isError = false}) {
    bool isWideScreen = MediaQuery.of(context).size.width >= 900;
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
  }

  Future<String> _getUserName(String uid) async {
    if (_userNamesCache.containsKey(uid)) {
      return _userNamesCache[uid]!;
    }
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (doc.exists && doc.data() != null) {
        final name = doc.data()!['fullName'] ?? 'Unknown User';
        _userNamesCache[uid] = name;
        return name;
      }
    } catch (_) {}
    _userNamesCache[uid] = 'Unknown User';
    return 'Unknown User';
  }

  String _formatDate(Timestamp timestamp) {
    final date = timestamp.toDate();
    return DateFormat('MMM d, yyyy • hh:mm a').format(date);
  }

  Future<void> _markAsRead(String docId) async {
    try {
      await FirebaseFirestore.instance.collection('notifications').doc(docId).update({'isRead': true});
      _updateUnreadCount();
      _showMessage("Notification marked as read");
    } catch (e) {
      _showMessage("Failed to mark as read: $e", isError: true);
    }
  }

  Future<void> _deleteNotification(String docId) async {
    try {
      await FirebaseFirestore.instance.collection('notifications').doc(docId).delete();
      _updateUnreadCount();
      _showMessage("Notification deleted successfully");
    } catch (e) {
      _showMessage("Failed to delete notification: $e", isError: true);
    }
  }

  void _updateUnreadCount() {
    FirebaseFirestore.instance
        .collection('notifications')
        .where('role', isEqualTo: 'admin')
        .where('isRead', isEqualTo: false)
        .snapshots()
        .listen((snapshot) {
      if (mounted && widget.onUnreadCountChanged != null) {
        widget.onUnreadCountChanged!(snapshot.docs.length);
      }
    });
  }

  Widget _buildFilterChip(String label, String value) {
    return FilterChip(
      label: Text(label),
      selected: _selectedFilter == value,
      onSelected: (bool selected) {
        if (selected) {
          setState(() {
            _selectedFilter = value;
          });
        }
      },
      selectedColor: Colors.green.shade100,
      checkmarkColor: Colors.green,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Notifications",
                style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87),
              ),
              if (_isWideScreen(context))
                Wrap(
                  spacing: 8.0,
                  children: [
                    _buildFilterChip('All', 'all'),
                    _buildFilterChip('Patient', 'patient'),
                    _buildFilterChip('Nurse', 'nurse'),
                    _buildFilterChip('System', 'system'),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 24),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('notifications')
                  .where('role', isEqualTo: 'admin')
                  .where('type', isEqualTo: _selectedFilter == 'system' ? null : null) // Assuming 'system' notifications have no type or role field
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(
                    child: Text(
                      "No notifications found.",
                      style: TextStyle(color: Colors.grey, fontSize: 16),
                    ),
                  );
                }

                final filteredDocs = snapshot.data!.docs.where((doc) {
                  final notif = doc.data() as Map<String, dynamic>;
                  if (_selectedFilter == 'all') return true;
                  if (_selectedFilter == 'system') {
                    // Filter for system-generated notifications (no 'userId' or 'type' fields)
                    return notif['userId'] == null || notif['userId'].isEmpty;
                  }
                  return notif['type'] == _selectedFilter;
                }).toList();

                if (filteredDocs.isEmpty) {
                  return const Center(
                    child: Text(
                      "No notifications found for this filter.",
                      style: TextStyle(color: Colors.grey, fontSize: 16),
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: filteredDocs.length,
                  itemBuilder: (context, index) {
                    final doc = filteredDocs[index];
                    final notif = doc.data() as Map<String, dynamic>;
                    final senderId = notif['userId'] ?? '';
                    final isRead = notif['isRead'] ?? false;
                    final createdAt = notif['createdAt'] as Timestamp?;
                    final notificationType = notif['type'] ?? 'general';

                    return FutureBuilder<String>(
                      future: _getUserName(senderId),
                      builder: (context, userSnap) {
                        final senderName = userSnap.connectionState == ConnectionState.done
                            ? userSnap.data ?? 'Unknown User'
                            : 'Loading...';

                        return Dismissible(
                          key: Key(doc.id),
                          direction: DismissDirection.endToStart,
                          onDismissed: (_) => _deleteNotification(doc.id),
                          background: Container(
                            color: Colors.red,
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: const Icon(Icons.delete, color: Colors.white),
                          ),
                          child: Card(
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: BorderSide(color: Colors.grey.shade200)),
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  CircleAvatar(
                                    backgroundColor: isRead ? Colors.grey.shade300 : Colors.green.shade50,
                                    child: Icon(
                                      Icons.notifications,
                                      color: isRead ? Colors.grey : Colors.green,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          notif['title'] ?? 'Notification',
                                          style: TextStyle(
                                            fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
                                            color: isRead ? Colors.grey[700] : Colors.black,
                                            fontSize: 16,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          notif['message'] ?? 'No message',
                                          style: TextStyle(
                                            color: isRead ? Colors.grey : Colors.black54,
                                            fontSize: 14,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Row(
                                          children: [
                                            Icon(Icons.person, size: 16, color: Colors.grey.shade600),
                                            const SizedBox(width: 4),
                                            Text("From: $senderName", style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                            const SizedBox(width: 16),
                                            Icon(Icons.access_time, size: 16, color: Colors.grey.shade600),
                                            const SizedBox(width: 4),
                                            if (createdAt != null)
                                              Text(_formatDate(createdAt), style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (!isRead)
                                    IconButton(
                                      icon: const Icon(Icons.mark_email_read, color: Colors.blue),
                                      onPressed: () => _markAsRead(doc.id),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}