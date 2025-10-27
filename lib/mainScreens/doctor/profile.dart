import 'dart:convert';
import 'dart:io';

import 'package:autisecure/login_signup/login_screen.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DocProfileScreen extends StatefulWidget {
  const DocProfileScreen({super.key});

  @override
  State<DocProfileScreen> createState() => _DocProfileScreenState();
}

class _DocProfileScreenState extends State<DocProfileScreen> {
  String? userRole;
  bool isLoading = true;
  String? profileImageUrl;

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _dobController = TextEditingController(); // Controller for DOB

  // Doctor-specific controllers
  final TextEditingController docInfo = TextEditingController();
  final TextEditingController clinicLoc = TextEditingController();
  final TextEditingController experience = TextEditingController();
  final TextEditingController specialization = TextEditingController();

  File? _imageFile;

  @override
  void initState() {
    super.initState();
    getUserInfo(context);
  }

   @override
  void dispose() {
    // Dispose all controllers to prevent memory leaks
    _nameController.dispose();
    _emailController.dispose();
    _phController.dispose();
    _addressController.dispose();
    _dobController.dispose();
    docInfo.dispose();
    clinicLoc.dispose();
    experience.dispose();
    specialization.dispose();
    super.dispose();
  }


  Future<void> getUserInfo(BuildContext context) async {
    // Ensure isLoading is true at the start of fetching
    if (mounted) {
      setState(() => isLoading = true);
    }
    final prefs = await SharedPreferences.getInstance();
    final role = prefs.getString('role');
    userRole = role; // Set the userRole state variable

    // Determine the correct API endpoint based on the role
    final url = Uri.parse(
      role == "Doctor"
          ? "https://autisense-backend.onrender.com/api/doctor/data"
          : role == "Admin" // Added check for Admin
              ? "https://autisense-backend.onrender.com/api/admin/data" // Assuming admin data endpoint
              : "https://autisense-backend.onrender.com/api/user/data", // Default to user
    );

    final token = prefs.getString('token');
    if (token == null || token.isEmpty) {
      if (mounted) { // Check mounted before showing SnackBar
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Authentication error. Please log in again.")),
        );
        // Optionally navigate to login screen
         Navigator.pushAndRemoveUntil(
           context,
           MaterialPageRoute(builder: (context) => const LoginScreen()),
           (route) => false,
         );
      }
      return;
    }

