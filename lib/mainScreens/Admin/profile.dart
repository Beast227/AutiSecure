import 'dart:convert';
import 'package:autisecure/login_signup/login_screen.dart'; // Ensure correct path
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class AdminProfileScreen extends StatefulWidget {
  const AdminProfileScreen({super.key});

  @override
  State<AdminProfileScreen> createState() => _AdminProfileScreenState();
}

class _AdminProfileScreenState extends State<AdminProfileScreen> {
  bool isLoading = true;
  bool _isEditing = false;

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();

  Map<String, dynamic> _originalDataSnapshot = {};

  // Define cache key constant
  static const String _adminCacheKey = 'adminDataCache';

  @override
  void initState() {
    super.initState();
    _loadAdminDataFromCacheAndFetch();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }

  // --- Caching and Data Fetching Logic (Standardized Cache) ---

  Future<void> _loadAdminDataFromCacheAndFetch() async {
    final prefs = await SharedPreferences.getInstance();
    final cachedDataString = prefs.getString(_adminCacheKey);

    // 1. Load from cache first (expecting flat admin object)
    if (cachedDataString != null) {
      try {
        final Map<String, dynamic> cachedAdminData = json.decode(cachedDataString);
        // Directly populate controllers with the flat admin object
        _populateAdminControllers(cachedAdminData);
        if (mounted) {
          setState(() => isLoading = false);
        }
      } catch (e) {
        debugPrint("Error decoding admin cache: $e");
        await prefs.remove(_adminCacheKey);
      }
    }

    // 2. Then, fetch from network
    await _fetchAndCacheAdminProfile(cachedDataString);
  }

  Future<void> _fetchAndCacheAdminProfile(String? cachedDataString) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    if (token == null || token.isEmpty) {
      _showSnackBar("Token not found. Please log in again.", isError: true);
      _logOut();
      return;
    }

    // *** USE CORRECT FETCH ENDPOINT ***
    final url =
        Uri.parse("https://autisense-backend.onrender.com/api/admin/data");

    try {
      final response = await http.get(
        url,
        headers: {'authorization': 'Bearer $token'},
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final responseBody = json.decode(response.body);
        // *** Extract the inner admin object from the response ***
        final Map<String, dynamic>? adminDataFromServer = responseBody['admin'] is Map<String, dynamic>
            ? responseBody['admin'] as Map<String, dynamic>
            : null;

        if (adminDataFromServer != null) {
          final String serverAdminDataString = json.encode(adminDataFromServer);

          // Compare the *inner admin object string* with the cached string
          if (serverAdminDataString != cachedDataString) {
            debugPrint("Admin profile data mismatch. Updating cache and UI.");
            // *** Store only the inner admin object string in cache ***
            await prefs.setString(_adminCacheKey, serverAdminDataString);
            _populateAdminControllers(adminDataFromServer);
            if (cachedDataString != null) {
              _showSnackBar("Profile data updated from server.");
            }
          } else {
            debugPrint("Admin profile data is up-to-date.");
          }
        } else {
           debugPrint("Admin object not found or incorrect format in server response.");
           if (cachedDataString == null) { // Show error only if no cache exists
              _showSnackBar("Could not parse admin data from server.", isError: true);
           }
        }
      } else {
        if (cachedDataString == null) {
          _showSnackBar("Admin Data Not Available: ${response.body}", isError: true);
        }
      }
    } catch (e) {
      if (!mounted) return;
      if (cachedDataString == null) {
        _showSnackBar("Error fetching admin data: $e", isError: true);
      }
    }

    // Ensure loading spinner is off
    if (isLoading && mounted) {
      setState(() => isLoading = false);
    }
  }

  // --- Populate Function (Expects Flat Object) ---
  void _populateAdminControllers(Map<String, dynamic> adminData) {
     // Directly uses the flat admin object
    setState(() {
      _nameController.text = adminData['name'] ?? '';
      _emailController.text = adminData['email'] ?? '';
    });
  }

  // --- Profile Actions ---

  Future<void> _logOut() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
    await prefs.remove('role');
    await prefs.remove(_adminCacheKey); // Use constant key
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
      (route) => false,
    );
  }

  // Snapshot remains flat (correct)
  void _takeAdminDataSnapshot() {
    _originalDataSnapshot = {
      "name": _nameController.text.trim(),
    };
  }

  Future<void> _submitAdminUpdate() async {
    final currentName = _nameController.text.trim();
    final originalName = _originalDataSnapshot['name'];

    if (currentName == originalName) {
      _showSnackBar("No changes detected.");
      setState(() => _isEditing = false);
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    if (token == null) return;

    // *** USE CORRECT UPDATE ENDPOINT ***
    final url =
        Uri.parse("https://autisense-backend.onrender.com/api/admin/update");
    final apiPayload = {"name": currentName};

    try {
      final response = await http.put(
        url,
        headers: {
          'authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode(apiPayload),
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        _showSnackBar("Profile saved successfully!");

        // *** Update Cache with Flat Object ***
        // Create the new flat admin object for caching
        final Map<String, dynamic> updatedAdminDataForCache = {
           'name': currentName,
           // Preserve email from controller (it wasn't sent to API)
           'email': _emailController.text.trim(),
           // Preserve any other non-editable fields if they were loaded initially
        };

        // Save the flat object string
        await prefs.setString(_adminCacheKey, json.encode(updatedAdminDataForCache));

        // Populate controllers (though they already have the right text)
        _populateAdminControllers(updatedAdminDataForCache);

        // Exit edit mode
        setState(() => _isEditing = false);
      } else {
        _showSnackBar("Failed to save: ${response.body}", isError: true);
      }
    } catch (e) {
      _showSnackBar("Error saving: $e", isError: true);
    }
  }

  // --- Build Method (Unchanged) ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 245, 245, 245), // Lighter bg
      appBar: AppBar(
        automaticallyImplyLeading: false, // Remove back button if not needed
        title: Stack(
          alignment: Alignment.center,
          children: [
            const Center(
              child: Text(
                "Admin Profile", // Updated title
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.orange, // Keep theme color
                  fontFamily: "Merriweather",
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
                    _submitAdminUpdate(); // Call save
                  } else {
                    _takeAdminDataSnapshot(); // Take snapshot before editing
                    if (mounted) {
                      setState(() => _isEditing = true); // Enter edit mode
                    }
                  }
                },
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFFFFF2E0), // Keep theme color
        elevation: 1,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.orange))
          : SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _buildAdminDetailsForm(),
                    const SizedBox(height: 30),
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
                        backgroundColor: Colors.redAccent,
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

  // --- UI Helper Widgets (Unchanged) ---
  Widget _buildAdminDetailsForm() {
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
              "Account Details",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFFB97001),
              ),
            ),
            const Divider(height: 20),
            buildTextField(
              "Name",
              _nameController,
              icon: Icons.person_outline,
            ),
            const SizedBox(height: 10),
            buildTextField(
              "Email",
              _emailController,
              icon: Icons.email_outlined,
              readOnlyOverride: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget buildTextField(
    String label,
    TextEditingController controller, {
    IconData? icon,
    bool readOnlyOverride = false,
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
          fillColor: _isEditing && !readOnlyOverride
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
           enabledBorder: OutlineInputBorder(
             borderRadius: BorderRadius.circular(12),
             borderSide: BorderSide(
               color: _isEditing && !readOnlyOverride ? Colors.grey.shade400 : Colors.grey.shade300,
               width: 1,
            ),
          ),
        ),
      ),
    );
  }
}