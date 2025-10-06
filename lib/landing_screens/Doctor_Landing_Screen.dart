// ignore: file_names
import 'package:autisecure/globals.dart' as globals;
import 'package:autisecure/mainScreens/doctor/doc_test_screen.dart';
import 'package:autisecure/mainScreens/doctor/doctorDashBoard.dart';
import 'package:autisecure/mainScreens/doctor/doctor_doc_screen.dart';
import 'package:autisecure/mainScreens/doctor/live_chat/chat_list_screen.dart';
import 'package:autisecure/mainScreens/profile.dart';
import 'package:flutter/material.dart';

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
    ChatListScreen(),
    ProfileScreen(),
  ];

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
          icon: Icon(Icons.chat, size: 30),
          label: "Doctors",
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.person, size: 30),
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
      body: pages[globals.selectedIndex],
      bottomNavigationBar: buildBottomNavBar(),
    );
  }
}
