import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import 'dart:math' as math;
import 'package:permission_handler/permission_handler.dart';

class SplashScreenApp extends StatefulWidget {
  const SplashScreenApp({super.key});

  @override
  _SplashScreenAppState createState() => _SplashScreenAppState();
}

class _SplashScreenAppState extends State<SplashScreenApp>
    with TickerProviderStateMixin {
  late AnimationController _logoController;
  late AnimationController _fadeController;
  late AnimationController _textController;
  late AnimationController _bubbleController;
  
  late Animation<double> _logoScaleAnimation;
  late Animation<double> _logoOpacityAnimation;
  late Animation<Offset> _logoSlideAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _textSlideAnimation;
  late Animation<double> _textOpacityAnimation;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _startNavigationFlow();
  }

  void _initializeAnimations() {
    // Logo animations
    _logoController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _textController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _bubbleController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat();

    // Logo scale with bounce
    _logoScaleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _logoController,
      curve: Curves.elasticOut,
    ));

    // Logo opacity
    _logoOpacityAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _logoController,
      curve: const Interval(0.0, 0.5, curve: Curves.easeIn),
    ));

    // Logo slide from top
    _logoSlideAnimation = Tween<Offset>(
      begin: const Offset(0, -0.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _logoController,
      curve: Curves.easeOutBack,
    ));

    // Background fade
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeIn,
    ));

    // Text slide from bottom
    _textSlideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _textController,
      curve: Curves.easeOutCubic,
    ));

    // Text opacity
    _textOpacityAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _textController,
      curve: Curves.easeIn,
    ));

    // Start animations with delay
    _fadeController.forward();
    Future.delayed(const Duration(milliseconds: 200), () {
      _logoController.forward();
    });
    Future.delayed(const Duration(milliseconds: 600), () {
      _textController.forward();
    });
  }

  void _startNavigationFlow() {
    Timer(const Duration(milliseconds: 2500), () async {
      await _checkPermissionsAndNavigate();
    });
  }

  Future<void> _checkPermissionsAndNavigate() async {
    try {
      // Request permissions
      await [
        Permission.bluetoothScan,
        Permission.bluetoothConnect,
        Permission.notification,
        Permission.locationWhenInUse,
      ].request();

      // Check user authentication
      final user = FirebaseAuth.instance.currentUser;
      
      if (!mounted) return;

      if (user == null) {
        Navigator.pushReplacementNamed(context, '/login');
      } else {
        await user.reload();
        if (user.emailVerified) {
          final hasBabyData = await _hasBabyData(user.uid);
          Navigator.pushReplacementNamed(
            context,
            hasBabyData ? '/dashboard' : '/welcome',
          );
        } else {
          Navigator.pushReplacementNamed(context, '/login');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Silakan verifikasi email Anda terlebih dahulu'),
                backgroundColor: Colors.orange,
              ),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/login');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Terjadi kesalahan: $e')),
        );
      }
    }
  }

  Future<bool> _hasBabyData(String userId) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('babies')
          .limit(1)
          .get();
      return snapshot.docs.isNotEmpty && 
             snapshot.docs.first.data()['name'] != null;
    } catch (e) {
      return false;
    }
  }

  @override
  void dispose() {
    _logoController.dispose();
    _fadeController.dispose();
    _textController.dispose();
    _bubbleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFF79BCC1),
              const Color(0xFF9FD3D7),
              const Color(0xFFB0E3E0),
              Colors.white,
            ],
            stops: const [0.0, 0.3, 0.6, 1.0],
          ),
        ),
        child: Stack(
          children: [
            // Animated bubbles background
            _buildAnimatedBubbles(),
            
            // Main content
            Center(
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Spacer(flex: 2),
                    
                    // Logo with animations
                    SlideTransition(
                      position: _logoSlideAnimation,
                      child: FadeTransition(
                        opacity: _logoOpacityAnimation,
                        child: ScaleTransition(
                          scale: _logoScaleAnimation,
                          child: _buildLogo(),
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 40),
                    
                    // App name with animation
                    SlideTransition(
                      position: _textSlideAnimation,
                      child: FadeTransition(
                        opacity: _textOpacityAnimation,
                        child: Column(
                          children: [
                            const Text(
                              'TummyTrack',
                              style: TextStyle(
                                fontSize: 36,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                letterSpacing: 2,
                                shadows: [
                                  Shadow(
                                    blurRadius: 10,
                                    color: Colors.black26,
                                    offset: Offset(0, 2),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Smart Baby Monitoring',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.white.withOpacity(0.9),
                                fontWeight: FontWeight.w300,
                                letterSpacing: 1,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    
                    const Spacer(flex: 2),
                    
                    // Loading indicator
                    SlideTransition(
                      position: _textSlideAnimation,
                      child: FadeTransition(
                        opacity: _textOpacityAnimation,
                        child: Column(
                          children: [
                            SizedBox(
                              width: 40,
                              height: 40,
                              child: CircularProgressIndicator(
                                strokeWidth: 3,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white.withOpacity(0.8),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Loading...',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.white.withOpacity(0.7),
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 60),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogo() {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.white.withOpacity(0.3),
            spreadRadius: 10,
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
          BoxShadow(
            color: const Color(0xFF79BCC1).withOpacity(0.5),
            spreadRadius: 5,
            blurRadius: 20,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white,
          border: Border.all(
            color: Colors.white.withOpacity(0.5),
            width: 4,
          ),
        ),
        child: ClipOval(
          child: Image.asset(
            'assets/images/logo.jpg',
            width: 180,
            height: 180,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return Container(
                width: 180,
                height: 180,
                decoration: BoxDecoration(
                  color: const Color(0xFF79BCC1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.child_care,
                  size: 80,
                  color: Colors.white,
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildAnimatedBubbles() {
    return AnimatedBuilder(
      animation: _bubbleController,
      builder: (context, child) {
        return Stack(
          children: List.generate(15, (index) {
            final random = math.Random(index);
            final size = 20.0 + random.nextDouble() * 80;
            final left = random.nextDouble() * 
                         MediaQuery.of(context).size.width;
            final animationValue = (_bubbleController.value + 
                                   random.nextDouble()) % 1.0;
            final top = MediaQuery.of(context).size.height * 
                       (1 - animationValue);
            
            return Positioned(
              left: left,
              top: top,
              child: Opacity(
                opacity: (0.1 + random.nextDouble() * 0.2) * 
                        (1 - animationValue),
                child: Container(
                  width: size,
                  height: size,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.3),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.5),
                      width: 2,
                    ),
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}