    try {
      final response = await http.get(
        url,
        headers: {'authorization': 'Bearer $token'},
      );

      if (!mounted) return; // Check if the widget is still in the tree

      final responseData = json.decode(response.body);
      // --- ADDED DEBUG PRINT ---
      debugPrint("Fetched Profile Data: $responseData");
      // --- END DEBUG PRINT ---

      if (response.statusCode == 200) {
          // Access nested 'doctor' or 'user' object if backend sends it that way
          // Adjust this based on your actual backend response structure
          Map<String, dynamic> userData = responseData; // Default to flat structure
          if (role == "Doctor" && responseData['doctor'] != null && responseData['doctor'] is Map) {
             userData = responseData['doctor'];
          } else if (role == "User" && responseData['user'] != null && responseData['user'] is Map) {
             userData = responseData['user'];
          } else if (role == "Admin" && responseData['admin'] != null && responseData['admin'] is Map) {
              userData = responseData['admin'];
          }
          // If the structure is always flat, you can remove the above 'if/else if' block


        setState(() {
          _nameController.text = userData['name'] ?? '';
          _emailController.text = userData['email'] ?? '';
          _phController.text = userData['phone'] ?? '';
          _addressController.text = userData['address'] ?? '';
          // Directly assign the string from the API
          _dobController.text = userData['dob'] ?? '';
          profileImageUrl = userData['imageUrl']; // Use userData here too

          // Populate doctor-specific fields only if the role is Doctor
          if (role == "Doctor") {
            docInfo.text = userData['description'] ?? '';
            experience.text = userData['experience']?.toString() ?? ''; // Ensure toString
            clinicLoc.text = userData['clinicAddress'] ?? '';
            specialization.text = userData['speciality'] ?? '';
          }
          isLoading = false; // Stop loading indicator on success
        });
      } else {
        // Handle API errors more specifically
        final errorMessage = responseData['message'] ?? 'User Data Not Available';
        ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(content: Text("Error ${response.statusCode}: $errorMessage")),
        );
         setState(() => isLoading = false); // Stop loading on error
      }
    } catch (e) {
       if (!mounted) return;
       debugPrint("Error fetching user info: $e"); // Log the error
      ScaffoldMessenger.of(context).showSnackBar(
         SnackBar(content: Text("An error occurred: $e")),
      );
       setState(() => isLoading = false); // Stop loading on exception
    }
  }


  Future<void> logOutBtn(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
    await prefs.remove('role'); // Also clear role
     await prefs.remove('userDataCache'); // Clear cache if you implement it later
     await prefs.remove('adminDataCache');
     await prefs.remove('doctorsCache');

     if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
      (route) => false,
    );
  }

  Future<void> _pickImage() async {
    final pickedFile = await ImagePicker().pickImage(
      source: ImageSource.gallery,
       imageQuality: 50, // Optionally compress image slightly
    );

    if (pickedFile != null) {
      setState(() => _imageFile = File(pickedFile.path));
    }
  }

  Future<void> _uploadProfileImage() async {
    if (_imageFile == null) return;
    if (!mounted) return;

     // Show a loading indicator (optional)
     showDialog(
       context: context,
       barrierDismissible: false,
       builder: (context) => const Center(child: CircularProgressIndicator()),
     );


    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    if (token == null) {
        Navigator.pop(context); // Dismiss loading indicator
        if(mounted) _showSnackBar("Authentication error.", isError: true);
        return;
    }

    final uri = Uri.parse(
      userRole == "Doctor"
          ? "https://autisense-backend.onrender.com/api/doctor/update-image"
          // Assuming user and admin use the same endpoint, adjust if not
          : "https://autisense-backend.onrender.com/api/user/update-image",
    );

    try {
        final request = http.MultipartRequest('POST', uri);
        request.headers['authorization'] = 'Bearer $token';
        request.files.add(
          await http.MultipartFile.fromPath('image', _imageFile!.path),
        );

        final response = await request.send();

         Navigator.pop(context); // Dismiss loading indicator

        if (!mounted) return;

        if (response.statusCode == 200) {
          _showSnackBar("Profile Image Updated Successfully");
           setState(() => _imageFile = null); // Clear the selected file view
          getUserInfo(context); // Refresh profile data to get new URL
        } else {
            final respStr = await response.stream.bytesToString();
           _showSnackBar("Failed to update image (${response.statusCode}): $respStr", isError: true);
        }
    } catch (e) {
         Navigator.pop(context); // Dismiss loading indicator
         if (mounted) _showSnackBar("Error uploading image: $e", isError: true);
    }
  }

    // --- Helper function to show SnackBar ---
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
  Widget build(BuildContext context) {
    return Scaffold(
       appBar: AppBar( // Add AppBar for context and title
        title: Text(
          userRole == "Doctor" ? "Doctor Profile" : "User Profile", // Dynamic title
           style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.orange, // Keep theme color
                fontFamily: "Merriweather",
            ),
        ),
         backgroundColor: const Color(0xFFFFF2E0), // Keep theme color
         elevation: 1,
         centerTitle: true,
      ),
      backgroundColor: const Color(0xFFFFF5E3), // Match theme background
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.orange))
          : SafeArea(
              child: RefreshIndicator( // Add pull-to-refresh
                onRefresh: () => getUserInfo(context),
                color: Colors.orange,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      // Profile Header
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF2E0),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: const [
                            BoxShadow(
                              color: Colors.black12,
                              blurRadius: 6,
                              offset: Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            Stack(
                              alignment: Alignment.bottomRight,
                              children: [
                                CircleAvatar(
                                  radius: 60,
                                  backgroundColor: Colors.white,
                                  backgroundImage: _imageFile != null
                                      ? FileImage(_imageFile!)
                                      : (profileImageUrl != null && profileImageUrl!.isNotEmpty
                                          ? NetworkImage(profileImageUrl!)
                                          : null) as ImageProvider?,
                                  child: _imageFile == null &&
                                          (profileImageUrl == null || profileImageUrl!.isEmpty)
                                      ? const Icon(
                                          Icons.person,
                                          size: 60,
                                          color: Colors.grey,
                                        )
                                      : null,
                                ),
                                Positioned(
                                  bottom: 0,
                                  right: 0,
                                  child: InkWell(
                                    onTap: _pickImage,
                                    child: const CircleAvatar(
                                      radius: 20,
                                      backgroundColor: Colors.orange,
                                      child: Icon(
                                        Icons.edit,
                                        color: Colors.white,
                                        size: 18,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            if (_imageFile != null) ...[
                              const SizedBox(height: 10),
                              ElevatedButton.icon(
                                onPressed: _uploadProfileImage,
                                icon: const Icon(Icons.save, size: 18),
                                label: const Text("Save Image"),
                                style: ElevatedButton.styleFrom(
                                  foregroundColor: Colors.white,
                                  backgroundColor: Colors.orange,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ],
                            const SizedBox(height: 20),
                            // Profile Form Section
                            _buildProfileForm(),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Logout Button
                      ElevatedButton.icon(
                        onPressed: () => logOutBtn(context),
                        icon: const Icon(Icons.logout, color: Colors.white),
                        label: const Text(
                          "Log Out",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            fontFamily: "Merriweather",
                            color: Colors.white,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.redAccent, // Slightly different red
                          minimumSize: const Size(double.infinity, 50),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  // Build the form fields based on user role
  Widget _buildProfileForm() {
    return Column(
      children: [
        buildTextField("Name", _nameController, icon: Icons.person_outline),
        buildTextField("Email", _emailController, icon: Icons.email_outlined, readOnly: true), // Email usually read-only
        buildTextField("Phone Number", _phController, icon: Icons.phone_outlined),
        buildTextField("Address", _addressController, icon: Icons.home_outlined),
        // DOB Field - Displays String directly
        buildTextField("Date of Birth", _dobController, icon: Icons.calendar_today_outlined, readOnly: true),

        // Doctor Specific Fields
        if (userRole == "Doctor") ...[
           const SizedBox(height: 10), // Add spacing before doctor fields
            const Divider(), // Visual separator
             const SizedBox(height: 10),
          buildTextField("Specialization", specialization, icon: Icons.medical_services_outlined),
          buildTextField("Experience (Years)", experience, icon: Icons.workspace_premium_outlined, keyboardType: TextInputType.number),
          buildTextField("Clinic Address", clinicLoc, icon: Icons.location_on_outlined),
          buildTextField("About Yourself", docInfo, icon: Icons.info_outline, maxLines: 3), // Allow multiple lines
        ],
      ],
    );
  }

  // Reusable TextField builder
  Widget buildTextField(
    String label,
    TextEditingController controller, {
    IconData? icon,
    bool readOnly = false, // Changed parameter name for clarity
     TextInputType? keyboardType,
     int? maxLines = 1, // Added maxLines parameter
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: TextFormField(
        controller: controller,
        readOnly: readOnly, // Use the readOnly parameter
         keyboardType: keyboardType,
         maxLines: maxLines, // Use maxLines
        decoration: InputDecoration(
           prefixIcon: icon != null ? Icon(icon, color: const Color(0xFFB97001)) : null,
          labelText: label,
          filled: true,
          fillColor: readOnly ? Colors.grey.shade100 : Colors.white, // Grey out if read-only
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 15,
            vertical: 14,
          ),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFB97001), width: 2),
          ),
           enabledBorder: OutlineInputBorder(
             borderRadius: BorderRadius.circular(12),
             borderSide: BorderSide(
               color: Colors.grey.shade400, // Consistent border
               width: 1,
            ),
          ),
        ),
      ),
    );
  }
}