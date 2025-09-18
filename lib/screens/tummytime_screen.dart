import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:provider/provider.dart';
import '../models/baby_model.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'achievement_screen.dart';

class TummyTimeScreen extends StatefulWidget {
  @override
  _TummyTimeScreenState createState() => _TummyTimeScreenState();
}

class _TummyTimeScreenState extends State<TummyTimeScreen> with TickerProviderStateMixin {
  int _selectedIndex = 1;
  Timer? _timer;
  int _seconds = 0;
  int _minutes = 0;
  bool _isRunning = false;
  late AnimationController _rotationController;
  late AnimationController _progressController;
  String _selectedMood = 'Normal';
  late int _maxDurationSeconds;
  int _remainingSeconds = 0;
  List<bool> _achievements = [false, false, false, false, false, false, false];
  final List<String> _achievementTexts = [];
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
  List<List<bool>> _matrasGrid = List.generate(5, (_) => List.filled(11, false));
  String? _lastButtonPressed;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    // Inisialisasi awal _progressController dengan durasi default
    _progressController = AnimationController(
      duration: const Duration(seconds: 120), // Default 2 menit
      vsync: this,
    );
    final babyModel = Provider.of<BabyModel>(context, listen: false);
    _fetchBabyData(babyModel); // Ambil birthDate dari Firestore
    _rotationController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat();
    _initializeNotifications();
  }

  Future<void> _fetchBabyData(BabyModel babyModel) async {
    setState(() => _isLoading = true);
    final user = FirebaseAuth.instance.currentUser;
    print("User UID: ${user?.uid}");
    if (user != null && babyModel.babyId == null) {
      try {
        final babySnapshot = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('babies')
            .limit(1)
            .get();
        print("Baby snapshot: ${babySnapshot.docs.length} docs");
        if (babySnapshot.docs.isNotEmpty) {
          final babyDoc = babySnapshot.docs.first.data();
          final babyId = babySnapshot.docs.first.id;
          babyModel.updateBabyId(babyId);
          print("Baby ID set to: $babyId");
          // Ambil birthDate dari Firestore
          final birthDateStr = babyDoc['birth_date'] as String?;
          if (birthDateStr != null) {
            babyModel.updateBirthDate(DateTime.parse(birthDateStr));
            print("Birth date set to: $birthDateStr");
          } else {
            print("Birth date not found, using default");
            babyModel.updateBirthDate(DateTime.now().subtract(const Duration(days: 30))); // Default 1 bulan
          }
          _setDurationAndAchievements(babyModel);
          _listenToMatrasData(babyModel);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Data bayi tidak ditemukan')),
          );
        }
      } catch (e) {
        print("Fetch error: $e");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal mengambil data bayi: $e')),
        );
      }
    } else {
      print("User or babyId null: ${user?.uid}, ${babyModel.babyId}");
      _setDurationAndAchievements(babyModel); // Gunakan data existing
      _listenToMatrasData(babyModel);
    }
    setState(() => _isLoading = false);
  }

  Future<void> _initializeNotifications() async {
    const initializationSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    );
    await flutterLocalNotificationsPlugin.initialize(initializationSettings);
    if (await flutterLocalNotificationsPlugin
            .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
            ?.areNotificationsEnabled() ==
        false) {
      await flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
    }
  }

  void _setDurationAndAchievements(BabyModel babyModel) {
    final birthDate = babyModel.birthDate;
    print("Birth date from BabyModel: $birthDate");
    if (birthDate == null) {
      _maxDurationSeconds = 120; // Default 2 menit jika birthDate null
      _remainingSeconds = 120;
      _minutes = 2;
      _achievementTexts.clear();
      _achievementTexts.addAll([
        'Bayi bisa mengangkat kepala mandiri hingga setinggi 45 derajat?',
        'Bayi bisa menggerakkan kepala dari kiri/kanan ke tengah?',
        'Bayi bisa melihat dan menatap wajah Anda?',
        'Bayi bisa mengoceh spontan atau bereaksi dengan mengoceh?',
        'Bayi membalas tersenyum ketika diajak bicara/ tersenyum?',
        'Bayi bereaksi terkejut terhadap suara keras?',
        'Bayi mengenal ibu dengan pengelihatan, penciuman, pendengaran, kontak?',
      ]);
      _achievements = List.filled(7, false);
    } else {
      final currentDate = DateTime.now();
      final ageDays = currentDate.difference(birthDate).inDays;

      if (ageDays <= 90) {
        _maxDurationSeconds = 120;
        _remainingSeconds = 120;
        _minutes = 2;
        _achievementTexts.clear();
        _achievementTexts.addAll([
          'Bayi bisa mengangkat kepala mandiri hingga setinggi 45 derajat?',
          'Bayi bisa menggerakkan kepala dari kiri/kanan ke tengah?',
          'Bayi bisa melihat dan menatap wajah Anda?',
          'Bayi bisa mengoceh spontan atau bereaksi dengan mengoceh?',
          'Bayi membalas tersenyum ketika diajak bicara/ tersenyum?',
          'Bayi bereaksi terkejut terhadap suara keras?',
          'Bayi mengenal ibu dengan pengelihatan, penciuman, pendengaran, kontak?',
        ]);
        _achievements = List.filled(7, false);
      } else if (ageDays <= 180) {
        _maxDurationSeconds = 180;
        _remainingSeconds = 180;
        _minutes = 3;
        _achievementTexts.clear();
        _achievementTexts.addAll([
          'Bayi bisa berbalik dari telungkup ke telentang?',
          'Bayi bisa mengangkat kepala secara mandiri hingga tegak 90 derajat?',
          'Bayi bisa mempertahankan posisi kepala tetap tegak dan stabil?',
          'Bayi bisa menggenggam atau meraih mainan?',
          'Bayi bisa mengamati tangannya sendiri?',
          'Bayi mengeluarkan suara gembira bernada tinggi atau memekik?',
          'Bayi tersenyum ketika melihat mainan saat bermain sendiri?',
        ]);
        _achievements = List.filled(7, false);
      } else {
        _maxDurationSeconds = 240;
        _remainingSeconds = 240;
        _minutes = 4;
        _achievementTexts.clear();
        _achievementTexts.addAll([
          'Bayi bisa mengangkat kepala mandiri hingga setinggi 45 derajat?',
          'Bayi bisa menggerakkan kepala dari kiri/kanan ke tengah?',
          'Bayi bisa melihat dan menatap wajah Anda?',
        ]);
        _achievements = List.filled(3, false);
      }
    }
    _progressController.duration = Duration(seconds: _maxDurationSeconds);
    print("Max duration set to: $_maxDurationSeconds seconds");
  }

  void _listenToMatrasData(BabyModel babyModel) {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null && babyModel.babyId != null) {
      print("Listening to: matras_data/${user.uid}/${babyModel.babyId}");
      FirebaseDatabase.instance
          .ref('matras_data/${user.uid}/${babyModel.babyId}')
          .orderByKey()
          .limitToLast(10)
          .onValue
          .listen((event) {
        print("RTDB event: ${event.snapshot.value}");
        final data = event.snapshot.value as Map<dynamic, dynamic>?;
        if (data != null && data.isNotEmpty) {
          setState(() {
            _matrasGrid = List.generate(5, (_) => List.filled(11, false));
            data.forEach((key, value) {
              final button = value as String?;
              if (button != null && button.length >= 2) {
                try {
                  final row = 'ABCDE'.indexOf(button[0].toUpperCase());
                  final col = int.parse(button.substring(1)) - 1;
                  if (row >= 0 && row < 5 && col >= 0 && col < 11) {
                    _matrasGrid[row][col] = true;
                  }
                } catch (e) {
                  print("Invalid button: $button, error: $e");
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Data matras invalid: $button')),
                  );
                }
              }
            });
            _lastButtonPressed = data.entries.last.value as String?;
          });
        } else {
          setState(() {
            _matrasGrid = List.generate(5, (_) => List.filled(11, false));
            _lastButtonPressed = null;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Tidak ada data matras terbaru')),
          );
        }
      }, onError: (error) {
        print("RTDB error: $error");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error akses data matras: $error')),
        );
      });
    } else {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User atau baby ID tidak ditemukan')),
      );
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
    print("Starting timer, remaining: $_remainingSeconds");
    if (!_isRunning) {
      _isRunning = true;
      _progressController.forward(from: 0.0);
      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        setState(() {
          if (_remainingSeconds > 0) {
            _remainingSeconds--;
            _seconds = _remainingSeconds % 60;
            _minutes = _remainingSeconds ~/ 60;
            print("Timer: $_formattedTime");
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
      _matrasGrid = List.generate(5, (_) => List.filled(11, false));
      _lastButtonPressed = null;
    });
    _progressController.reset();
  }

  Future<void> _scheduleNextNotification() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final now = DateTime.now();
        final nextTime = now.add(const Duration(minutes: 1)); // Test dengan 1 menit
        final matrasTime = now.add(const Duration(minutes: 2)); // Test dengan 2 menit
        print("Scheduling notification at: $nextTime");
        await flutterLocalNotificationsPlugin.zonedSchedule(
          0,
          'Tummy Time Reminder',
          'Waktunya bayi Anda melaksanakan Tummy Time',
          tz.TZDateTime.from(nextTime, tz.local),
          const NotificationDetails(
            android: AndroidNotificationDetails(
              'tummy_time_channel',
              'Tummy Time Notifications',
              importance: Importance.high,
              priority: Priority.high,
            ),
          ),
          uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        );
        print("Notification scheduled");
        await FirebaseFirestore.instance.collection('notifications').add({
          'user_id': user.uid,
          'type': 'tummy_time_reminder',
          'message': 'Waktunya bayi Anda melaksanakan Tummy Time',
          'timestamp': Timestamp.fromDate(nextTime),
          'is_read': false,
        });
        await FirebaseFirestore.instance.collection('notifications').add({
          'user_id': user.uid,
          'type': 'mat_connection_status',
          'message': 'Saatnya untuk Tummy Time di matras',
          'timestamp': Timestamp.fromDate(matrasTime),
          'is_read': false,
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Notifikasi dijadwalkan')),
        );
      }
    } catch (e) {
      print("Notification error: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal menjadwalkan notifikasi: $e')),
      );
    }
  }

  List<String> _getPressedButtons() {
    List<String> pressed = [];
    for (int row = 0; row < 5; row++) {
      for (int col = 0; col < 11; col++) {
        if (_matrasGrid[row][col]) {
          pressed.add(buttonLabels[row][col]);
        }
      }
    }
    return pressed;
  }

  Future<void> _saveTummyTimeSession() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      final babyModel = Provider.of<BabyModel>(context, listen: false);
      if (user != null && babyModel.babyId != null) {
        final pressedButtons = _getPressedButtons();
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('babies')
            .doc(babyModel.babyId)
            .collection('tummy_time_sessions')
            .add({
          'date': Timestamp.now(),
          'duration': '${(_maxDurationSeconds - _remainingSeconds) ~/ 60} menit ${(_maxDurationSeconds - _remainingSeconds) % 60} detik',
          'mood': _selectedMood,
          'achievements': _achievements,
          'achievement_texts': _achievementTexts,
          'matras_buttons': pressedButtons,
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sesi tummy time tersimpan')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Data bayi atau pengguna belum lengkap')),
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
    ).then((_) {
      _saveTummyTimeSession();
      _scheduleNextNotification();
    });
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
    Navigator.of(context).pushReplacementNamed(route);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
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
                        const SizedBox(width: 48),
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
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          const Text(
                            'Matras Posisi',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF333333),
                            ),
                          ),
                          const SizedBox(height: 10),
                          GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 11,
                              mainAxisSpacing: 4,
                              crossAxisSpacing: 4,
                              childAspectRatio: 1,
                            ),
                            itemCount: 55,
                            itemBuilder: (context, index) {
                              final row = index ~/ 11;
                              final col = index % 11;
                              return Container(
                                decoration: BoxDecoration(
                                  color: _matrasGrid[row][col] ? const Color(0xFF4CAF50) : Colors.grey[300],
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: Text(
                                    buttonLabels[row][col],
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: _matrasGrid[row][col] ? Colors.white : Colors.black,
                                    ),
                                  ),
                                ),
                              );
                            },
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
                    const SizedBox(height: 20),
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
              icon: _buildIcon('assets/images/tummy_active_icon.png', Icons.child_care),
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

    paint.color = Colors.grey[300]!;
    canvas.drawCircle(center, radius, paint);

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

    if (isRunning) {
      paint.color = Colors.white.withOpacity(0.3);
      canvas.drawCircle(center, radius - 5, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

const List<List<String>> buttonLabels = [
  ["A1", "A2", "A3", "A4", "A5", "A6", "A7", "A8", "A9", "A10", "A11"],
  ["B1", "B2", "B3", "B4", "B5", "B6", "B7", "B8", "B9", "B10", "B11"],
  ["C1", "C2", "C3", "C4", "C5", "C6", "C7", "C8", "C9", "C10", "C11"],
  ["D1", "D2", "D3", "D4", "D5", "D6", "D7", "D8", "D9", "D10", "D11"],
  ["E1", "E2", "E3", "E4", "E5", "E6", "E7", "E8", "E9", "E10", "E11"],
];