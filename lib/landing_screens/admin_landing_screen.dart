// Remove the globals import
// import 'package:autisecure/globals.dart' as globals; 

import 'package:autisecure/mainScreens/Admin/admin.dart';
import 'package:autisecure/mainScreens/profile.dart';
import 'package:flutter/material.dart';

class AdminLandingScreen extends StatefulWidget {
  const AdminLandingScreen({super.key});

  @override
  State<AdminLandingScreen> createState() => _AdminLandingScreenState();
}

class _AdminLandingScreenState extends State<AdminLandingScreen> {
  // 1. Manage the index here. It safely starts at 0 every time.
  int _selectedIndex = 0;

  final List<Widget> pages = [
    AdminDashboard(),
    ProfileScreen(),
  ];

  // 2. Update the local state variable
  void onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  Widget buildHeader() {
    // ... (this function is fine, no changes)
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
      // 3. Use the local _selectedIndex
      currentIndex: _selectedIndex,
      onTap: onItemTapped,
      type: BottomNavigationBarType.fixed,
      items: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.home, size: 30),
          label: "Home",
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
      // 4. Use the local _selectedIndex
      body: pages[_selectedIndex],
      bottomNavigationBar: buildBottomNavBar(),
    );
  }
}