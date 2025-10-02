import 'package:animated_splash_screen/animated_splash_screen.dart';
import 'package:autisecure/landing_screens/Doctor_Landing_Screen.dart';
import 'package:autisecure/landing_screens/admin_landing_screen.dart';
import 'package:autisecure/landing_screens/landing_screen.dart';
import 'package:autisecure/login_signup/login_screen.dart';
import 'package:autisecure/mainScreens/home_page.dart';
import 'package:autisecure/state_models/survey_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:page_transition/page_transition.dart';

Future<void> main() async {
  await dotenv.load(fileName: ".env");
  runApp(
    ChangeNotifierProvider(
      create: (_) {
        var surveyState = SurveyState();
        return surveyState;
      },
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: const SplashScreen(),
      routes: {
        'login': (context) => const LoginScreen(),
        'home': (context) => const HomeScreen(),
      },
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  Widget? nextScreen;

  @override
  void initState() {
    super.initState();
    _checkIsLoggedIn();
  }

  Future<void> _checkIsLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    final role = prefs.getString('role');
    bool isLoggedIn = token != null && token.isNotEmpty;
    setState(() {
      nextScreen =
          isLoggedIn
              ? role == "Admin"
                  ? AdminLandingScreen()
                  : role == "Doctor"
                  ? DoctorLndingScreen()
                  : Landingscreen()
              : LoginScreen();
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSplashScreen(
      splash: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Image.asset("assets/logo.png", width: 220),
          ),
          SizedBox(height: 20),
          Text(
            "Auti Secure",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 35,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              fontFamily: "Merriweather",
            ),
          ),
        ],
      ),
      nextScreen:
          nextScreen ??
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      backgroundColor: Colors.orange,
      splashIconSize: 550,
      centered: true,
      duration: 3000,
      splashTransition: SplashTransition.fadeTransition,
      pageTransitionType: PageTransitionType.fade,
      animationDuration: Duration(milliseconds: 2000),
    );
  }
}
