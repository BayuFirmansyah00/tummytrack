import 'package:flutter/material.dart';
// AchievementScreen no longer writes directly to Firestore; data is
// returned to the caller. Cloud/Firebase imports removed.
import 'package:provider/provider.dart';
import '../models/baby_model.dart';

class AchievementScreen extends StatefulWidget {
  final String duration;
  final String mood;
  final List<bool> achievements;
  final VoidCallback onClose;

  const AchievementScreen({
    super.key,
    required this.duration,
    required this.mood,
    required this.achievements,
    required this.onClose,
  });

  @override
  _AchievementScreenState createState() => _AchievementScreenState();
}

class _AchievementScreenState extends State<AchievementScreen>
    with TickerProviderStateMixin {
  late List<bool> _achievements;
  bool _isSaving = false;
  List<String> _achievementTexts = [];
  late AnimationController _slideController;
  late AnimationController _fadeController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _setAchievementTexts();
    _achievements = List<bool>.filled(_achievementTexts.length, false);

    // Initialize animations
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic),
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _fadeController, curve: Curves.easeOut));

    // Start animations
    _fadeController.forward();
    _slideController.forward();
  }

  @override
  void dispose() {
    _slideController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  void _setAchievementTexts() {
    final babyModel = Provider.of<BabyModel>(context, listen: false);
    final birthDate = babyModel.birthDate;

    if (birthDate == null) {
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
      _achievementTexts = [
        'Bayi bisa mengangkat kepala mandiri hingga setinggi 45 derajat?',
        'Bayi bisa menggerakkan kepala dari kiri/kanan ke tengah?',
        'Bayi bisa melihat dan menatap wajah Anda?',
      ];
    }
  }

  Future<void> _saveAchievements() async {
    // Instead of saving here (to avoid duplicate writes), return the
    // selected achievements back to the caller via Navigator.pop.
    // Caller (TummyTimeScreen) will perform the single, consolidated save.
    if (_isSaving) return;
    setState(() {
      _isSaving = true;
    });

    try {
      final result = {
        'achievements': _achievements,
        'achievement_texts': _achievementTexts,
        'duration': widget.duration,
        'mood': widget.mood,
      };
      Navigator.of(context).pop(result);
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
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Column(
            children: [
              // Enhanced Header
              _buildHeader(),

              // Main Content
              Expanded(
                child: SlideTransition(
                  position: _slideAnimation,
                  child: Container(
                    width: double.infinity,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(24),
                        topRight: Radius.circular(24),
                      ),
                    ),
                    child: Column(
                      children: [
                        // Drag indicator
                        Container(
                          margin: const EdgeInsets.only(top: 16, bottom: 8),
                          height: 4,
                          width: 40,
                          decoration: BoxDecoration(
                            color: const Color(0xFFE0E0E0),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),

                        // Session Summary Card
                        _buildSessionSummary(),

                        // Title Section
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 20),
                          child: Text(
                            'Track Pencapaian',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF1E1E1E),
                              letterSpacing: -0.5,
                            ),
                          ),
                        ),

                        // Age-based info badge
                        _buildAgeBadge(),

                        const SizedBox(height: 16),

                        // Achievements List
                        Expanded(child: _buildAchievementsList()),

                        // Enhanced Submit Button
                        _buildSubmitButton(),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white, size: 24),
              onPressed: widget.onClose,
            ),
          ),
          const Expanded(
            child: Center(
              child: Text(
                'Tummy Time Session',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _buildSessionSummary() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF79BCC1).withOpacity(0.1),
            const Color(0xFF79BCC1).withOpacity(0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF79BCC1).withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF79BCC1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.timer, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Sesi Selesai',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      widget.duration,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1E1E1E),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: _getMoodColor(widget.mood).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        widget.mood,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _getMoodColor(widget.mood),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAgeBadge() {
    final babyModel = Provider.of<BabyModel>(context, listen: false);
    final birthDate = babyModel.birthDate;
    String ageText = "0-3 bulan";

    if (birthDate != null) {
      final ageDays = DateTime.now().difference(birthDate).inDays;
      if (ageDays <= 90) {
        ageText = "0-3 bulan";
      } else if (ageDays <= 180) {
        ageText = "4-6 bulan";
      } else {
        ageText = "${(ageDays / 30).floor()} bulan";
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F9FF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF0EA5E9)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.child_care, size: 16, color: Color(0xFF0EA5E9)),
          const SizedBox(width: 8),
          Text(
            'Milestone untuk usia $ageText',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF0EA5E9),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAchievementsList() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      itemCount: _achievements.length,
      itemBuilder: (context, index) {
        return AnimatedContainer(
          duration: Duration(milliseconds: 200 + (index * 50)),
          curve: Curves.easeOutCubic,
          margin: const EdgeInsets.symmetric(vertical: 6),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () {
                setState(() {
                  _achievements[index] = !_achievements[index];
                });
              },
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color:
                      _achievements[index]
                          ? const Color(0xFF4CAF50).withOpacity(0.1)
                          : const Color(0xFFF8F9FA),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color:
                        _achievements[index]
                            ? const Color(0xFF4CAF50)
                            : const Color(0xFFE5E7EB),
                    width: _achievements[index] ? 2 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color:
                            _achievements[index]
                                ? const Color(0xFF4CAF50)
                                : Colors.transparent,
                        border: Border.all(
                          color:
                              _achievements[index]
                                  ? const Color(0xFF4CAF50)
                                  : const Color(0xFFBDBDBD),
                          width: 2,
                        ),
                      ),
                      child:
                          _achievements[index]
                              ? const Icon(
                                Icons.check,
                                size: 16,
                                color: Colors.white,
                              )
                              : null,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        index < _achievementTexts.length
                            ? _achievementTexts[index]
                            : 'Achievement ${index + 1}',
                        style: TextStyle(
                          fontSize: 14,
                          color:
                              _achievements[index]
                                  ? const Color(0xFF1E1E1E)
                                  : const Color(0xFF6B7280),
                          fontWeight:
                              _achievements[index]
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSubmitButton() {
    final completedCount = _achievements.where((a) => a).length;

    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Progress indicator
          if (completedCount > 0)
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF4CAF50).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.celebration,
                    color: Color(0xFF4CAF50),
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '$completedCount dari ${_achievements.length} milestone tercapai!',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF4CAF50),
                    ),
                  ),
                ],
              ),
            ),

          // Submit button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isSaving ? null : _saveAchievements,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF79BCC1),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
                shadowColor: Colors.transparent,
              ),
              child:
                  _isSaving
                      ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                      : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.save, size: 20),
                          SizedBox(width: 8),
                          Text(
                            'Simpan Capaian',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getMoodColor(String mood) {
    switch (mood.toLowerCase()) {
      case 'senang':
      case 'bahagia':
        return const Color(0xFF4CAF50);
      case 'sedih':
        return const Color(0xFF2196F3);
      case 'marah':
        return const Color(0xFFF44336);
      case 'rewel':
        return const Color(0xFFFF9800);
      default:
        return const Color(0xFF6B7280);
    }
  }
}
