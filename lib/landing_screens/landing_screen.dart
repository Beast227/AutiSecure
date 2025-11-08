import 'dart:async';
import 'package:autisecure/calls/video_call.dart';
import 'package:autisecure/calls/incoming_call.dart';
import 'package:autisecure/services/socket_service.dart';
import 'package:autisecure/globals.dart' as globals;
import 'package:autisecure/mainScreens/user/home_page.dart';
import 'package:autisecure/mainScreens/user/live_chat.dart';
import 'package:autisecure/mainScreens/user/test_screen.dart';
import 'package:autisecure/mainScreens/user/doctor_screen.dart';
import 'package:autisecure/mainScreens/user/profile.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Landingscreen extends StatefulWidget {
  const Landingscreen({super.key});

  @override
  State<Landingscreen> createState() => _LandingscreenState();
}

class _LandingscreenState extends State<Landingscreen> {
  final List<Widget> pages = [
    const HomeScreen(),
    const TestScreen(),
    const DoctorListScreen(),
    const LiveChat2(),
    const ProfileScreen(),
  ];

  final SocketService _socketService = SocketService();
  late final StreamSubscription<Map<String, dynamic>> _callSubscription;
  String? _selfUserId;

  @override
  void initState() {
    super.initState();
    _loadUserIdAndListenForCalls();
  }

  Future<void> _loadUserIdAndListenForCalls() async {
    final prefs = await SharedPreferences.getInstance();
    _selfUserId = prefs.getString(
      'userId',
    ); // ⚠️ Make sure this key is correct!

    // Listen to the stream from SocketService
    _callSubscription = _socketService.incomingCallStream.listen(
      _onIncomingCall,
    );
    debugPrint("📞 [LandingScreen] Subscribed to incomingCallStream");
  }

  Future<void> _onIncomingCall(Map<String, dynamic> data) async {
    debugPrint("📞 [LandingScreen] Handling incoming call: $data");
    if (!mounted || _selfUserId == null) return;

    final String conversationId = data['conversationId']?.toString() ?? '';
    final String callerName =
        data['callerName']?.toString() ?? 'Unknown Caller';
    final String callerId = data['callerId']?.toString() ?? '';
    final String callerSocketId = data['callerSocketId']?.toString() ?? '';

    if (conversationId.isEmpty || callerId.isEmpty || callerSocketId.isEmpty) {
      debugPrint(
        "❌ [LandingScreen] Incoming call data is incomplete. Ignoring.",
      );
      return;
    }

    // 1. Show the ringing screen
    final bool? didAccept = await Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder:
            (context) => IncomingCallScreen(
              callerName: callerName,
              conversationId: conversationId,
              data: data,
            ),
      ),
    );

    // 2. Handle the user's choice
    if (didAccept == true) {
      debugPrint("✅ [LandingScreen] Call accepted by user.");
      _socketService.acceptCall(conversationId, callerSocketId);

      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder:
              (context) => VideoCall(
                socket: _socketService.socket!,
                callerName: callerName,
                selfUserId: _selfUserId!,
                peerUserId: callerId,
                conversationId: conversationId,
                isCaller: false, // You are the callee
                peerSocketId: callerSocketId,
              ),
        ),
      );
    } else {
      debugPrint("❌ [LandingScreen] Call rejected by user.");
      _socketService.rejectCall(conversationId, callerSocketId);
    }
  }

  @override
  void dispose() {
    _callSubscription.cancel();
    debugPrint("📞 [LandingScreen] Unsubscribed from incomingCallStream");
    super.dispose();
  }

  void onItemTapped(int index) {
    setState(() {
      globals.selectedIndex = index;
    });
  }

  Widget buildHeader() {
    return Row(
      children: [
        Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 3),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(50),
            child: Image.asset("assets/logo.png", height: 60),
          ),
        ),
        const SizedBox(width: 10),
        const Text(
          "AutiSecure",
          style: TextStyle(
            fontSize: 32,
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontFamily: "Merriweather",
          ),
        ),
      ],
    );
  }

  Widget buildBottomNavBar() {
    return BottomNavigationBar(
      selectedItemColor: Colors.orange,
      unselectedItemColor: Colors.black,
      currentIndex: globals.selectedIndex,
      onTap: onItemTapped,
      type: BottomNavigationBarType.fixed,
      items: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.home, size: 30),
          label: "Home",
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.chat, size: 30),
          label: "Test",
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.local_hospital, size: 30),
          label: "Doctor",
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.chat, size: 30),
          label: "Chat",
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.person, size: 30),
          label: "Profile",
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        toolbarHeight: 80,
        backgroundColor: Colors.orange,
        title: buildHeader(),
      ),
      body: IndexedStack(index: globals.selectedIndex, children: pages),
      bottomNavigationBar: buildBottomNavBar(),
    );
  }
}
