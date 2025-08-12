import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Login dengan email dan kata sandi
  Future<User?> signIn(String email, String password) async {
    try {
      final result = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return result.user;
    } on FirebaseAuthException {
      rethrow; // Lempar kembali error untuk penanganan di UI
    } catch (e) {
      print('Error saat login: $e');
      return null;
    }
  }

  // Registrasi dengan email dan kata sandi
  Future<User?> signUp(String email, String password) async {
    try {
      final result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      await result.user?.sendEmailVerification(); // Kirim email verifikasi
      return result.user;
    } on FirebaseAuthException {
      rethrow;
    } catch (e) {
      print('Error saat registrasi: $e');
      return null;
    }
  }

  // Kirim email pengaturan ulang kata sandi
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException {
      rethrow;
    } catch (e) {
      print('Error saat mengirim email reset: $e');
      rethrow;
    }
  }

  // Login dengan Google
  Future<User?> signInWithGoogle() async {
    try {
      final GoogleSignIn googleSignIn = GoogleSignIn();
      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
      if (googleUser == null) return null;
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      final result = await _auth.signInWithCredential(credential);
      return result.user;
    } catch (e) {
      print('Error Google Sign-In: $e');
      return null;
    }
  }

  // Keluar dari akun
  Future<void> signOut() async {
    await _auth.signOut();
  }
}