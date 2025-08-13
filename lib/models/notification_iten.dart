import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationItem {
  final String id;
  final String message;
  final DateTime timestamp;
  final String userId;
  final String type;

  NotificationItem({
    required this.id,
    required this.message,
    required this.timestamp,
    required this.userId,
    required this.type,
  });

  factory NotificationItem.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return NotificationItem(
      id: doc.id,
      message: data['message'] ?? '',
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      userId: data['user_id'] ?? '',
      type: data['type'] ?? 'unknown',
    );
  }
}