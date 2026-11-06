import 'package:TummyTrack/models/tummy_time_state.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'screens/splash_screen.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/forgot_password_screen.dart';
import 'screens/welcome_page.dart';
import 'screens/baby_name_input_screen.dart';
import 'screens/baby_birthdate_input_screen.dart';
import 'screens/relationship_page.dart';
import 'screens/dashboard_screen.dart';
import 'screens/tummytime_screen.dart';
import 'screens/history_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/notification_screen.dart';
import 'models/baby_model.dart';
import 'models/user_model.dart';
import 'services/auth_service.dart';
import 'services/firestore_service.dart';
// NOTE: tummy_time_state is already imported via package path above
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

Future<void> _initializeNotifications() async {
  tz.initializeTimeZones();
  tz.setLocalLocation(tz.getLocation('Asia/Jakarta'));
  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@mipmap/ic_launcher');
  final InitializationSettings initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid,
  );
  await flutterLocalNotificationsPlugin.initialize(initializationSettings);
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await _initializeNotifications();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => BabyModel()),
        ChangeNotifierProvider(create: (_) => UserModel()),
        // === PERUBAHAN DI SINI ===
        // Mendaftarkan TummyTimeState agar bisa diakses di seluruh aplikasi.
        ChangeNotifierProvider(create: (_) => TummyTimeState()),
        // =========================
        Provider(create: (_) => FirestoreService()),
        Provider(create: (_) => AuthService()),
      ],
      child: GetMaterialApp(
        title: 'TummyTrack App',
        theme: ThemeData(
          primarySwatch: Colors.blue,
          fontFamily: 'Roboto',
          colorScheme: ColorScheme.fromSwatch(
            primarySwatch: Colors.blue,
          ).copyWith(secondary: const Color(0xFF7DD3FC)),
        ),
        initialRoute: '/splash',
        // Rute Anda sudah benar dan mendukung navigasi yang diperbaiki
        routes: {
          '/splash': (context) => SplashScreenApp(),
          '/login': (context) => LoginScreen(),
          '/register': (context) => RegisterScreen(),
          '/forgot-password': (context) => ForgotPasswordScreen(),
          '/welcome': (context) => WelcomePage(),
          '/baby-name': (context) => BabyNameInputScreen(),
          '/birthdate': (context) => BirthDatePage(),
          '/relationship': (context) => RelationshipPage(),
          '/dashboard': (context) => DashboardScreen(),
          '/tummy': (context) => TummyTimeScreen(),
          '/history': (context) => HistoryScreen(),
          '/profile': (context) => ProfileScreen(),
          '/notification': (context) => NotificationScreen(),
        },
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}
