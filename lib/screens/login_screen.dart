import 'package:TummyTrack/models/user_model.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with TickerProviderStateMixin {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _obscureText = true;
  bool _isLoading = false;
  bool _isGoogleLoading = false;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.5),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic),
    );

    _animationController.forward();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _checkAndSetLinkedDevice(String userId) async {
    try {
      final userModel = Provider.of<UserModel>(context, listen: false);
      final rtdbRef = FirebaseDatabase.instance.ref(
        'users/$userId/linkedDevices',
      );
      final snapshot = await rtdbRef.get();

      if (snapshot.exists && snapshot.value != null) {
        final linkedDevices = snapshot.value as Map;
        if (linkedDevices.isNotEmpty) {
          final deviceId = linkedDevices.keys.first as String;
          userModel.setLinkedDevice(deviceId);
          print('Linked device found: $deviceId');
        }
      } else {
        userModel.setLinkedDevice(null);
      }
    } catch (e) {
      print('Error checking linked device: $e');
      final userModel = Provider.of<UserModel>(context, listen: false);
      userModel.setLinkedDevice(null);
    }
  }

  Future<bool> _hasBabyData(String userId) async {
    try {
      final docs = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('babies')
          .limit(1)
          .get();
      return docs.docs.isNotEmpty &&
          docs.docs.any((doc) => doc.data()['name'] != null);
    } catch (e) {
      print('Error checking baby data: $e');
      return false;
    }
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() {
      _isGoogleLoading = true;
    });

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final user = await authService.signInWithGoogle();

      if (user != null) {
        // Get or create user document
        final userDocRef = FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid);
        
        final userDoc = await userDocRef.get();
        
        Map<String, dynamic> firestoreData = {};
        
        if (userDoc.exists) {
          firestoreData = userDoc.data() as Map<String, dynamic>;
        } else {
          // Create new user document for Google sign-in
          firestoreData = {
            'uid': user.uid,
            'email': user.email ?? '',
            'name': user.displayName ?? '',
            'created_at': FieldValue.serverTimestamp(),
            'updated_at': FieldValue.serverTimestamp(),
          };
          await userDocRef.set(firestoreData);
        }

        // Set user model
        final userModel = Provider.of<UserModel>(context, listen: false);
        userModel.setUser(user, firestoreData);
        
        // Check linked device
        await _checkAndSetLinkedDevice(user.uid);

        // Navigate based on baby data
        final hasBabyData = await _hasBabyData(user.uid);
        
        if (mounted) {
          Navigator.pushReplacementNamed(
            context,
            hasBabyData ? '/dashboard' : '/welcome',
          );
        }
      } else {
        _showSnackBar('Login dengan Google dibatalkan', isError: true);
      }
    } on FirebaseAuthException catch (e) {
      String errorMessage;
      switch (e.code) {
        case 'account-exists-with-different-credential':
          errorMessage = 'Akun sudah ada dengan metode login berbeda';
          break;
        case 'invalid-credential':
          errorMessage = 'Kredensial tidak valid';
          break;
        case 'operation-not-allowed':
          errorMessage = 'Operasi tidak diizinkan';
          break;
        case 'user-disabled':
          errorMessage = 'Akun dinonaktifkan';
          break;
        case 'user-not-found':
          errorMessage = 'Pengguna tidak ditemukan';
          break;
        default:
          errorMessage = 'Login dengan Google gagal: ${e.message}';
      }
      _showSnackBar(errorMessage, isError: true);
    } catch (e) {
      print('Google Sign-In error: $e');
      _showSnackBar('Terjadi kesalahan saat login dengan Google', isError: true);
    } finally {
      if (mounted) {
        setState(() {
          _isGoogleLoading = false;
        });
      }
    }
  }

  void _login() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final authService = Provider.of<AuthService>(context, listen: false);
    try {
      final user = await authService.signIn(
        _emailController.text.trim(),
        _passwordController.text,
      );

      if (user != null && user.emailVerified) {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

        Map<String, dynamic> firestoreData = {};
        if (userDoc.exists) {
          firestoreData = userDoc.data() as Map<String, dynamic>;
        }

        final userModel = Provider.of<UserModel>(context, listen: false);
        userModel.setUser(user, firestoreData);
        await _checkAndSetLinkedDevice(user.uid);

        final hasBabyData = await _hasBabyData(user.uid);
        
        if (mounted) {
          Navigator.pushReplacementNamed(
            context,
            hasBabyData ? '/dashboard' : '/welcome',
          );
        }
      } else if (user != null && !user.emailVerified) {
        _showSnackBar(
          'Silakan verifikasi email Anda terlebih dahulu',
          isError: true,
        );
      } else {
        _showSnackBar('Gagal mendapatkan data pengguna', isError: true);
      }
    } on FirebaseAuthException catch (e) {
      String errorMessage;
      switch (e.code) {
        case 'user-not-found':
          errorMessage = 'Pengguna tidak ditemukan';
          break;
        case 'wrong-password':
          errorMessage = 'Kata sandi salah';
          break;
        case 'invalid-email':
          errorMessage = 'Email tidak valid';
          break;
        case 'user-disabled':
          errorMessage = 'Akun dinonaktifkan';
          break;
        case 'invalid-credential':
          errorMessage = 'Email atau password salah';
          break;
        default:
          errorMessage = 'Gagal login: ${e.message}';
      }
      _showSnackBar(errorMessage, isError: true);
    } catch (e) {
      print('Login error: $e');
      _showSnackBar('Terjadi kesalahan saat login', isError: true);
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red[400] : Colors.green[400],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(20),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _resendVerificationEmail() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null && !user.emailVerified) {
        await user.sendEmailVerification();
        _showSnackBar('Email verifikasi telah dikirim ulang');
      } else {
        _showSnackBar(
          'Tidak ada pengguna yang perlu verifikasi',
          isError: true,
        );
      }
    } catch (e) {
      _showSnackBar('Gagal mengirim email verifikasi', isError: true);
    }
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF79BCC1).withOpacity(0.2),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Icon(
            Icons.child_care,
            size: 60,
            color: const Color(0xFF79BCC1),
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          'Selamat Datang',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Color(0xFF333333),
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'TummyTrack',
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: Color(0xFF79BCC1),
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Pantau tumbuh kembang si kecil\ndengan lebih mudah',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 15,
            color: Colors.grey[600],
            height: 1.5,
          ),
        ),
      ],
    );
  }

  Widget _buildLoginForm() {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 30,
            offset: const Offset(0, 15),
          ),
        ],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            // Email Field
            TextFormField(
              controller: _emailController,
              decoration: InputDecoration(
                labelText: 'Email',
                hintText: 'contoh@email.com',
                filled: true,
                fillColor: Colors.grey[50],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: Color(0xFF79BCC1),
                    width: 2,
                  ),
                ),
                errorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.red),
                ),
                prefixIcon: const Icon(
                  Icons.email_outlined,
                  color: Color(0xFF79BCC1),
                ),
              ),
              keyboardType: TextInputType.emailAddress,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Email harus diisi';
                }
                if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
                    .hasMatch(value)) {
                  return 'Email tidak valid';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            
            // Password Field
            TextFormField(
              controller: _passwordController,
              obscureText: _obscureText,
              decoration: InputDecoration(
                labelText: 'Kata Sandi',
                hintText: 'Masukkan kata sandi',
                filled: true,
                fillColor: Colors.grey[50],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: Color(0xFF79BCC1),
                    width: 2,
                  ),
                ),
                errorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.red),
                ),
                prefixIcon: const Icon(
                  Icons.lock_outline,
                  color: Color(0xFF79BCC1),
                ),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscureText ? Icons.visibility_off : Icons.visibility,
                    color: Colors.grey[600],
                  ),
                  onPressed: () {
                    setState(() {
                      _obscureText = !_obscureText;
                    });
                  },
                ),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Kata sandi harus diisi';
                }
                if (value.length < 6) {
                  return 'Kata sandi minimal 6 karakter';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            
            // Action Links
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                  onPressed: _resendVerificationEmail,
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(0, 0),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text(
                    'Kirim ulang verifikasi',
                    style: TextStyle(
                      color: Color(0xFF79BCC1),
                      fontSize: 12,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.pushNamed(context, '/forgot-password'),
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(0, 0),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text(
                    'Lupa Kata Sandi?',
                    style: TextStyle(
                      color: Color(0xFF79BCC1),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            
            // Login Button
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _login,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF79BCC1),
                  disabledBackgroundColor: Colors.grey[400],
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                  shadowColor: const Color(0xFF79BCC1).withOpacity(0.4),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2.5,
                        ),
                      )
                    : const Text(
                        'Masuk',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 0.5,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 24),
            
            // Divider
            Row(
              children: [
                Expanded(child: Divider(color: Colors.grey[300], thickness: 1)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    'Atau',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                      fontSize: 13,
                    ),
                  ),
                ),
                Expanded(child: Divider(color: Colors.grey[300], thickness: 1)),
              ],
            ),
            const SizedBox(height: 24),
            
            // Google Sign In Button
            SizedBox(
              width: double.infinity,
              height: 54,
              child: OutlinedButton.icon(
                onPressed: _isGoogleLoading ? null : _handleGoogleSignIn,
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: Colors.grey[300]!),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  backgroundColor: Colors.white,
                ),
                icon: _isGoogleLoading
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                        ),
                      )
                    : Image.asset(
                        'assets/images/google.png',
                        width: 22,
                        height: 22,
                        errorBuilder: (context, error, stackTrace) {
                          return const Icon(Icons.g_mobiledata, size: 28);
                        },
                      ),
                label: Text(
                  _isGoogleLoading ? 'Memproses...' : 'Lanjut dengan Google',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF333333),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              const Color(0xFF79BCC1).withOpacity(0.1),
              Colors.white,
            ],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 40.0),
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: Column(
                  children: [
                    const SizedBox(height: 20),
                    _buildHeader(),
                    const SizedBox(height: 40),
                    _buildLoginForm(),
                    const SizedBox(height: 24),
                    
                    // Register Link
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Belum punya akun? ',
                          style: TextStyle(
                            color: Colors.grey[700],
                            fontSize: 14,
                          ),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pushNamed(context, '/register'),
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.zero,
                            minimumSize: const Size(0, 0),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: const Text(
                            'Daftar Sekarang',
                            style: TextStyle(
                              color: Color(0xFF79BCC1),
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}