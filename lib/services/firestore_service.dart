import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> saveBabyData(Map<String, dynamic> babyData) async {
    try {
      String? userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId != null) {
        final userDoc = _firestore.collection('users').doc(userId);
        await userDoc.collection('babies').add({
          'user_id': userId,
          'name': babyData['name'],
          'birth_date': babyData['birth_date'],
          'age_range': babyData['age_range'],
          'relationship': babyData['relationship'],
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      print("Error saving baby data: $e");
      throw e; // Lempar error agar bisa ditangani di UI jika diperlukan
    }
  }

  Future<void> saveTummyTimeSession(Map<String, dynamic> sessionData) async {
    try {
      await _firestore.collection('tummy_time_sessions').add({
        'baby_id': sessionData['baby_id'],
        'date': sessionData['date'] ?? FieldValue.serverTimestamp(),
        'duration': sessionData['duration'] ?? 0,
        'achievement': sessionData['achievement'] ?? '',
        'emotion': sessionData['emotion'] ?? '',
      });
    } catch (e) {
      print("Error saving tummy time session: $e");
      throw e;
    }
  }
}