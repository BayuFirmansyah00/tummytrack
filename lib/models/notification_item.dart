import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationItem {
  final String id;
  final String userId;
  final String type;
  final String message;
  final DateTime timestamp;
  final bool isRead;

  NotificationItem({
    required this.id,
    required this.userId,
    required this.type,
    required this.message,
    required this.timestamp,
    this.isRead = false,
  });

  factory NotificationItem.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return NotificationItem(
      id: doc.id,
      userId: data['user_id'] ?? '',
      type: data['type'] ?? '',
      message: data['message'] ?? '',
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isRead: data['is_read'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'user_id': userId,
      'type': type,
      'message': message,
      'timestamp': Timestamp.fromDate(timestamp),
      'is_read': isRead,
    };
  }
}