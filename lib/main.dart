import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:myapp/models/user_model.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
import 'models/baby_model.dart';
import 'services/auth_service.dart';
import 'services/firestore_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(MyApp());
}

class MyApp extends StatelessWidget {

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => BabyModel()),
        ChangeNotifierProvider(create: (_) => UserModel()),
        Provider(create: (_) => FirestoreService()),
        Provider(create: (_) => AuthService()),
      ],
      child: MaterialApp(
        title: 'TummyTrack App',
        theme: ThemeData(
          primarySwatch: Colors.blue,
          fontFamily: 'Roboto',
          colorScheme: ColorScheme.fromSwatch(primarySwatch: Colors.blue).copyWith(
            secondary: const Color(0xFF7DD3FC),
          ),
        ),
        initialRoute: '/splash',
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
        },
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}