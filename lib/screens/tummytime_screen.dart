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
    )..repeat();
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
      _progressController.forward(from: 0.0);
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

  Widget _buildIcon(String assetPath, IconData fallbackIcon) {
    return Image.asset(
      assetPath,
      width: 24,
      height: 24,
      errorBuilder: (context, error, stackTrace) {
        return Icon(fallbackIcon, size: 24);
      },
    );
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
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () => _navigateTo(0),
                  ),
                  const Text(
                    'Tummy Time',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF333333),
                    ),
                  ),
                  const SizedBox(width: 48), // Placeholder for symmetry
                ],
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: 300,
                height: 300,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CustomPaint(
                      size: const Size(300, 300),
                      painter: ProgressPainter(_progressController.value, _isRunning),
                    ),
                    Positioned(
                      top: 120,
                      child: Text(
                        _formattedTime,
                        style: const TextStyle(
                          fontSize: 40,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF333333),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 60,
                      child: ElevatedButton(
                        onPressed: _isRunning ? _pauseTimer : _startTimer,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _isRunning ? Colors.red : const Color(0xFF4CAF50),
                          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          _isRunning ? 'Jeda' : 'Mulai',
                          style: const TextStyle(fontSize: 18, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Mood baby',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF333333),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: ['Normal', 'Menangis', 'Senang'].map((mood) {
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedMood = mood;
                      });
                    },
                    child: Column(
                      children: [
                        Container(
                          width: 70,
                          height: 70,
                          decoration: BoxDecoration(
                            color: const Color(0xFF79BCC1),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: _selectedMood == mood ? const Color(0xFF7DD3D8) : Colors.transparent,
                              width: 3,
                            ),
                          ),
                          child: Center(
                            child: Image.asset(
                              'assets/images/${mood.toLowerCase()}.png',
                              width: 55,
                              height: 55,
                              errorBuilder: (context, error, stackTrace) {
                                return Icon(
                                  Icons.face,
                                  size: 55,
                                  color: Colors.white,
                                );
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          mood,
                          style: TextStyle(
                            fontSize: 12,
                            color: _selectedMood == mood ? const Color(0xFF7DD3D8) : Colors.grey[600],
                            fontWeight: _selectedMood == mood ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
              const Spacer(),
            ],
          ),
        ),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: _onItemTapped,
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.white,
          selectedItemColor: const Color(0xFF7DD3D8),
          unselectedItemColor: Colors.grey[400],
          items: [
            BottomNavigationBarItem(
              icon: _buildIcon('assets/images/home_active_icon.png', Icons.home),
              label: 'Beranda',
            ),
            BottomNavigationBarItem(
              icon: _buildIcon('assets/images/1tummy_active_icon.png', Icons.child_care),
              label: 'Tummy',
            ),
            BottomNavigationBarItem(
              icon: _buildIcon('assets/images/history_active_icon.png', Icons.history),
              label: 'Riwayat',
            ),
            BottomNavigationBarItem(
              icon: _buildIcon('assets/images/profile_active_icon.png', Icons.person),
              label: 'Profil',
            ),
          ],
        ),
      ),
    );
  }
}

class ProgressPainter extends CustomPainter {
  final double progress;
  final bool isRunning;

  ProgressPainter(this.progress, this.isRunning);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 10;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.round;

    // Background circle
    paint.color = Colors.grey[300]!;
    canvas.drawCircle(center, radius, paint);

    // Progress arc with gradient
    final rect = Rect.fromCircle(center: center, radius: radius);
    paint.shader = const SweepGradient(
      colors: [Color(0xFF7DD3D8), Color(0xFF4CAF50), Color(0xFFFFA726)],
      startAngle: 0.0,
      endAngle: 2 * math.pi,
    ).createShader(rect);
    canvas.drawArc(
      rect,
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      paint,
    );

    // Add subtle rotation effect
    if (isRunning) {
      paint.color = Colors.white.withOpacity(0.3);
      canvas.drawCircle(center, radius - 5, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}