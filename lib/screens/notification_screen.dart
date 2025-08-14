import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../models/notification_item.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({Key? key}) : super(key: key);

  @override
  _NotificationScreenState createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _currentUserId = user.uid;
    }
  }

  String _getRelativeDate(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);
    if (difference.inDays == 0) return 'Hari ini';
    if (difference.inDays == 1) return 'Kemarin';
    return DateFormat('dd MMM yyyy').format(timestamp);
  }

  @override
  Widget build(BuildContext context) {
    if (_currentUserId == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Notifikasi'),
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back_ios, color: Colors.black),
          ),
        ),
        body: const Center(child: Text('Silakan login untuk melihat notifikasi')),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Notifikasi', style: TextStyle(color: Colors.black87)),
        backgroundColor: Colors.white,
        elevation: 2,
        shadowColor: Colors.black12,
        centerTitle: true,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore
            .collection('notifications')
            .where('user_id', isEqualTo: _currentUserId)
            .where('type', whereIn: ['tummy_time_reminder', 'mat_connection_status'])
            .orderBy('timestamp', descending: true)
            .limit(50)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            print('Error fetching notifications: ${snapshot.error}');
            return const Center(child: Text('Gagal memuat notifikasi. Coba lagi nanti.'));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.notifications_off, size: 60, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('Tidak ada notifikasi', style: TextStyle(fontSize: 18, color: Colors.grey)),
                  Text(
                    'Notifikasi akan muncul di sini saat ada pembaruan.',
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }

          final notifications = snapshot.data!.docs
              .map((doc) => NotificationItem.fromFirestore(doc))
              .toList();

          // Group by relative date
          Map<String, List<NotificationItem>> groupedByDate = {};
          for (var item in notifications) {
            String dateKey = _getRelativeDate(item.timestamp);
            if (!groupedByDate.containsKey(dateKey)) {
              groupedByDate[dateKey] = [];
            }
            groupedByDate[dateKey]!.add(item);
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16.0),
            itemCount: groupedByDate.length,
            itemBuilder: (context, index) {
              String date = groupedByDate.keys.elementAt(index);
              List<NotificationItem> items = groupedByDate[date]!;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Text(
                      date,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF333333),
                      ),
                    ),
                  ),
                  ...items.map((item) {
                    IconData icon = item.type == 'tummy_time_reminder'
                        ? Icons.timer
                        : Icons.favorite; // Hati untuk matras
                    Color iconColor = item.type == 'tummy_time_reminder'
                        ? const Color(0xFF00A3FF)
                        : const Color(0xFFFF4081); // Biru untuk timer, pink untuk matras

                    return Container(
                      margin: const EdgeInsets.only(bottom: 8.0),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 5,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: ListTile(
                        leading: Icon(icon, color: iconColor),
                        title: Text(
                          item.type == 'tummy_time_reminder'
                              ? 'Hai Mom!'
                              : 'Matras Ready!',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF333333),
                          ),
                        ),
                        subtitle: Text(
                          item.message,
                          style: const TextStyle(fontSize: 14, color: Color(0xFF666666)),
                        ),
                        trailing: Text(
                          getRelativeTime(item.timestamp),
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                        onTap: () {
                          if (item.type == 'tummy_time_reminder') {
                            Navigator.pushNamed(context, '/tummy');
                          } else if (item.type == 'mat_connection_status') {
                            Navigator.pushNamed(context, '/mat-status');
                          }
                        },
                      ),
                    );
                  }),
                ],
              );
            },
          );
        },
      ),
    );
  }

  String getRelativeTime(DateTime timestamp) {
    final now = DateTime.now();
    final diff = now.difference(timestamp);

    if (diff.inMinutes < 1) return 'Baru saja';
    if (diff.inMinutes < 60) return '${diff.inMinutes} menit';
    if (diff.inHours < 24) return '${diff.inHours} jam';
    return '${diff.inHours ~/ 24} hari';
  }
}