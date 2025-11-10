import 'package:animated_splash_screen/animated_splash_screen.dart';
import 'package:autisecure/firebase_options.dart';
import 'package:autisecure/landing_screens/doctor_landing_screen.dart';
import 'package:autisecure/landing_screens/admin_landing_screen.dart';
import 'package:autisecure/landing_screens/landing_screen.dart';
import 'package:autisecure/login_signup/login_screen.dart';
import 'package:autisecure/mainScreens/user/home_page.dart';
import 'package:autisecure/state_models/survey_state.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:page_transition/page_transition.dart';

// --- ADD THESE IMPORTS ---
import 'package:autisecure/calls/video_call.dart';
import 'package:autisecure/services/socket_service.dart';
// --- END OF NEW IMPORTS ---

class GlobalNavigator {
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();
}

// 🔔 Background handler
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  debugPrint("📩 Background message: ${message.notification?.title}");
  // You could even call the handler here if needed, but be careful
  // as the app is not running a UI.
}

// --- ADD THIS NEW FUNCTION ---
/// Handles navigating to a video call from an FCM notification
Future<void> _handleIncomingCallFromNotification(
  Map<String, dynamic> data,
) async {
  debugPrint("📞 Handling incoming call from notification...");

  final String? type = data['type'];

  if (type == 'incoming_call') {
    final String? conversationId = data['conversationId'];
    final String? callerId = data['callerId'];
    final String? callerName = data['callerName'];

    // Get the current user's ID from storage
    final prefs = await SharedPreferences.getInstance();
    // ⚠️ IMPORTANT: Make sure 'userId' is the key you use to save the user's ID!
    final String? selfUserId = prefs.getString('userId');

    if (conversationId != null && callerId != null && selfUserId != null) {
      debugPrint("✅ Call data is valid. Connecting socket and navigating...");

      // 1. Get the navigator state from our global key
      final navigator = GlobalNavigator.navigatorKey.currentState;

      // 2. Connect the socket
      final SocketService socketService = SocketService();
      try {
        await socketService.connect();
        if (socketService.socket == null) {
          throw Exception("Socket instance is null after connect");
        }

        // 3. Navigate to the VideoCall screen
        navigator?.push(
          MaterialPageRoute(
            builder:
                (context) => VideoCall(
                  socket: socketService.socket!,
                  callerName: callerName ?? 'Caller',
                  selfUserId: selfUserId,
                  peerUserId: callerId,
                  conversationId: conversationId,
                  isCaller: false,
                  isVideoCall: true, // This user is the callee
                ),
          ),
        );
      } catch (e) {
        debugPrint("❌ Error connecting socket or navigating: $e");
      }
    } else {
      debugPrint("⚠️ Invalid call data in notification payload.");
      debugPrint(
        "   convID: $conversationId, callerID: $callerId, selfID: $selfUserId",
      );
    }
  }
}
// --- END OF NEW FUNCTION ---

// 🔧 Update token to backend dynamically
Future<void> updateFcmToken(String token) async {
  final prefs = await SharedPreferences.getInstance();
  final jwt = prefs.getString('token');
  final role = prefs.getString('role');

  if (jwt == null || role == null) {
    debugPrint("⚠️ Skipping FCM update — missing token or role");
    return;
  }

  // 🧭 Choose correct API based on role
  final endpoint =
      role == "Doctor"
          ? "https://autisense-backend.onrender.com/api/doctor/updateFcmToken"
          : "https://autisense-backend.onrender.com/api/user/updateFcmToken";

  try {
    final res = await http.put(
      Uri.parse(endpoint),
      headers: {
        'Authorization': 'Bearer $jwt',
        'Content-Type': 'application/json',
      },
      body: '{"fcmToken": "$token"}',
    );

    if (res.statusCode == 200) {
      debugPrint('✅ $role FCM token updated successfully');
    } else {
      debugPrint('⚠️ $role FCM token update failed: ${res.statusCode}');
    }
  } catch (e) {
    debugPrint('❌ Failed to update $role FCM token: $e');
  }
}

// 🔹 Initialize and store FCM token locally
Future<void> setupFCM() async {
  final messaging = FirebaseMessaging.instance;
  await messaging.requestPermission();

  final prefs = await SharedPreferences.getInstance();
  final oldToken = prefs.getString('fcmToken');
  final newToken = await messaging.getToken();

  debugPrint("📱 Current stored FCM token: $newToken");

  // ✅ Only store it locally here (don’t send to backend yet)
  if (newToken != null && newToken != oldToken) {
    await prefs.setString('fcmToken', newToken);
    debugPrint("🔥 New FCM Token stored locally: $newToken");
  }

  // 🔄 Listen for token refresh
  FirebaseMessaging.instance.onTokenRefresh.listen((refreshedToken) async {
    await prefs.setString('fcmToken', refreshedToken);
    debugPrint("🔄 Token refreshed: $refreshedToken");
    await updateFcmToken(refreshedToken); // safe: user is logged in by now
  });

  // 🔔 Foreground message handler
  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    debugPrint('📩 Foreground message: ${message.notification?.title}');
    // You could show an in-app banner here if you want
  });

  // 🔔 When user taps notification (app in background)
  FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
    debugPrint('📲 Notification tapped! (Background)');
    _handleIncomingCallFromNotification(message.data); // <-- MODIFIED
  });
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  await setupFCM(); // 👈 Initialize FCM system (store token locally only)

  // 🔔 Check if app was launched from a terminated state
  RemoteMessage? initialMessage =
      await FirebaseMessaging.instance.getInitialMessage();
  if (initialMessage != null) {
    debugPrint('📲 Notification tapped! (Terminated)');
    // We add a small delay to ensure the UI is ready before navigating
    Future.delayed(const Duration(seconds: 1), () {
      _handleIncomingCallFromNotification(initialMessage.data);
    });
  }

  runApp(
    ChangeNotifierProvider(create: (_) => SurveyState(), child: const MyApp()),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: GlobalNavigator.navigatorKey, // <-- MODIFIED
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
          const SizedBox(height: 20),
          const Text(
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
      animationDuration: const Duration(milliseconds: 2000),
    );
  }
}
