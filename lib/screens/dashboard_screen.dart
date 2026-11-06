import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../models/baby_model.dart';
import 'dart:async';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  _DashboardScreenState createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> with TickerProviderStateMixin {
  int _selectedIndex = 0;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String? _babyName;
  int _currentCarouselIndex = 0;
  
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _fetchBabyName();
  }

  void _initializeAnimations() {
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideController, curve: Curves.easeOutBack));
    
    _fadeController.forward();
    _slideController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
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
          babyModel.updateBirthDate(
            (babyDoc['birth_date'] is Timestamp)
                ? (babyDoc['birth_date'] as Timestamp).toDate()
                : DateTime.tryParse(babyDoc['birth_date'] ?? '') ?? DateTime.now(),
          );
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
    Navigator.of(context).pushReplacementNamed(route);
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF79BCC1),
            Color(0xFF9FD3D7),
          ],
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Column(
                  children: [
                    const Text(
                      'TummyTrack',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    StreamBuilder<DateTime>(
                      stream: Stream.periodic(const Duration(seconds: 1), (i) => DateTime.now()),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) return const SizedBox();
                        final now = snapshot.data!;
                        return Text(
                          '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')} WIB',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.white.withOpacity(0.9),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 25),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: const Icon(Icons.child_care, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Hai, Selamat Datang!',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.white70,
                        ),
                      ),
                      Text(
                        _babyName ?? 'Baby John',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCarouselSection() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              'Tips & Informasi',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF333333),
              ),
            ),
          ),
          const SizedBox(height: 15),
          CarouselSlider(
            options: CarouselOptions(
              height: 180,
              enlargeCenterPage: true,
              autoPlay: true,
              autoPlayInterval: const Duration(seconds: 4),
              enableInfiniteScroll: true,
              viewportFraction: 0.85,
              onPageChanged: (index, reason) {
                setState(() {
                  _currentCarouselIndex = index;
                });
              },
            ),
            items: [
              _buildCarouselCard('assets/images/card beranda 1.png', 0),
              _buildCarouselCard('assets/images/card beranda 2.png', 1),
              _buildCarouselCard('assets/images/card beranda 3.png', 2),
              _buildCarouselCard('assets/images/card beranda 4.png', 3),
              _buildCarouselCard('assets/images/card beranda 5.png', 4),
            ],
          ),
          const SizedBox(height: 15),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (index) {
              return AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: _currentCarouselIndex == index ? 24 : 8,
                height: 8,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  color: _currentCarouselIndex == index
                      ? const Color(0xFF79BCC1)
                      : Colors.grey[300],
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildCarouselCard(String imagePath, int index) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Image.asset(
          imagePath,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF79BCC1).withOpacity(0.7),
                    const Color(0xFF9FD3D7).withOpacity(0.7),
                  ],
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Center(
                child: Icon(Icons.image, size: 50, color: Colors.white),
              ),
            );
          },
        ),
      ),
    );
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
              return await babyDoc.reference
                  .collection('tummy_time_sessions')
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

  double? _parseToDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) {
      try {
        return double.parse(value);
      } catch (e) {
        return null;
      }
    }
    return null;
  }

  double _getSafeMaxY(List<FlSpot> spots) {
    if (spots.isEmpty) return 10.0;
    try {
      final maxValue = spots.map((s) => s.y).reduce((a, b) => a > b ? a : b);
      return maxValue < 1 ? 10.0 : maxValue;
    } catch (e) {
      return 10.0;
    }
  }

  Widget _buildErrorState() {
    return Container(
      padding: const EdgeInsets.all(30),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(Icons.error_outline, color: Colors.red, size: 40),
          ),
          const SizedBox(height: 20),
          const Text(
            'Terjadi Kesalahan',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF374151),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Periksa koneksi internet Anda',
            style: TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return Container(
      padding: const EdgeInsets.all(40),
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            strokeWidth: 3,
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF79BCC1)),
          ),
          SizedBox(height: 20),
          Text(
            'Memuat data...',
            style: TextStyle(
              fontSize: 16,
              color: Color(0xFF6B7280),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(30),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(25),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF79BCC1).withOpacity(0.1),
                  const Color(0xFF9FD3D7).withOpacity(0.1),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(
              Icons.timeline_outlined,
              size: 50,
              color: Color(0xFF79BCC1),
            ),
          ),
          const SizedBox(height: 25),
          const Text(
            'Belum Ada Data',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF374151),
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Mulai sesi tummy time untuk\nmelihat progress perkembangan',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: Color(0xFF6B7280),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 25),
          ElevatedButton.icon(
            onPressed: () => Navigator.pushNamed(context, '/tummy'),
            icon: const Icon(Icons.play_arrow, color: Colors.white),
            label: const Text('Mulai Sesi', style: TextStyle(color: Colors.white, fontSize: 16)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF79BCC1),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(IconData icon, String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [color.withOpacity(0.1), color.withOpacity(0.05)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 24, color: color),
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF6B7280),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChartSection(List<Map<String, dynamic>> sessions, List<FlSpot> spots) {
    final totalMinutes = sessions.fold(0.0, (sum, session) {
      final duration = _parseToDouble(session['duration']) ?? 0.0;
      return sum + duration;
    });
    final avgMinutes = sessions.isNotEmpty ? totalMinutes / sessions.length : 0.0;
    final maxY = _getSafeMaxY(spots);

    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF79BCC1), Color(0xFF9FD3D7)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.timeline, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 15),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Progress Tummy Time',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF333333),
                      ),
                    ),
                    Text(
                      '7 hari terakhir',
                      style: TextStyle(
                        fontSize: 14,
                        color: Color(0xFF666666),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 25),
          Row(
            children: [
              _buildStatCard(Icons.timer_outlined, 'Total', '${totalMinutes.toInt()}m', const Color(0xFF79BCC1)),
              const SizedBox(width: 12),
              _buildStatCard(Icons.trending_up, 'Rata-rata', '${avgMinutes.toInt()}m', const Color(0xFF4CAF50)),
              const SizedBox(width: 12),
              _buildStatCard(Icons.calendar_today, 'Sesi', '${sessions.length}x', const Color(0xFFFF9800)),
            ],
          ),
          const SizedBox(height: 30),
          SizedBox(
            height: 250,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: true,
                  drawHorizontalLine: true,
                  verticalInterval: 1,
                  horizontalInterval: maxY > 15 ? 5 : (maxY > 8 ? 3 : 2),
                  getDrawingVerticalLine: (value) => FlLine(
                    color: const Color(0xFFF1F3F4),
                    strokeWidth: 1,
                    dashArray: [5, 5],
                  ),
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: const Color(0xFFF1F3F4),
                    strokeWidth: 1,
                    dashArray: value == 0 ? null : [5, 5],
                  ),
                ),
                titlesData: FlTitlesData(
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final days = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];
                        if (value.toInt() >= 0 && value.toInt() < days.length) {
                          return Container(
                            margin: const EdgeInsets.only(top: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFF79BCC1).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              days[value.toInt()],
                              style: const TextStyle(
                                color: Color(0xFF79BCC1),
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          );
                        }
                        return const SizedBox();
                      },
                      reservedSize: 35,
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        if (value == 0) return const SizedBox();
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: Text(
                            '${value.toInt()}m',
                            style: const TextStyle(
                              color: Color(0xFF9CA3AF),
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        );
                      },
                      reservedSize: 40,
                      interval: maxY > 15 ? 5 : (maxY > 8 ? 3 : 2),
                    ),
                  ),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(
                  show: true,
                  border: const Border(
                    bottom: BorderSide(color: Color(0xFFE5E7EB), width: 2),
                    left: BorderSide(color: Color(0xFFE5E7EB), width: 2),
                  ),
                ),
                minX: 0,
                maxX: 6,
                minY: 0,
                maxY: maxY * 1.2,
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    curveSmoothness: 0.35,
                    gradient: const LinearGradient(
                      colors: [Color(0xFF79BCC1), Color(0xFF9FD3D7)],
                    ),
                    barWidth: 4,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
                        radius: 6,
                        color: const Color(0xFF79BCC1),
                        strokeWidth: 3,
                        strokeColor: Colors.white,
                      ),
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          const Color(0xFF79BCC1).withOpacity(0.3),
                          const Color(0xFF79BCC1).withOpacity(0.1),
                          const Color(0xFF79BCC1).withOpacity(0.05),
                        ],
                      ),
                    ),
                  ),
                ],
                lineTouchData: LineTouchData(
                  enabled: true,
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (touchedSpot) => const Color(0xFF79BCC1),
                    tooltipRoundedRadius: 12,
                    tooltipPadding: const EdgeInsets.all(12),
                    getTooltipItems: (touchedSpots) {
                      return touchedSpots.map((touchedSpot) {
                        final days = ['Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu'];
                        final dayName = touchedSpot.x.toInt() < days.length
                            ? days[touchedSpot.x.toInt()]
                            : 'Hari ${touchedSpot.x.toInt() + 1}';
                        return LineTooltipItem(
                          '$dayName\n${touchedSpot.y.toInt()} menit',
                          const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        );
                      }).toList();
                    },
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SlideTransition(
          position: _slideAnimation,
          child: Column(
            children: [
              _buildHeader(),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      _buildCarouselSection(),
                      StreamBuilder<QuerySnapshot>(
                        stream: _getBabySessionsStream(),
                        builder: (context, snapshot) {
                          if (snapshot.hasError) {
                            return _buildErrorState();
                          }
                          if (!snapshot.hasData) {
                            return _buildLoadingState();
                          }

                          final sessions = snapshot.data!.docs.map((doc) {
                            final data = doc.data() as Map<String, dynamic>;
                            return {
                              ...data,
                              'duration': _parseToDouble(data['duration']) ?? 0.0,
                              'timestamp': data['timestamp'],
                            };
                          }).toList();

                          final spots = _calculateProgress(sessions);

                          if (spots.isEmpty || sessions.isEmpty) {
                            return _buildEmptyState();
                          }

                          return _buildChartSection(sessions, spots);
                        },
                      ),
                      const SizedBox(height: 100),
                    ],
                  ),
                ),
              ),
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
          selectedItemColor: const Color(0xFF79BCC1),
          unselectedItemColor: Colors.grey[400],
          selectedFontSize: 12,
          unselectedFontSize: 12,
          elevation: 0,
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
      ),);
  }
}
