import 'dart:convert';

import 'package:autisecure/login_signup/login_screen.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

// --- ADD THIS IMPORT ---
import 'profile.dart'; // Imports AdminProfileScreen from profile.dart

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  Future<void> logOutBtn(context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
    await prefs.remove('role'); // Also remove role
    await prefs.remove('adminDataCache'); // Clear admin cache on logout

    if (!mounted) return; // Add mounted check before navigation

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
      (route) => false,
    );
  }

  List<dynamic> doctors = [];
  bool isLoading = true;
  String? _error; // To store potential errors

  Future<void> fetchDoctors() async { // Removed context parameter
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    if (token == null || token.isEmpty) {
        _handleError("Authentication token missing. Please log in.");
        logOutBtn(context); // Log out if token is missing
        return;
    }
    // Set loading state at the beginning
    if (mounted) {
       setState(() {
         isLoading = true;
         _error = null;
       });
    }

    try {
      final url = Uri.parse(
        "https://autisense-backend.onrender.com/api/admin/doctor-requests",
      );
      debugPrint("Fetching doctor requests...");
      final response = await http.get(
        url,
        headers: {"authorization": "Bearer $token"},
      );
      debugPrint("Response status: ${response.statusCode}");
      debugPrint("Response body: ${response.body}");

      if (!mounted) return; // Check if widget is still mounted

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        setState(() {
          // Ensure 'requests' key exists and is a List
          doctors = (decoded["requests"] as List?) ?? [];
          isLoading = false;
          _error = null; // Clear error on success
        });
        debugPrint("Doctor requests loaded: ${doctors.length} found");
      } else {
        // Handle specific error codes if needed
         _handleError("Failed to load doctors: ${response.statusCode} ${response.reasonPhrase}");
      }
    } catch (e) {
      debugPrint("Error fetching doctors: $e");
       _handleError("Error fetching doctors: $e");
    } finally {
       if (mounted) {
         setState(() => isLoading = false); // Ensure loading is stopped
       }
    }
  }

  // Helper function to handle errors and update state
  void _handleError(String errorMessage) {
     if (mounted) {
        setState(() {
          doctors = []; // Clear doctors list on error
          _error = errorMessage;
          isLoading = false;
        });
        // Optionally show a SnackBar, but the error text in the body is clearer
        // ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errorMessage)));
     }
  }


  Future<void> updateDoctorStatus(
    String doctorId,
    bool approve,
  ) async { // Removed context parameter
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
     if (token == null || token.isEmpty) {
        _showSnackBar("Authentication token missing.");
        logOutBtn(context);
        return;
     }

    try {
      final url = Uri.parse(
        approve
            ? "https://autisense-backend.onrender.com/api/admin/approve-doctor"
            : "https://autisense-backend.onrender.com/api/admin/reject-doctor",
      );

      final response = await http.post(
        url,
        headers: {
          "Content-Type": "application/json",
          "authorization": "Bearer $token",
        },
        body: jsonEncode({"requestId": doctorId}),
      );

      debugPrint(
          "Update status for $doctorId (${approve ? 'Approve' : 'Reject'}): ${response.statusCode}");

      if (!mounted) return;

      if (response.statusCode == 200) {
        _showSnackBar("Doctor ${approve ? "approved" : "rejected"} successfully.");
        fetchDoctors(); // Refresh list after update
      } else {
        final errorBody = jsonDecode(response.body);
        _showSnackBar("Failed: ${errorBody['message'] ?? response.reasonPhrase}", isError: true);
      }
    } catch (e) {
      debugPrint("Error updating doctor status: $e");
      _showSnackBar("Error updating status: $e", isError: true);
    }
  }

  // Helper for showing snackbars
   void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    // Fetch data without passing context initially
    fetchDoctors();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF5E3), // Use background color from profile
      appBar: AppBar(
        automaticallyImplyLeading: false, // Remove back arrow
        title: const Text(
            "Admin Dashboard",
             style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.orange, // Keep theme color
                fontFamily: "Merriweather",
            ),
        ),
        centerTitle: true,
        backgroundColor: const Color(0xFFFFF2E0), // Keep theme color
        elevation: 1,
        actions: [
          // Profile Button
          IconButton(
            icon: const Icon(Icons.account_circle_outlined, color: Colors.black87, size: 28),
            tooltip: "Profile", // Add tooltip for accessibility
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AdminProfileScreen()),
              );
            },
          ),
          // Logout Button
           IconButton(
            icon: const Icon(Icons.logout, color: Colors.redAccent),
             tooltip: "Logout",
            onPressed: () => logOutBtn(context), // Call logout directly
          ),
        ],
      ),
      body: SafeArea( // Wrap body in SafeArea
        child: _buildBody(),
      ),
    );
  }

  // Helper widget to build the main body content
  Widget _buildBody() {
     if (isLoading) {
        return const Center(child: CircularProgressIndicator(color: Colors.orange));
     }

     if (_error != null) {
       return Center(
         child: Padding(
           padding: const EdgeInsets.all(20.0),
           child: Column(
             mainAxisSize: MainAxisSize.min,
             children: [
               const Icon(Icons.error_outline, color: Colors.red, size: 50),
               const SizedBox(height: 10),
               Text(
                 _error!,
                 style: const TextStyle(color: Colors.red, fontSize: 16),
                 textAlign: TextAlign.center,
               ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  icon: const Icon(Icons.refresh),
                  label: const Text("Retry"),
                  onPressed: fetchDoctors, // Retry fetching
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                )
             ],
           ),
         ),
       );
     }

     if (doctors.isEmpty) {
        return Center(
          child: Column(
             mainAxisSize: MainAxisSize.min,
            children: [
              const Text("No pending doctor requests found.", style: TextStyle(fontSize: 18, color: Colors.grey)),
               const SizedBox(height: 20),
               IconButton(
                icon: const Icon(Icons.refresh, size: 30, color: Colors.orange),
                tooltip: "Refresh",
                onPressed: fetchDoctors,
              ),
            ],
          )
        );
     }

      // Display the list if everything is okay
     return RefreshIndicator( // Add pull-to-refresh
       onRefresh: fetchDoctors,
       color: Colors.orange,
       child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: doctors.length,
        itemBuilder: (context, index) {
          final doctor = doctors[index];
          // Safely access properties with null checks
          final String name = doctor['name'] ?? 'Unknown Doctor';
          final String speciality = doctor['speciality'] ?? 'N/A';
          final String imageUrl = doctor['imageUrl'] ?? '';
          final String doctorId = doctor['_id'] ?? ''; // Ensure ID exists

          return Card(
            margin: const EdgeInsets.symmetric(vertical: 8),
            elevation: 3, // Add slight elevation
             shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              leading: CircleAvatar(
                      radius: 25, // Slightly larger avatar
                      backgroundColor: Colors.orange[100], // Placeholder color
                      backgroundImage: (imageUrl.isNotEmpty)
                          ? NetworkImage(imageUrl)
                          : null, // Use NetworkImage if URL exists
                      child: (imageUrl.isEmpty)
                          ? const Icon(Icons.person, color: Colors.orange, size: 28) // Icon if no image
                          : null,
                    ),
              title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text(
                "Speciality: $speciality",
                style: TextStyle(color: Colors.grey[700]),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min, // Keep buttons compact
                children: [
                  IconButton(
                    icon: const Icon(Icons.check_circle_outline, color: Colors.green, size: 26),
                    tooltip: "Approve Doctor",
                    onPressed: doctorId.isEmpty ? null : // Disable if no ID
                        () => updateDoctorStatus(doctorId, true),
                  ),
                  IconButton(
                    icon: const Icon(Icons.highlight_off, color: Colors.red, size: 26),
                     tooltip: "Reject Doctor",
                    onPressed: doctorId.isEmpty ? null : // Disable if no ID
                        () => updateDoctorStatus(doctorId, false),
                  ),
                ],
              ),
               onTap: () {
                  // Optional: Navigate to a detailed view of the doctor request
                  debugPrint("Tapped on doctor: $name");
               },
            ),
          );
        },
           ),
     );
  }
}