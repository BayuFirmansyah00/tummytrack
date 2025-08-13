import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../models/notification_iten.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({Key? key}) : super(key: key);

  @override
  _NotificationScreenState createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _currentUserId = FirebaseAuth.instance.currentUser!.uid;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifikasi'),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          onPressed: () {
            Navigator.pop(context);
          },
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore
            .collection('notifications')
            .where('user_id', isEqualTo: _currentUserId)
            .where('type', whereIn: ['tummy_time_reminder', 'mat_connection_status'])
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('Tidak ada notifikasi'));
          }

          final notifications = snapshot.data!.docs
              .map((doc) => NotificationItem.fromFirestore(doc))
              .toList();

          final grouped = groupNotifications(notifications);

          return RefreshIndicator(
            onRefresh: () async {
              setState(() {}); // Trigger refresh
            },
            child: ListView.builder(
              padding: const EdgeInsets.all(16.0),
              itemCount: grouped.length,
              itemBuilder: (context, index) {
                final category = grouped[index].keys.first;
                final items = grouped[index][category]!;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Text(
                        category,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                    ...items.map((item) => ListTile(
                          leading: Icon(
                            item.type == 'tummy_time_reminder'
                                ? Icons.timer
                                : Icons.wifi,
                            color: const Color(0xFF7DD3FC),
                          ),
                          title: Text(item.message),
                          subtitle: Text(getRelativeTime(item.timestamp)),
                          onTap: () {
                            // Optional: Navigate to relevant screen, e.g., TummyTimeScreen for tummy time reminders
                            if (item.type == 'tummy_time_reminder') {
                              Navigator.pushNamed(context, '/tummy');
                            }
                          },
                        )),
                  ],
                );
              },
            ),
          );
        },
      ),
    );
  }

  List<Map<String, List<NotificationItem>>> groupNotifications(
      List<NotificationItem> notifications) {
    final tummyTimeList = <NotificationItem>[];
    final matStatusList = <NotificationItem>[];

    for (var item in notifications) {
      if (item.type == 'tummy_time_reminder') {
        tummyTimeList.add(item);
      } else if (item.type == 'mat_connection_status') {
        matStatusList.add(item);
      }
    }

    final grouped = <Map<String, List<NotificationItem>>>[];
    if (tummyTimeList.isNotEmpty) grouped.add({'Pengingat Tummy Time': tummyTimeList});
    if (matStatusList.isNotEmpty) grouped.add({'Status Koneksi Matras': matStatusList});

    return grouped;
  }

  String getRelativeTime(DateTime timestamp) {
    final now = DateTime.now();
    final diff = now.difference(timestamp);

    if (diff.inMinutes < 1) return 'Baru saja';
    if (diff.inMinutes < 60) return '${diff.inMinutes} menit lalu';
    if (diff.inHours < 24) return '${diff.inHours} jam lalu';
    return DateFormat('dd MMM yyyy').format(timestamp);
  }
}