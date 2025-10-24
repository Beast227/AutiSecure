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
  bool isLoading = true; // For the initial data load
  bool _isEditing = false; // Toggles between View and Edit mode
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
  Map<String, dynamic> _originalDataSnapshot = {}; // For checking changes

  @override
  void initState() {
    super.initState();
    _loadDataFromCacheAndFetch();
  }

  @override
  void dispose() {
    // Dispose all controllers
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

  // Helper to safely show SnackBars
  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }

  // --- Caching and Data Fetching Logic ---

  Future<void> _loadDataFromCacheAndFetch() async {
    final prefs = await SharedPreferences.getInstance();
    userRole = prefs.getString('role');

    // 1. Load from cache first for instant UI
    final cachedDataString = prefs.getString('userDataCache');
    if (cachedDataString != null) {
      final cachedData = json.decode(cachedDataString);
      _populateControllers(cachedData);
      if (mounted) {
        setState(() => isLoading = false);
      }
    }

    // 2. Then, fetch from network to check for updates
    await _fetchAndCacheProfile(cachedDataString);
  }

  Future<void> _fetchAndCacheProfile(String? cachedDataString) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    if (token == null || token.isEmpty) {
      _showSnackBar("Token not found. Please log in again.", isError: true);
      _logOut();
      return;
    }

    final url = Uri.parse(
      userRole == "Doctor"
          ? "https://autisense-backend.onrender.com/api/doctor/data"
          : userRole == "Admin"
          ? "https://autisense-backend.onrender.com/api/admin"
          : "https://autisense-backend.onrender.com/api/user/data",
    );

    try {
      final response = await http.get(
        url,
        headers: {'authorization': 'Bearer $token'},
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final newResponseDataString = response.body;

        // 3. Compare new data with cached data
        if (newResponseDataString != cachedDataString) {
          debugPrint("Profile data mismatch. Updating cache and UI.");
          await prefs.setString('userDataCache', newResponseDataString);
          final responseData = json.decode(newResponseDataString);
          _populateControllers(responseData);
          if (cachedDataString != null) {
            _showSnackBar("Profile data updated from server.");
          }
        } else {
          debugPrint("Profile data is up-to-date.");
        }
      } else {
        if (cachedDataString == null) {
          _showSnackBar("User Data Not Available", isError: true);
        }
      }
    } catch (e) {
      if (!mounted) return;
      if (cachedDataString == null) {
        _showSnackBar("Error: $e", isError: true);
      }
    }

    // Ensure loading spinner is off
    if (isLoading && mounted) {
      setState(() => isLoading = false);
    }
  }

  void _populateControllers(Map<String, dynamic> data) {
    setState(() {
      _nameController.text = data['name'] ?? '';
      _emailController.text = data['email'] ?? '';
      _phController.text = data['phone'] ?? '';
      _addressController.text = data['address'] ?? '';
      _dobController.text = data['dob'] ?? '';
      profileImageUrl = data['imageUrl'];

      if (userRole == "Doctor") {
        docInfo.text = data['description'] ?? '';
        experience.text = data['experience']?.toString() ?? '';
        clinicLoc.text = data['clinicAddress'] ?? '';
        specialization.text = data['speciality'] ?? '';
      }
    });
  }

  // --- Profile Actions ---

  Future<void> _logOut() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
    await prefs.remove('role');
    await prefs.remove('userDataCache'); // Clear the cache on logout
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

    try {
      final response = await request.send();
      if (response.statusCode == 200) {
        _showSnackBar("Profile Image Updated Successfully");
        setState(() => _imageFile = null); // Hide "Save Image" button
        // Refresh all data (including the new image URL)
        await _fetchAndCacheProfile(null);
      } else {
        _showSnackBar("Failed to update image", isError: true);
      }
    } catch (e) {
      _showSnackBar("Error uploading image: $e", isError: true);
    }
  }

  void _takeDataSnapshot() {
    _originalDataSnapshot = {
      "name": _nameController.text.trim(),
      "phone": _phController.text.trim(),
      "address": _addressController.text.trim(),
      "dob": _dobController.text.trim(),
    };

    if (userRole == "Doctor") {
      _originalDataSnapshot.addAll({
        "speciality": specialization.text.trim(),
        "experience":
            experience.text.trim(), // Store as text for simple comparison
        "description": docInfo.text.trim(),
        "clinicAddress": clinicLoc.text.trim(),
      });
    }
  }

  Future<void> _submitUpdate() async {
    // 1. Create maps for comparison and for the API payload
    final Map<String, dynamic> currentDataForComparison = {
      "name": _nameController.text.trim(),
      "phone": _phController.text.trim(),
      "address": _addressController.text.trim(),
      "dob": _dobController.text.trim(),
    };

    final Map<String, dynamic> apiPayload = {
      "name": _nameController.text.trim(),
      "phone": _phController.text.trim(),
      "address": _addressController.text.trim(),
      "dob": _dobController.text.trim(),
    };

    if (userRole == "Doctor") {
      currentDataForComparison.addAll({
        "speciality": specialization.text.trim(),
        "experience": experience.text.trim(), // Compare as string
        "description": docInfo.text.trim(),
        "clinicAddress": clinicLoc.text.trim(),
      });

      apiPayload.addAll({
        "speciality": specialization.text.trim(),
        "experience":
            int.tryParse(experience.text.trim()) ?? 0, // API needs int
        "description": docInfo.text.trim(),
        "clinicAddress": clinicLoc.text.trim(),
      });
    }

    // 2. Compare the current map to the snapshot
    bool hasChanges =
        json.encode(currentDataForComparison) !=
        json.encode(_originalDataSnapshot);

    if (!hasChanges) {
      _showSnackBar("No changes detected.");
      setState(() => _isEditing = false); // Still exit edit mode
      return; // Don't make the network call
    }

    // 3. If changes exist, proceed with the network request.
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    if (token == null) return;

    final url = Uri.parse(
      userRole == "Doctor"
          ? "https://autisense-backend.onrender.com/api/doctor/update"
          : "https://autisense-backend.onrender.com/api/user/update",
    );

    try {
      final response = await http.put(
        url,
        headers: {
          'authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode(apiPayload), // Use the correctly typed apiPayload
      );

      if (response.statusCode == 200) {
        _showSnackBar("Profile saved successfully!");

        // --- THIS IS THE FIX ---
        // DO NOT use response.body. Update cache with the plain text payload.

        // 1. Get old cache to preserve non-editable fields (like email, imageUrl)
        final oldCacheString = prefs.getString('userDataCache');
        Map<String, dynamic> updatedCacheData = {};
        if (oldCacheString != null) {
          updatedCacheData = json.decode(oldCacheString);
        }

        // 2. Merge our new plain text payload into the cached data
        updatedCacheData.addAll(apiPayload);

        // 3. Save the new plain text map as the new cache
        await prefs.setString('userDataCache', json.encode(updatedCacheData));

        // 4. Just exit edit mode. The controllers already show the new text.
        if (mounted) {
          setState(() => _isEditing = false);
        }
      } else {
        _showSnackBar("Failed to save: ${response.body}", isError: true);
      }
    } catch (e) {
      _showSnackBar("Error saving: $e", isError: true);
    }
  }

  // --- Build Method ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 245, 245, 245),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Stack(
          alignment: Alignment.center,
          children: [
            Center(
              child: Text(
                "My Profile",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.orange,
                ),
              ),
            ),
            Positioned(
              right: 0,
              child: IconButton(
                icon: Icon(
                  _isEditing ? Icons.save_as_outlined : Icons.edit_outlined,
                  color: Colors.black87,
                ),
                onPressed: () {
                  if (_isEditing) {
                    _submitUpdate();
                  } else {
                    _takeDataSnapshot();
                    if (mounted) {
                      setState(() => _isEditing = true);
                    }
                  }
                },
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFFFFF2E0),
        elevation: 1,
      ),
      body:
          isLoading
              ? const Center(child: CircularProgressIndicator())
              : SafeArea(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _buildProfileHeader(),
                      const SizedBox(height: 20),
                      _buildPersonalDetailsForm(),
                      const SizedBox(height: 20),
                      if (userRole == "Doctor") ...[
                        _buildDoctorDetailsForm(),
                        const SizedBox(height: 20),
                      ],
                      ElevatedButton.icon(
                        onPressed: _logOut,
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

  // --- UI Helper Widgets ---

  Widget _buildProfileHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF2E0),
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 3)),
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
                                ? NetworkImage(profileImageUrl!)
                                : null)
                            as ImageProvider?,
                child:
                    _imageFile == null && profileImageUrl == null
                        ? const Icon(Icons.person, size: 60, color: Colors.grey)
                        : null,
              ),
              if (_isEditing) // Only show edit icon when in edit mode
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: InkWell(
                    onTap: _pickImage,
                    child: const CircleAvatar(
                      radius: 20,
                      backgroundColor: Colors.orange,
                      child: Icon(Icons.edit, color: Colors.white, size: 18),
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
                backgroundColor: Colors.orange,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPersonalDetailsForm() {
    return Card(
      elevation: 2,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Personal Details",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFFB97001),
              ),
            ),
            const Divider(height: 20),
            buildTextField("Name", _nameController, icon: Icons.person_outline),
            buildTextField(
              "Email",
              _emailController,
              icon: Icons.email_outlined,
              readOnlyOverride: true, // Email should never be editable
            ),
            buildTextField(
              "Phone Number",
              _phController,
              icon: Icons.phone_outlined,
              keyboardType: TextInputType.phone,
            ),
            buildTextField(
              "Address",
              _addressController,
              icon: Icons.home_outlined,
            ),
            // --- MODIFIED DOB FIELD ---
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: TextFormField(
                controller: _dobController,
                readOnly: true, // Always readOnly, tap is handled manually
                decoration: InputDecoration(
                  prefixIcon: const Icon(
                    Icons.calendar_today_outlined,
                    color: Color(0xFFB97001),
                  ),
                  labelText: "Date of Birth",
                  filled: true,
                  fillColor: _isEditing ? Colors.white : Colors.grey.shade100,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 15,
                    vertical: 14,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: Color(0xFFB97001),
                      width: 2,
                    ),
                  ),
                ),
                onTap: () async {
                  // Only allow tap if in edit mode
                  if (_isEditing) {
                    DateTime? pickedDate = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now(),
                      firstDate: DateTime(1900),
                      lastDate: DateTime.now(),
                    );
                    if (pickedDate != null) {
                      _dobController.text =
                          "${pickedDate.day.toString().padLeft(2, '0')}-${pickedDate.month.toString().padLeft(2, '0')}-${pickedDate.year}";
                    }
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDoctorDetailsForm() {
    return Card(
      elevation: 2,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Professional Information",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFFB97001),
              ),
            ),
            const Divider(height: 20),
            buildTextField(
              "Specialization",
              specialization,
              icon: Icons.medical_services_outlined,
            ),
            buildTextField(
              "Experience (in years)",
              experience,
              icon: Icons.workspace_premium_outlined,
              keyboardType: TextInputType.number,
            ),
            buildTextField(
              "Clinic Address",
              clinicLoc,
              icon: Icons.location_on_outlined,
            ),
            buildTextField("About Yourself", docInfo, icon: Icons.info_outline),
          ],
        ),
      ),
    );
  }

  Widget buildTextField(
    String label,
    TextEditingController controller, {
    IconData? icon,
    bool readOnlyOverride = false, // To force read-only (like for email)
    TextInputType? keyboardType,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: TextFormField(
        controller: controller,
        readOnly: readOnlyOverride || !_isEditing,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          prefixIcon:
              icon != null ? Icon(icon, color: const Color(0xFFB97001)) : null,
          labelText: label,
          filled: true,
          fillColor:
              _isEditing && !readOnlyOverride
                  ? Colors.white
                  : Colors.grey.shade100,
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
