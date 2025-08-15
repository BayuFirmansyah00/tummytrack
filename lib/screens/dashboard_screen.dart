import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../models/baby_model.dart';
import 'dart:async';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({Key? key}) : super(key: key);

  @override
  _DashboardScreenState createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _selectedIndex = 0;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String? _babyName;
  int _currentCarouselIndex = 0;

  @override
  void initState() {
    super.initState();
    _fetchBabyName();
  }

  void _fetchBabyName() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final babySnapshot = await _firestore
            .collection('users')
            .doc(user.uid)
            .collection('babies')
            .limit(1)
            .get();
        if (babySnapshot.docs.isNotEmpty) {
          final babyDoc = babySnapshot.docs.first.data();
          final babyModel = Provider.of<BabyModel>(context, listen: false);
          setState(() {
            _babyName = babyDoc['name'] ?? 'Baby John';
          });
          babyModel.updateName(babyDoc['name']);
          babyModel.updateGender(babyDoc['gender']);
          babyModel.updateBirthDate((babyDoc['birth_date'] is Timestamp)
              ? (babyDoc['birth_date'] as Timestamp).toDate()
              : DateTime.tryParse(babyDoc['birth_date'] ?? '') ?? DateTime.now());
          babyModel.updateAgeRange(babyDoc['age_range']);
          babyModel.updateRelationship(babyDoc['relationship']);
        }
      } else {
        setState(() {
          _babyName = 'Guest';
        });
      }
    } catch (e) {
      print('Error fetching baby data: $e');
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
    if (index != 0) {
      _navigateTo(index);
    }
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

  Future<void> _addSampleNotifications() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Silakan login terlebih dahulu')),
      );
      return;
    }

    final babyModel = Provider.of<BabyModel>(context, listen: false);
    final babyName = babyModel.name ?? 'Bayi';

    final notifications = [
      {
        'user_id': user.uid,
        'message': 'Waktunya sesi tummy time untuk $babyName!',
        'timestamp': Timestamp.fromDate(DateTime.now().subtract(const Duration(minutes: 30))),
        'type': 'tummy_time_reminder',
      },
      {
        'user_id': user.uid,
        'message': 'Matras IoT telah terhubung untuk $babyName',
        'timestamp': Timestamp.fromDate(DateTime.now()),
        'type': 'mat_connection_status',
      },
    ];

    final firestore = FirebaseFirestore.instance;
    for (var notification in notifications) {
      await firestore.collection('notifications').add(notification);
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Notifikasi sampel ditambahkan')),
    );
  }

  void _navigateTo(int index) {
    String route;
    switch (index) {
      case 1:
        route = '/tummy';
        break;
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
        SnackBar(content: Text('Navigation error: $error')),
      );
    });
  }

  Stream<QuerySnapshot> _getBabySessionsStream() {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      return _firestore
          .collection('users')
          .doc(user.uid)
          .collection('babies')
          .limit(1)
          .snapshots()
          .asyncMap((babySnapshot) async {
        if (babySnapshot.docs.isNotEmpty) {
          final babyDoc = babySnapshot.docs.first;
          return await babyDoc.reference.collection('tummy_time_sessions')
              .orderBy('createdAt', descending: true)
              .get();
        }
        return await _firestore.collection('empty').limit(0).get();
      });
    }
    return Stream.value(_firestore.collection('empty').limit(0).get() as QuerySnapshot);
  }

  List<FlSpot> _calculateProgress(List<Map<String, dynamic>> sessions) {
    final now = DateTime.now();
    final Map<int, int> dailyAchievements = {};

    for (var session in sessions) {
      try {
        DateTime sessionDate;
        if (session['createdAt'] is Timestamp) {
          sessionDate = (session['createdAt'] as Timestamp).toDate();
        } else {
          sessionDate = DateTime.tryParse(session['createdAt']?.toString() ?? '') ?? DateTime.now();
        }
        
        final daysDiff = now.difference(sessionDate).inDays;
        if (daysDiff >= 0 && daysDiff <= 6) {
          final dayIndex = 6 - daysDiff;
          int achievementCount = 0;
          
          if (session['achievements'] != null) {
            final achievements = session['achievements'] as List?;
            achievementCount = achievements?.where((a) => a == true).length ?? 0;
          }
          
          dailyAchievements[dayIndex] = (dailyAchievements[dayIndex] ?? 0) + achievementCount;
        }
      } catch (e) {
        print('Error processing session: $e');
      }
    }

    List<FlSpot> spots = [];
    for (int i = 0; i <= 6; i++) {
      final value = (dailyAchievements[i] ?? 0).toDouble();
      spots.add(FlSpot(i.toDouble(), value));
    }
    return spots;
  }

  double _getMaxY(List<FlSpot> spots) {
    if (spots.isEmpty) return 10.0; // Match the original maxY
    final maxValue = spots.map((spot) => spot.y).reduce((a, b) => a > b ? a : b);
    return maxValue > 10 ? maxValue + 2 : 10.0; // Ensure it doesn't exceed original maxY unless necessary
  }

  @override
  Widget build(BuildContext context) {
    final babyModel = Provider.of<BabyModel>(context);

    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(
                        Icons.person,
                        size: 40,
                        color: Color(0xFF00A3FF),
                      ),
                      onPressed: () {
                        Navigator.pushNamed(context, '/profile').then((value) {
                          print('Returned from /profile');
                        }).catchError((error) {
                          print('Navigation error to /profile: $error');
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Gagal navigasi ke profil: $error')),
                          );
                        });
                      },
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.notifications,
                        size: 24,
                        color: Color(0xFF00A3FF),
                      ),
                      onPressed: () {
                        Navigator.pushNamed(context, '/notification').then((value) {
                          print('Returned from /notification');
                        }).catchError((error) {
                          print('Navigation error to /notification: $error');
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Gagal navigasi ke notifikasi: $error')),
                          );
                        });
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Text(
                  'Hai, ${_babyName ?? babyModel.name ?? 'Baby John'}',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF333333),
                  ),
                ),
                const Text(
                  'Selamat Datang di aplikasi Tummy Track',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF666666),
                  ),
                ),
                const SizedBox(height: 16),
                Column(
                  children: [
                    CarouselSlider(
                      options: CarouselOptions(
                        height: 200,
                        enlargeCenterPage: true,
                        autoPlay: false,
                        enableInfiniteScroll: false,
                        viewportFraction: 0.9,
                        onPageChanged: (index, reason) {
                          setState(() {
                            _currentCarouselIndex = index;
                          });
                        },
                      ),
                      items: [
                        Image.asset('assets/images/card beranda 1.png'),
                        Image.asset('assets/images/card beranda 2.png'),
                        Image.asset('assets/images/card beranda 3.png'),
                        Image.asset('assets/images/card beranda 4.png'),
                        Image.asset('assets/images/card beranda 5.png'),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(5, (index) {
                        return Container(
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _currentCarouselIndex == index
                                ? const Color(0xFF00A3FF)
                                : Colors.grey[400],
                          ),
                        );
                      }),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  height: 200,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const Text(
                        'Tummy Time Track',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF333333),
                        ),
                      ),
                      const SizedBox(height: 8),
                      StreamBuilder<DateTime>(
                        stream: Stream.periodic(const Duration(seconds: 1), (i) => DateTime.now()),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData) return const Text('Loading...');
                          final now = snapshot.data!;
                          return Text(
                            '${now.day}-${now.month}-${now.year}, ${now.hour}:${now.minute.toString().padLeft(2, '0')} WIB',
                            style: const TextStyle(
                              fontSize: 16,
                              color: Colors.grey,
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 20),
                      Expanded(
                        child: StreamBuilder<QuerySnapshot>(
                          stream: _getBabySessionsStream(),
                          builder: (context, snapshot) {
                            if (snapshot.hasError) {
                              return const Center(child: Text('Error loading data'));
                            }
                            if (!snapshot.hasData) {
                              return const Center(child: CircularProgressIndicator());
                            }
                            
                            final sessions = snapshot.data!.docs.map((doc) => doc.data() as Map<String, dynamic>).toList();
                            final spots = _calculateProgress(sessions);
                            final maxY = _getMaxY(spots);

                            return LineChart(
                              LineChartData(
                                gridData: FlGridData(
                                  show: true,
                                  drawVerticalLine: false,
                                  horizontalInterval: 2,
                                  getDrawingHorizontalLine: (value) {
                                    return FlLine(
                                      color: Colors.grey[200]!,
                                      strokeWidth: 1,
                                    );
                                  },
                                ),
                                titlesData: FlTitlesData(
                                  bottomTitles: AxisTitles(
                                    sideTitles: SideTitles(
                                      showTitles: true,
                                      getTitlesWidget: (value, meta) {
                                        final days = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];
                                        if (value.toInt() >= 0 && value.toInt() < days.length) {
                                          return Text(
                                            days[value.toInt()],
                                            style: const TextStyle(
                                              color: Colors.grey,
                                              fontSize: 10,
                                            ),
                                          );
                                        }
                                        return const Text('');
                                      },
                                      reservedSize: 30,
                                    ),
                                  ),
                                  leftTitles: AxisTitles(
                                    sideTitles: SideTitles(
                                      showTitles: true,
                                      getTitlesWidget: (value, meta) {
                                        return Text(
                                          '${value.toInt()}',
                                          style: const TextStyle(
                                            color: Colors.grey,
                                            fontSize: 10,
                                          ),
                                        );
                                      },
                                      reservedSize: 30,
                                    ),
                                  ),
                                  topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                  rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                ),
                                borderData: FlBorderData(
                                  show: true,
                                  border: Border(
                                    bottom: BorderSide(color: Colors.grey[300]!, width: 1),
                                    left: BorderSide(color: Colors.grey[300]!, width: 1),
                                  ),
                                ),
                                minX: 0,
                                maxX: 6,
                                minY: 0,
                                maxY: maxY,
                                lineBarsData: [
                                  LineChartBarData(
                                    spots: spots,
                                    isCurved: true,
                                    color: const Color(0xFF00A3FF),
                                    barWidth: 3,
                                    dotData: FlDotData(show: true),
                                    belowBarData: BarAreaData(
                                      show: true,
                                      color: const Color(0xFF00A3FF).withOpacity(0.2),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 100),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.white,
        selectedItemColor: const Color(0xFF00A3FF),
        unselectedItemColor: Colors.grey[400],
        items: [
          BottomNavigationBarItem(
            icon: _buildIcon('assets/images/1home_active_icon.png', Icons.home),
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
    );
  }
}