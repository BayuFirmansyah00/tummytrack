import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AchievementScreen extends StatefulWidget {
  final String duration;
  final String mood;
  final List<bool> achievements;
  final VoidCallback onClose;

  const AchievementScreen({
    Key? key,
    required this.duration,
    required this.mood,
    required this.achievements,
    required this.onClose,
  }) : super(key: key);

  @override
  _AchievementScreenState createState() => _AchievementScreenState();
}

class _AchievementScreenState extends State<AchievementScreen> {
  late List<bool> _achievements;
  
  final List<String> _achievementTexts = [
    'Bayi bisa mengangkat kepala mandiri hingga setinggi 45 derajat?',
    'Bayi bisa menggerakkan kepala dari kiri/kanan ke tengah?',
    'Bayi bisa melihat dan menatap wajah Anda?',
    'Bayi bisa mengoceh spontan atau bereaksi dengan mengoceh?',
    'Bayi membalas tersenyum ketika diajak bicara/ tersenyum?',
  ];

  @override
  void initState() {
    super.initState();
    _achievements = List<bool>.from(widget.achievements);
  }

  Future<void> _saveAchievements() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final babySnapshot = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('babies')
            .limit(1)
            .get();
        if (babySnapshot.docs.isNotEmpty) {
          final babyDoc = babySnapshot.docs.first;
          final babyId = babyDoc.id;
          print('Saving session for baby: $babyId');

          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .collection('babies')
              .doc(babyId)
              .collection('tummy_time_sessions')
              .add({
            'date': Timestamp.now().toDate().toIso8601String(),
            'duration': widget.duration,
            'mood': widget.mood,
            'achievements': _achievements,
            'createdAt': FieldValue.serverTimestamp(),
          });
          print('Session saved successfully');
          widget.onClose();
        } else {
          throw Exception('No baby data found');
        }
      } else {
        throw Exception('No user logged in');
      }
    } catch (e) {
      print('Error saving achievements: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal menyimpan capaian: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 12),
                  height: 4,
                  width: 60,
                  decoration: BoxDecoration(
                    color: const Color(0xFF7DD3D8),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                
                const SizedBox(height: 20),
                const Icon(
                  Icons.check_circle_outline,
                  size: 60,
                  color: Color(0xFF4CAF50),
                ),
                const SizedBox(height: 16),
                
                const Text(
                  'Sesi Tummy Time Selesai!',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF333333),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                
                Text(
                  'Durasi: ${widget.duration}',
                  style: const TextStyle(
                    fontSize: 16,
                    color: Color(0xFF666666),
                  ),
                ),
                
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Mood: ',
                        style: const TextStyle(
                          fontSize: 16,
                          color: Color(0xFF666666),
                        ),
                      ),
                      Image.asset(
                        'assets/images/${widget.mood}.png',
                        width: 30,
                        height: 30,
                        errorBuilder: (context, error, stackTrace) {
                          return const Icon(Icons.error, color: Colors.red);
                        },
                      ),
                    ],
                  ),
                ),
                
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    'Pencapaian:',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF333333),
                    ),
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: _achievements.length,
                    itemBuilder: (context, index) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4.0),
                        child: Row(
                          children: [
                            GestureDetector(
                              onTap: () {
                                setState(() {
                                  _achievements[index] = !_achievements[index];
                                });
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                margin: const EdgeInsets.only(top: 2),
                                width: 22,
                                height: 22,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: _achievements[index] ? const Color(0xFF4CAF50) : Colors.transparent,
                                  border: Border.all(
                                    color: _achievements[index] ? const Color(0xFF4CAF50) : const Color(0xFF666666),
                                    width: 2,
                                  ),
                                ),
                                child: _achievements[index]
                                    ? const Icon(
                                        Icons.check,
                                        color: Colors.white,
                                        size: 14,
                                      )
                                    : null,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Text(
                                index < _achievementTexts.length ? _achievementTexts[index] : 'Achievement ${index + 1}',
                                style: const TextStyle(
                                  fontSize: 15,
                                  color: Color(0xFF333333),
                                  height: 1.4,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _saveAchievements,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4CAF50),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(25),
                        ),
                        elevation: 2,
                      ),
                      child: const Text(
                        'Kirim',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}