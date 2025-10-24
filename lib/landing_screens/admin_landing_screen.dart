import 'package:flutter/material.dart';

// --- UPDATED IMPORTS ---
import 'package:autisecure/mainScreens/Admin/admin.dart'; // Keep this for AdminDashboard
// import 'package:autisecure/mainScreens/user/profile.dart'; // Remove User Profile
import 'package:autisecure/mainScreens/Admin/profile.dart'; // Add Admin Profile (assuming file is admin_profile.dart)
// --- END UPDATED IMPORTS ---


class AdminLandingScreen extends StatefulWidget {
  const AdminLandingScreen({super.key});

  @override
  State<AdminLandingScreen> createState() => _AdminLandingScreenState();
}

class _AdminLandingScreenState extends State<AdminLandingScreen> {
  int _selectedIndex = 0;

  // --- UPDATED PAGES LIST ---
  final List<Widget> pages = [
    AdminDashboard(),
    AdminProfileScreen(), // Use AdminProfileScreen here
  ];
  // --- END UPDATED PAGES LIST ---

  void onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  Widget buildHeader() {
    // No changes needed here
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
    // No changes needed here
    return BottomNavigationBar(
      selectedItemColor: Colors.orange,
      unselectedItemColor: Colors.black,
      currentIndex: _selectedIndex,
      onTap: onItemTapped,
      type: BottomNavigationBarType.fixed,
      items: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.dashboard_customize_outlined, size: 30), // Changed icon
          label: "Dashboard", // Changed label
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.person_outline, size: 30), // Changed icon
          label: "Profile",
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    // No changes needed here
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        toolbarHeight: 80,
        backgroundColor: Colors.orange,
        title: buildHeader(),
      ),
      body: pages[_selectedIndex],
      bottomNavigationBar: buildBottomNavBar(),
    );
  }
}