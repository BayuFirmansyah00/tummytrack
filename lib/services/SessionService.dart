import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SessionService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> saveSession(String duration, String mood, List<bool> achievements) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final babySnapshot = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('babies')
          .limit(1)
          .get();
      if (babySnapshot.docs.isNotEmpty) {
        final babyDoc = babySnapshot.docs.first;
        await babyDoc.reference.collection('tummy_time_sessions').add({
          'date': DateTime.now().toIso8601String(),
          'duration': duration,
          'mood': mood,
          'achievements': achievements,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
    }
  }
}