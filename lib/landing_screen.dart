import 'package:autisecure/globals.dart' as globals;
import 'package:autisecure/mainScreens/home_page.dart';
import 'package:autisecure/mainScreens/test_screen.dart';
import 'package:autisecure/mainScreens/doctor_screen.dart';
import 'package:autisecure/mainScreens/profile.dart';
import 'package:flutter/material.dart';

class Landingscreen extends StatefulWidget {
  const Landingscreen({super.key});

  @override
  State<Landingscreen> createState() => _LandingscreenState();
}

class _LandingscreenState extends State<Landingscreen> {
  final List<Widget> pages = const [
    HomeScreen(),
    TestScreen(),
    DoctorScreen(),
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
          icon: Icon(Icons.chat, size: 30),
          label: "Test",
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.local_hospital, size: 30),
          label: "Doctor",
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
