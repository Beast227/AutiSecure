import 'dart:convert';
import 'dart:io';

import 'package:autisecure/login_signup/login_screen.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String? userRole;
  bool isLoading = true;

  String? profileImageUrl; // <-- store image URL here

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _dobController = TextEditingController();

  // for Doctor
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

  Future<void> getUserInfo(context) async {
    final prefs = await SharedPreferences.getInstance();
    final role = prefs.getString('role');
    debugPrint("The Role is $role");
    userRole = role!;
    final url = Uri.parse(
      role == "Doctor"
          ? "https://autisense-backend.onrender.com/api/doctor/data"
          : "https://autisense-backend.onrender.com/api/user/data",
    );
    final token = prefs.getString('token');

    if (token == null || token.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Token not found. Please log in again.")),
      );
      return;
    }

    final response = await http.get(
      url,
      headers: {'authorization': 'Bearer $token'},
    );

    try {
      final responseData = json.decode(response.body);
      if (response.statusCode == 200) {
        setState(() {
          _nameController.text = responseData['name'] ?? '';
          _emailController.text = responseData['email'] ?? '';
          _phController.text = responseData['phone'] ?? '';
          _addressController.text = responseData['address'] ?? '';
          _dobController.text = responseData['dob'] ?? '';
          docInfo.text = responseData['about'] ?? '';
          experience.text = responseData['experience']?.toString() ?? '';
          clinicLoc.text = responseData['clinicAddress'] ?? '';
          specialization.text = responseData['speciality'] ?? '';
          profileImageUrl = responseData['imageUrl']; // <-- store image URL
        });
        isLoading = false;
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("User Data Not Available ${responseData['message']}"),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  Future<void> logOutBtn(context) async {
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
      setState(() {
        _imageFile = File(pickedFile.path);
      });
    }
  }

  /// Function to upload updated profile image
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
      getUserInfo(context); // refresh data
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Failed to update image. Code: ${response.statusCode}"),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body:
          isLoading
              ? const Center(child: CircularProgressIndicator())
              : Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: const Color.fromARGB(255, 255, 232, 188),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        padding: const EdgeInsets.symmetric(
                          vertical: 30,
                          horizontal: 20,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              "Profile",
                              style: TextStyle(
                                fontSize: 40,
                                fontWeight: FontWeight.bold,
                                fontFamily: "Merriweather",
                                color: Color(0xFF8B5400),
                              ),
                            ),
                            const SizedBox(height: 20),

                            // Profile Image + Edit Button
                            Stack(
                              alignment: Alignment.bottomRight,
                              children: [
                                CircleAvatar(
                                  radius: 100,
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
                                            size: 80,
                                            color: Colors.grey,
                                          )
                                          : null,
                                ),
                                Positioned(
                                  bottom: 8,
                                  right: 8,
                                  child: GestureDetector(
                                    onTap: _pickImage,
                                    child: Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: const BoxDecoration(
                                        color: Colors.white,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.edit,
                                        color: Colors.black,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),

                            // Button to upload after picking image
                            if (_imageFile != null)
                              ElevatedButton.icon(
                                onPressed: _uploadProfileImage,
                                icon: const Icon(Icons.save),
                                label: const Text("Save Profile Image"),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.orange,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                              ),
                            const SizedBox(height: 20),
                            _buildProfileForm(),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: () => logOutBtn(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(Icons.login, color: Colors.white, size: 20),
                            SizedBox(width: 15),
                            Text(
                              "Log-Out",
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                fontFamily: "Merriweather",
                                color: Colors.white,
                              ),
                            ),
                          ],
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
          const SizedBox(height: 10),
          buildTextField("About Yourself", docInfo),
          const SizedBox(height: 10),
          buildTextField("Clinic Address", clinicLoc),
          const SizedBox(height: 10),
          buildTextField("Specialization", specialization),
          const SizedBox(height: 10),
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
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 15,
            vertical: 15,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Colors.blue, width: 3),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFFB97001), width: 2),
          ),
        ),
      ),
    );
  }
}
