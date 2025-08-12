import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController(text: 'andin123@gmail.com');
  final _passwordController = TextEditingController();
  bool _obscureText = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

// Di dalam login_screen.dart
Future<bool> _hasBabyData(String userId) async {
  try {
    final docs = await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('babies')
        .get();
    return docs.docs.isNotEmpty && docs.docs.any((doc) => doc.data()['name'] != null);
  } catch (e) {
    print('Error checking baby data: $e');
    return false;
  }
}

  void _login() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Email dan kata sandi harus diisi')),
      );
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
        final hasBabyData = await _hasBabyData(user.uid);
        Navigator.pushReplacementNamed(
          context,
          hasBabyData ? '/dashboard' : '/welcome',
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Silakan verifikasi email Anda terlebih dahulu')),
        );
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
        default:
          errorMessage = 'Gagal login: ${e.message}';
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMessage)),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error tidak diketahui: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _resendVerificationEmail() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null && !user.emailVerified) {
        await user.sendEmailVerification();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Email verifikasi telah dikirim ulang')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tidak ada pengguna yang sedang login atau email sudah diverifikasi')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal mengirim ulang email: $e')),
      );
    }
  }

  void _navigateToRegister() {
    try {
      Navigator.pushNamed(context, '/register');
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal navigasi ke registrasi: $e')),
      );
    }
  }

  void _navigateToForgotPassword() {
    try {
      Navigator.pushNamed(context, '/forgot-password');
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal navigasi ke lupa kata sandi: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 40.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 50),
            const Text(
              'Selamat Datang di',
              style: TextStyle(fontSize: 24, color: Colors.black87),
            ),
            const Text(
              'TummyTrack',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2E3192),
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Pantau setiap momen tumbuh kembang\nsi kecil dengan lebih mudah',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Color(0xFF79BCC1)),
            ),
            const SizedBox(height: 40),
            TextField(
              controller: _emailController,
              decoration: InputDecoration(
                labelText: 'Email',
                filled: true,
                fillColor: Colors.grey[200],
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                prefixIcon: const Icon(Icons.email, color: Colors.grey),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _passwordController,
              obscureText: _obscureText,
              decoration: InputDecoration(
                labelText: 'Kata Sandi',
                filled: true,
                fillColor: Colors.grey[200],
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                prefixIcon: const Icon(Icons.lock, color: Colors.grey),
                suffixIcon: IconButton(
                  icon: Icon(_obscureText ? Icons.visibility_off : Icons.visibility),
                  onPressed: () {
                    setState(() {
                      _obscureText = !_obscureText;
                    });
                  },
                ),
              ),
            ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _navigateToForgotPassword,
                    child: const Text(
                      'Lupa Kata Sandi?',
                      style: TextStyle(color: Color(0xFF79BCC1)),
                    ),
                  ),
                  TextButton(
                    onPressed: _resendVerificationEmail,
                    child: const Text(
                      'Kirim ulang email verifikasi',
                      style: TextStyle(color: Color(0xFF79BCC1)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: _isLoading ? null : _login,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF79BCC1),
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: _isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text(
                      'Lanjut',
                      style: TextStyle(fontSize: 18, color: Colors.white),
                    ),
            ),
            const SizedBox(height: 10),
            const Text('Atau', style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () async {
                final authService = Provider.of<AuthService>(context, listen: false);
                try {
                  final user = await authService.signInWithGoogle();
                  if (user != null) {
                    final hasBabyData = await _hasBabyData(user.uid);
                    Navigator.pushReplacementNamed(
                      context,
                      hasBabyData ? '/dashboard' : '/welcome',
                    );
                  }
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Google Sign-In gagal: $e')));
                }
              },
              icon: Image.asset('assets/images/google.png', width: 20, height: 20),
              label: const Text(
                'Lanjut dengan Google',
                style: TextStyle(color: Color(0xFF79BCC1)),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFF79BCC1)),
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 20),
            TextButton(
              onPressed: _navigateToRegister,
              child: const Text(
                'Belum punya akun? Daftar',
                style: TextStyle(color: Color(0xFF79BCC1)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}