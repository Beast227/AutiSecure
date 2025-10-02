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
  final TextEditingController _dobController = TextEditingController();

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

  Future<void> getUserInfo(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    final role = prefs.getString('role');
    userRole = role;

    final url = Uri.parse(
      role == "Doctor"
          ? "https://autisense-backend.onrender.com/api/doctor/data"
          : role == "Admin"
          ? "https://autisense-backend.onrender.com/api/admin"
          : "https://autisense-backend.onrender.com/api/user/data",
    );

    final token = prefs.getString('token');
    if (token == null || token.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Token not found. Please log in again.")),
      );
      return;
    }

    try {
      final response = await http.get(
        url,
        headers: {'authorization': 'Bearer $token'},
      );
      final responseData = json.decode(response.body);

      if (response.statusCode == 200) {
        setState(() {
          _nameController.text = responseData['name'] ?? '';
          _emailController.text = responseData['email'] ?? '';
          _phController.text = responseData['phone'] ?? '';
          _addressController.text = responseData['address'] ?? '';
          _dobController.text = responseData['dob'] ?? '';
          profileImageUrl = responseData['imageUrl'];

          if (role == "Doctor") {
            docInfo.text = responseData['description'] ?? '';
            experience.text = responseData['experience']?.toString() ?? '';
            clinicLoc.text = responseData['clinicAddress'] ?? '';
            specialization.text = responseData['speciality'] ?? '';
          }
          isLoading = false;
        });
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("User Data Not Available")));
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  Future<void> logOutBtn(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
      (route) => false,
    );
  }

  Future<void> _pickImage() async {
    final pickedFile = await ImagePicker().pickImage(
      source: ImageSource.gallery,
    );

    if (pickedFile != null) {
      setState(() => _imageFile = File(pickedFile.path));
    }
  }

  Future<void> _uploadProfileImage() async {
    if (_imageFile == null) return;
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    if (token == null) return;

    final uri = Uri.parse(
      userRole == "Doctor"
          ? "https://autisense-backend.onrender.com/api/doctor/update-image"
          : "https://autisense-backend.onrender.com/api/user/update-image",
    );

    final request = http.MultipartRequest('POST', uri);
    request.headers['authorization'] = 'Bearer $token';
    request.files.add(
      await http.MultipartFile.fromPath('image', _imageFile!.path),
    );

    final response = await request.send();
    if (response.statusCode == 200) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Profile Image Updated Successfully")),
      );
      getUserInfo(context);
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Failed to update image")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body:
          isLoading
              ? const Center(child: CircularProgressIndicator())
              : SafeArea(
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
                          boxShadow: [
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
                                  backgroundImage:
                                      _imageFile != null
                                          ? FileImage(_imageFile!)
                                          : (profileImageUrl != null
                                                  ? NetworkImage(
                                                    profileImageUrl!,
                                                  )
                                                  : null)
                                              as ImageProvider?,
                                  child:
                                      _imageFile == null &&
                                              profileImageUrl == null
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
                                    child: CircleAvatar(
                                      radius: 20,
                                      backgroundColor: Colors.orange,
                                      child: const Icon(
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
                                icon: const Icon(Icons.save),
                                label: const Text("Save Image"),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.orange,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ],
                            const SizedBox(height: 20),
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
                          backgroundColor: Colors.red,
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
    );
  }

  Widget _buildProfileForm() {
    return Column(
      children: [
        buildTextField("Name", _nameController),
        buildTextField("Email", _emailController),
        buildTextField("Phone Number", _phController),
        buildTextField("Address", _addressController),
        buildTextField("DOB", _dobController),
        if (userRole == "Doctor") ...[
          buildTextField("Experience", experience),
          buildTextField("About Yourself", docInfo),
          buildTextField("Clinic Address", clinicLoc),
          buildTextField("Specialization", specialization),
        ],
      ],
    );
  }

  Widget buildTextField(
    String label,
    TextEditingController controller, {
    bool obscureText = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: TextFormField(
        controller: controller,
        obscureText: obscureText,
        readOnly: true, // keep read-only since it's a profile view
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 15,
            vertical: 14,
          ),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFB97001), width: 2),
          ),
        ),
      ),
    );
  }
}
