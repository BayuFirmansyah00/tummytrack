import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'achievement_screen.dart';
import 'package:provider/provider.dart';
import '../models/baby_model.dart';

class TummyTimeScreen extends StatefulWidget {
  @override
  _TummyTimeScreenState createState() => _TummyTimeScreenState();
}

class _TummyTimeScreenState extends State<TummyTimeScreen>
    with TickerProviderStateMixin {
  int _selectedIndex = 1; // Tummy is index 1
  Timer? _timer;
  int _seconds = 0;
  int _minutes = 0; // Will be set based on age
  bool _isRunning = false;
  late AnimationController _rotationController;
  late AnimationController _progressController;
  String _selectedMood = 'Normal';
  late int _maxDurationSeconds; // Will be set based on age
  int _remainingSeconds = 0; // Will be set based on age
  List<bool> _achievements = [false, false, false, false, false, false, false];
  final List<String> _achievementTexts = []; // Will be set based on age

  @override
  void initState() {
    super.initState();
    final babyModel = Provider.of<BabyModel>(context, listen: false);
    _setDurationAndAchievements(babyModel);
    _rotationController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    );
    _progressController = AnimationController(
      duration: Duration(seconds: _maxDurationSeconds),
      vsync: this,
    );
  }

  void _setDurationAndAchievements(BabyModel babyModel) {
    final birthDate = babyModel.birthDate;
    if (birthDate == null) {
      _maxDurationSeconds = 5;
      _remainingSeconds = 5;
      _minutes = 0;
      _achievementTexts.clear();
      _achievementTexts.addAll([
        'Bayi bisa mengangkat kepala mandiri hingga setinggi 45 derajat?',
        'Bayi bisa menggerakkan kepala dari kiri/kanan ke tengah?',
        'Bayi bisa melihat dan menatap wajah Anda?',
      ]);
      _achievements = List.filled(3, false);
      return;
    }

    final currentDate = DateTime.now();
    final ageDays = currentDate.difference(birthDate).inDays;

    if (ageDays <= 90) {
      _maxDurationSeconds = 5;
      _remainingSeconds = 5;
      _minutes = 0;
      _achievementTexts.clear();
      _achievementTexts.addAll([
        'Bayi bisa mengangkat kepala mandiri hingga setinggi 45 derajat?',
        'Bayi bisa menggerakkan kepala dari kiri/kanan ke tengah?',
        'Bayi bisa melihat dan menatap wajah Anda?',
      ]);
      _achievements = List.filled(3, false);
    } else if (ageDays <= 180) {
      _maxDurationSeconds = 5;
      _remainingSeconds = 5;
      _minutes = 0;
      _achievementTexts.clear();
      _achievementTexts.addAll([
        'Bayi bisa mengangkat kepala mandiri hingga setinggi 45 derajat?',
        'Bayi bisa menggerakkan kepala dari kiri/kanan ke tengah?',
        'Bayi bisa melihat dan menatap wajah Anda?',
        'Bayi bisa mengoceh spontan atau bereaksi dengan mengoceh?',
        'Bayi membalas tersenyum ketika diajak bicara/ tersenyum?',
      ]);
      _achievements = List.filled(5, false);
    } else {
      _maxDurationSeconds = 5;
      _remainingSeconds = 5;
      _minutes = 0;
      _achievementTexts.clear();
      _achievementTexts.addAll([
        'Bayi bisa mengangkat kepala mandiri hingga setinggi 45 derajat?',
        'Bayi bisa menggerakkan kepala dari kiri/kanan ke tengah?',
        'Bayi bisa melihat dan menatap wajah Anda?',
      ]);
      _achievements = List.filled(3, false);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _rotationController.dispose();
    _progressController.dispose();
    super.dispose();
  }

  void _startTimer() {
    if (!_isRunning) {
      _isRunning = true;
      _rotationController.repeat();
      _progressController.forward();
      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        setState(() {
          if (_remainingSeconds > 0) {
            _remainingSeconds--;
            _seconds = _remainingSeconds % 60;
            _minutes = _remainingSeconds ~/ 60;
          } else {
            _pauseTimer();
            _timer?.cancel();
            _showAchievementDialog();
          }
        });
      });
    }
  }

  void _pauseTimer() {
    if (_isRunning) {
      _isRunning = false;
      _timer?.cancel();
      _rotationController.stop();
      _progressController.stop();
    }
  }

  void _resetTimer() {
    _timer?.cancel();
    final babyModel = Provider.of<BabyModel>(context, listen: false);
    _setDurationAndAchievements(babyModel);
    setState(() {
      _isRunning = false;
    });
    _rotationController.reset();
    _progressController.reset();
  }

  Future<void> _saveTummyTimeSession() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final babySnapshot = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('babies')
            .limit(1)
            .get();
        if (babySnapshot.docs.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Data bayi belum diatur, silakan lengkapi di profil')),
          );
          return;
        }
        final babyDoc = babySnapshot.docs.first;
        await babyDoc.reference.collection('tummy_time_sessions').add({
          'date': DateTime.now().toIso8601String(),
          'duration': '${(_maxDurationSeconds - _remainingSeconds) ~/ 60} menit ${(_maxDurationSeconds - _remainingSeconds) % 60} detik',
          'mood': _selectedMood,
          'achievements': _achievements,
          'createdAt': FieldValue.serverTimestamp(),
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sesi tummy time tersimpan')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal menyimpan sesi: $e')),
      );
    }
  }

  void _showAchievementDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AchievementScreen(
          duration: '${(_maxDurationSeconds - _remainingSeconds) ~/ 60} menit ${(_maxDurationSeconds - _remainingSeconds) % 60} detik',
          mood: _selectedMood,
          achievements: List<bool>.from(_achievements),
          onClose: () {
            Navigator.of(context).pop();
            _resetTimer();
          },
        );
      },
    );
  }

  String get _formattedTime {
    return '${_minutes.toString().padLeft(2, '0')}:${_seconds.toString().padLeft(2, '0')}';
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
    _navigateTo(index);
  }

  void _navigateTo(int index) {
    String route;
    switch (index) {
      case 0:
        route = '/dashboard';
        break;
      case 1:
        route = '/tummy'; // Already on this page, no navigation
        return;
      case 2:
        route = '/history';
        break;
      case 3:
        route = '/profile';
        break;
      default:
        return;
    }
    Navigator.of(context).pushReplacementNamed(route).then((value) {
      print('Returned from $route');
    }).catchError((error) {
      print('Navigation error to $route: $error');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal navigasi ke $route: $error')),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              const Text(
                'Tummy Time',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF333333),
                ),
              ),
              const SizedBox(height: 20),
              Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 200,
                    height: 200,
                    child: CircularProgressIndicator(
                      value: _progressController.value,
                      strokeWidth: 12,
                      backgroundColor: Colors.grey[300],
                      valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF7DD3D8)),
                    ),
                  ),
                  AnimatedBuilder(
                    animation: _rotationController,
                    builder: (context, child) {
                      return Transform.rotate(
                        angle: _rotationController.value * 2 * math.pi,
                        child: Image.asset(
                          'assets/images/tummy_baby.png',
                          width: 150,
                          height: 150,
                        ),
                      );
                    },
                  ),
                  Positioned(
                    top: 70,
                    child: Text(
                      _formattedTime,
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF333333),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton(
                    onPressed: _isRunning ? _pauseTimer : _startTimer,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isRunning ? Colors.red : const Color(0xFF7DD3D8),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      _isRunning ? 'Jeda' : 'Mulai',
                      style: const TextStyle(fontSize: 16, color: Colors.white),
                    ),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton(
                    onPressed: _resetTimer,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey[400],
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Ulangi',
                      style: TextStyle(fontSize: 16, color: Colors.white),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const Text(
                'Pilih Mood Bayi',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF333333),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: ['Normal', 'Senang', 'Menangis'].map((mood) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedMood = mood;
                        });
                      },
                      child: Image.asset(
                        'assets/images/$mood.png',
                        width: 60,
                        height: 60,
                        color: _selectedMood == mood ? null : Colors.grey[400],
                      ),
                    ),
                  );
                }).toList(),
              ),
              const Spacer(),
            ],
          ),
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.white,
        selectedItemColor: const Color(0xFF7DD3D8),
        unselectedItemColor: Colors.grey[400],
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'Beranda',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.baby_changing_station_outlined),
            activeIcon: Icon(Icons.baby_changing_station),
            label: 'Tummy',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.history_outlined),
            activeIcon: Icon(Icons.history),
            label: 'Riwayat',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: 'Profil',
          ),
        ],
      ),
    );
  }
}