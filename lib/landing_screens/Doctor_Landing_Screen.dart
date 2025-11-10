// ignore: file_names
import 'dart:async';
import 'package:autisecure/calls/incoming_voice_call.dart';
import 'package:autisecure/calls/video_call.dart';
import 'package:autisecure/calls/incoming_call.dart';
import 'package:autisecure/calls/voice_call.dart';
import 'package:autisecure/services/socket_service.dart';
import 'package:autisecure/globals.dart' as globals;
import 'package:autisecure/mainScreens/doctor/doc_test_screen.dart';
import 'package:autisecure/mainScreens/doctor/doctor_dashboard.dart';
import 'package:autisecure/mainScreens/doctor/doctor_doc_screen.dart';
import 'package:autisecure/live_chat2.dart';
import 'package:autisecure/mainScreens/user/profile.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DoctorLndingScreen extends StatefulWidget {
  const DoctorLndingScreen({super.key});

  @override
  State<DoctorLndingScreen> createState() => ADoctorLndingScreenState();
}

class ADoctorLndingScreenState extends State<DoctorLndingScreen> {
  final List<Widget> pages = [
    DocHomeScreen(),
    DocTestScreen(),
    DocDocListScreen(),
    LiveChat2(),
    ProfileScreen(),
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
    final String callType =
        data['callType']?.toString() ?? 'video'; // voice or video

    if (conversationId.isEmpty || callerId.isEmpty || callerSocketId.isEmpty) {
      debugPrint("❌ Incoming call data incomplete. Ignoring.");
      return;
    }

    // 1) Show the correct incoming UI based on callType
    final bool? didAccept = await Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder:
            (context) =>
                callType == "voice"
                    ? IncomingVoiceCallScreen(
                      callerName: callerName,
                      conversationId: conversationId,
                      data: data,
                    )
                    : IncomingVideoCallScreen(
                      callerName: callerName,
                      conversationId: conversationId,
                      data: data,
                    ),
      ),
    );

    // 2) If accepted → navigate to the appropriate call screen
    if (didAccept == true) {
      debugPrint("✅ Call accepted");
      _socketService.acceptCall(conversationId, callerSocketId);

      if (!mounted) return;

      Navigator.of(context).push(
        MaterialPageRoute(
          builder:
              (context) =>
                  callType == "voice"
                      ? VoiceCall(
                        socket: _socketService.socket!,
                        callerName: callerName,
                        selfUserId: _selfUserId!,
                        peerUserId: callerId,
                        conversationId: conversationId,
                        isCaller: false,
                        peerSocketId: callerSocketId,
                      )
                      : VideoCall(
                        socket: _socketService.socket!,
                        callerName: callerName,
                        selfUserId: _selfUserId!,
                        peerUserId: callerId,
                        conversationId: conversationId,
                        isCaller: false,
                        peerSocketId: callerSocketId,
                      ),
        ),
      );
    } else {
      debugPrint("❌ Call rejected");
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
          icon: Icon(Icons.app_registration_rounded, size: 30),
          label: "Test",
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.medical_information, size: 30),
          label: "Doctors",
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
