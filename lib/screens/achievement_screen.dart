import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../models/baby_model.dart';

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
  bool _isSaving = false; // Flag to prevent multiple saves

  // Achievement texts akan diatur berdasarkan usia bayi
  List<String> _achievementTexts = [];

  @override
  void initState() {
    super.initState();
    _setAchievementTexts();
    // Reset achievements to false to match design (no pre-selection)
    _achievements = List<bool>.filled(_achievementTexts.length, false);
  }

  void _setAchievementTexts() {
    final babyModel = Provider.of<BabyModel>(context, listen: false);
    final birthDate = babyModel.birthDate;
    
    if (birthDate == null) {
      // Default untuk bayi tanpa tanggal lahir (anggap 0-3 bulan)
      _achievementTexts = [
        'Bayi bisa mengangkat kepala mandiri hingga setinggi 45 derajat?',
        'Bayi bisa menggerakkan kepala dari kiri/kanan ke tengah?',
        'Bayi bisa melihat dan menatap wajah Anda?',
        'Bayi bisa mengoceh spontan atau bereaksi dengan mengoceh?',
        'Bayi membalas tersenyum ketika diajak bicara/ tersenyum?',
        'Bayi bereaksi terkejut terhadap suara keras?',
        'Bayi mengenal ibu dengan pengelihatan, penciuman, pendengaran, kontak?',
      ];
      return;
    }

    final currentDate = DateTime.now();
    final ageDays = currentDate.difference(birthDate).inDays;

    if (ageDays <= 90) {
      // Usia 0-3 bulan
      _achievementTexts = [
        'Bayi bisa mengangkat kepala mandiri hingga setinggi 45 derajat?',
        'Bayi bisa menggerakkan kepala dari kiri/kanan ke tengah?',
        'Bayi bisa melihat dan menatap wajah Anda?',
        'Bayi bisa mengoceh spontan atau bereaksi dengan mengoceh?',
        'Bayi membalas tersenyum ketika diajak bicara/ tersenyum?',
        'Bayi bereaksi terkejut terhadap suara keras?',
        'Bayi mengenal ibu dengan pengelihatan, penciuman, pendengaran, kontak?',
      ];
    } else if (ageDays <= 180) {
      // Usia 4-6 bulan
      _achievementTexts = [
        'Bayi bisa berbalik dari telungkup ke telentang?',
        'Bayi bisa mengangkat kepala secara mandiri hingga tegak 90 derajat?',
        'Bayi bisa mempertahankan posisi kepala tetap tegak dan stabil?',
        'Bayi bisa menggenggam atau meraih mainan?',
        'Bayi bisa mengamati tangannya sendiri?',
        'Bayi mengeluarkan suara gembira bernada tinggi atau memekik?',
        'Bayi tersenyum ketika melihat mainan saat bermain sendiri?',
      ];
    } else {
      // Default untuk usia lainnya
      _achievementTexts = [
        'Bayi bisa mengangkat kepala mandiri hingga setinggi 45 derajat?',
        'Bayi bisa menggerakkan kepala dari kiri/kanan ke tengah?',
        'Bayi bisa melihat dan menatap wajah Anda?',
      ];
    }
  }

  Future<void> _saveAchievements() async {
    if (_isSaving) return; // Prevent multiple saves
    setState(() {
      _isSaving = true;
    });

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

          // Use server timestamp for date to ensure consistency
          final serverTimestamp = FieldValue.serverTimestamp();

          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .collection('babies')
              .doc(babyId)
              .collection('tummy_time_sessions')
              .add({
            'date': serverTimestamp, // Changed to server timestamp
            'duration': widget.duration,
            'mood': widget.mood,
            'achievements': _achievements,
            'achievement_texts': _achievementTexts, // Added to save texts for history
            'createdAt': serverTimestamp,
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
    } finally {
      setState(() {
        _isSaving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF79BCC1),
      body: SafeArea(
        child: Column(
          children: [
            // Header dengan back button dan title
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.black),
                    onPressed: widget.onClose,
                  ),
                  const Expanded(
                    child: Center(
                      child: Text(
                        'Tummy Time',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),
            // Content area
            Expanded(
              child: Container(
                width: double.infinity,
                margin: const EdgeInsets.only(top: 20),
                decoration: const BoxDecoration(
                  color: Color(0xFF79BCC1),
                ),
                child: Column(
                  children: [
                    // Drag indicator
                    Container(
                      margin: const EdgeInsets.only(top: 10, bottom: 20),
                      height: 4,
                      width: 40,
                      decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    // Ilustrasi ibu menggendong
                    Image.asset(
                      'assets/images/Bayitidur.png',
                      width: 550,
                      height: 100,
                      errorBuilder: (context, error, stackTrace) {
                        return const Icon(
                          Icons.child_care,
                          size: 50,
                          color: Colors.white,
                        );
                      },
                    ),
                    const SizedBox(height: 10),
                    // Track Pencapaian title
                    const Text(
                      'Track Pencapaian',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Achievements list
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        itemCount: _achievements.length,
                        itemBuilder: (context, index) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8.0),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      _achievements[index] = !_achievements[index];
                                    });
                                  },
                                  child: Container(
                                    width: 24,
                                    height: 24,
                                    margin: const EdgeInsets.only(top: 2),
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: _achievements[index]
                                          ? const Color(0xFF4CAF50)
                                          : Colors.transparent,
                                      border: Border.all(
                                        color: _achievements[index]
                                            ? const Color(0xFF4CAF50)
                                            : Colors.black54,
                                        width: 2,
                                      ),
                                    ),
                                    child: _achievements[index]
                                        ? const Icon(
                                            Icons.check,
                                            size: 16,
                                            color: Colors.white,
                                          )
                                        : null,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    index < _achievementTexts.length
                                        ? _achievementTexts[index]
                                        : 'Achievement ${index + 1}',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: Colors.black87,
                                      height: 1.3,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                    // Submit button
                    Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isSaving ? null : _saveAchievements,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: const Color(0xFF79BCC1),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                            elevation: 0,
                          ),
                          child: _isSaving
                              ? const CircularProgressIndicator(color: Color(0xFF79BCC1))
                              : const Text(
                                  'Kirim',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}