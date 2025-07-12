// import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:drivers_logbook/pages/home.dart';
import 'firebase_options.dart';
import 'package:drivers_logbook/authentication/login.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
//  await FirebaseAppCheck.instance.activate(
//    // You can also use a `ReCaptchaV3Provider` provider for web
//    androidProvider: AndroidProvider.debug,
//    webProvider: ReCaptchaV3Provider('recaptcha-v3-site-key'),
//    appleProvider: AppleProvider.appAttest,
//  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Drivers Logbook',
      theme: ThemeData(
        textTheme: TextTheme(
            bodyMedium: TextStyle(fontSize: 20),
            bodyLarge: TextStyle(fontSize: 20),
            bodySmall: TextStyle(fontSize: 20),
            titleLarge: TextStyle(fontSize: 20),
            titleMedium: TextStyle(fontSize: 20),
            titleSmall: TextStyle(fontSize: 20),
            headlineLarge: TextStyle(fontSize: 20),
            headlineMedium: TextStyle(fontSize: 20),
            headlineSmall: TextStyle(fontSize: 20),
            displayLarge: TextStyle(fontSize: 20),
            displayMedium: TextStyle(fontSize: 20),
            displaySmall: TextStyle(fontSize: 20),
            labelLarge: TextStyle(fontSize: 20),
            labelMedium: TextStyle(fontSize: 20),
            labelSmall: TextStyle(fontSize: 20),

        ),
      ),
            home: const AuthWrapper(),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }
        if (snapshot.hasData) {
          return const HomeScreen();
        }
        return const LoginScreen();
      },
    );
  }
}
