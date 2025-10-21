// ignore: file_names
import 'dart:convert';
import 'dart:io';

import 'package:autisecure/login_signup/login_screen.dart';
import 'package:autisecure/mainScreens/home_page.dart';
import 'package:flutter/material.dart';
// 1. ADD THIS IMPORT
import 'package:flutter/services.dart'; 
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  String dropDownValue = "User";
  File? doctorImage;
  var users = ["User", "Doctor"];

  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController nameController = TextEditingController();
  final TextEditingController confirmPasswordController =
      TextEditingController();
  final TextEditingController phController = TextEditingController();
  final TextEditingController addressController = TextEditingController();
  final TextEditingController dobController = TextEditingController();

  // For the Doctor
  final TextEditingController docInfo = TextEditingController();
  final TextEditingController clinicLoc = TextEditingController();
  final TextEditingController experience = TextEditingController();
  final TextEditingController specialization = TextEditingController();

  @override
  void initState() {
    super.initState();
    _checkIfLoggedIn();
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    nameController.dispose();
    confirmPasswordController.dispose();
    phController.dispose();
    addressController.dispose();
    dobController.dispose();
    docInfo.dispose();
    clinicLoc.dispose();
    experience.dispose();
    specialization.dispose();
    super.dispose();
  }

  Future<void> _checkIfLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    if (!mounted) return;

    if (token != null && token.isNotEmpty) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    }
  }

  Future<void> submitRegistration(context) async {
    if (passwordController.text.trim() !=
        confirmPasswordController.text.trim()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Passwords do not match!")),
      );
      return; 
    }

    String? imageUrl;

    if (doctorImage != null) {
      imageUrl = await uploadDoctorimage(doctorImage!);
    }
    
    final url = Uri.parse(
      dropDownValue == "Doctor"
          ? 'https://autisense-backend.onrender.com/api/doctor/register'
          : 'https://autisense-backend.onrender.com/api/user/register',
    );

    final Map<String, dynamic> data = {
      "name": nameController.text.trim(),
      "email": emailController.text.trim(),
      "phone": phController.text.trim(),
      "address": addressController.text.trim(),
      "dob": dobController.text.trim(),
      "password": passwordController.text.trim(),
      "imageUrl": imageUrl, 
    };
    if (dropDownValue == "Doctor") {
      data.addAll({
        "speciality": specialization.text.trim(),
        // 3. SEND THE EXPERIENCE AS A NUMBER (int)
        "experience": int.tryParse(experience.text.trim()) ?? 0, 
        "description": docInfo.text.trim(),
        "clinicAddress": clinicLoc.text.trim(),
      });
    }

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: json.encode(data),
    );

    if (!mounted) return;

    if (response.statusCode == 200) {
      nameController.clear();
      emailController.clear();
      phController.clear();
      addressController.clear();
      dobController.clear();
      passwordController.clear();
      confirmPasswordController.clear();
      specialization.clear();
      experience.clear();
      docInfo.clear();
      clinicLoc.clear();

      debugPrint("the message is ${response.body}");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Registration successful: ${response.body}")),
      );
      
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Couldn't Register: ${response.body}")),
      );
    }
  }


  Future<void> pickDoctorImage() async {
    final pickedFile = await ImagePicker().pickImage(
      source: ImageSource.gallery,
    );

    if (pickedFile != null) {
      setState(() {
        doctorImage = File(pickedFile.path);
      });
    }
  }

  Future<String?> uploadDoctorimage(File imageFile) async {
    final cloudName = dotenv.env['CLOUDINARY_CLOUD_NAME'];
    final uploadPreset = dotenv.env['CLOUDINARY_UPLOAD_PRESET'];

    if (cloudName == null || uploadPreset == null) {
      debugPrint("Cloudinary credentials not found in .env file");
      return null;
    }

    final url = Uri.parse(
      "https://api.cloudinary.com/v1_1/$cloudName/image/upload",
    );

    final request = http.MultipartRequest("POST", url)
      ..fields["upload_preset"] = uploadPreset
      ..files.add(
        await http.MultipartFile.fromPath("file", imageFile.path),
      );

    final response = await request.send();

    if (response.statusCode == 200) {
      final res = await http.Response.fromStream(response);
      final data = jsonDecode(res.body);
      debugPrint("Upload Success");
      return data["secure_url"];
    } else {
      debugPrint("Upload failed : ${response.statusCode}");
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    // 2. UPDATE buildTextField TO ACCEPT MORE OPTIONS
    Widget buildTextField(
      String label,
      TextEditingController controller,
      bool obscureText, {
      TextInputType keyboardType = TextInputType.text, // Add this
      List<TextInputFormatter>? inputFormatters, // Add this
    }) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: TextFormField(
          controller: controller,
          obscureText: obscureText,
          keyboardType: keyboardType, // Use the new parameter
          inputFormatters: inputFormatters, // Use the new parameter
          decoration: InputDecoration(
            labelText: label,
            fillColor: Colors.white,
            filled: true,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Colors.blue, width: 3),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Colors.purple, width: 2),
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 255, 245, 227),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 20),
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Image.asset("assets/logo.png", width: 120),
              ),
              const Text(
                "AutiSecure",
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  fontFamily: "Merriweather",
                ),
              ),
              const SizedBox(height: 20),
              Container(
                decoration: const BoxDecoration(color: Colors.white),
                padding:
                    const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      dropDownValue == "User"
                          ? "User Registration"
                          : "Doctor Registration",
                      style: const TextStyle(
                        fontFamily: "merriweather",
                        fontSize: 36,
                        color: Color(0xFF813400),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Column(
                        children: [
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              // Background color
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: Colors.purple,
                                width: 1,
                              ),
                            ),
                            child: DropdownButtonHideUnderline(
                              // Hide default underline
                              child: DropdownButton<String>(
                                value: dropDownValue,
                                isExpanded: true, // Makes it take full width
                                icon: Icon(
                                  Icons.arrow_drop_down,
                                  color: Colors.grey[600],
                                ),
                                items: users.map((String i) {
                                  return DropdownMenuItem(
                                    value: i,
                                    child: Text(
                                      i,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  );
                                }).toList(),
                                onChanged: (String? newValue) {
                                  setState(() {
                                    dropDownValue = newValue!;
                                  });
                                },
                                borderRadius: BorderRadius.circular(
                                  8,
                                ), // Dropdown menu background
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          buildTextField("Name", nameController, false),
                          const SizedBox(height: 10),
                          buildTextField("Email", emailController, false),
                          const SizedBox(height: 10),
                          buildTextField("Phone Number", phController, false),
                          const SizedBox(height: 10),
                          buildTextField("Address", addressController, false),
                          const SizedBox(height: 20),
                          TextFormField(
                            controller: dobController,
                            readOnly: true,
                            onTap: () async {
                              DateTime? pickedDate = await showDatePicker(
                                context: context,
                                initialDate: DateTime.now(),
                                firstDate: DateTime(1900),
                                lastDate: DateTime.now(),
                              );
                              if (pickedDate != null) {
                                dobController.text =
                                    "${pickedDate.day.toString().padLeft(2, '0')}-${pickedDate.month.toString().padLeft(2, '0')}-${pickedDate.year}";
                              }
                            },
                            decoration: InputDecoration(
                              labelText: "DOB",
                              fillColor: Colors.white,
                              filled: true,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          buildTextField("Password", passwordController, true),
                          const SizedBox(height: 10),
                          buildTextField(
                            "Confirm Password",
                            confirmPasswordController,
                            true,
                          ),
                        ],
                      ),
                    ),
                    if (dropDownValue == "Doctor") ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: Column(
                          children: [
                            const SizedBox(height: 10),
                            buildTextField(
                              "Specialization",
                              specialization,
                              false,
                            ),
                            const SizedBox(height: 10),
                            // 3. USE THE NEW PARAMETERS FOR THE "Experience" FIELD
                            buildTextField(
                              "Experience (in years)",
                              experience,
                              false,
                              keyboardType: TextInputType.number,
                              inputFormatters: <TextInputFormatter>[
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                            ),
                            const SizedBox(height: 10),
                            buildTextField("About Yourself", docInfo, false),
                            const SizedBox(height: 10),
                            buildTextField("Clinic Address", clinicLoc, false),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 20),
                      doctorImage != null
                          ? Image.file(doctorImage!, height: 120)
                          : const Text("No image selected (Optional)"),
                      TextButton(
                        onPressed: pickDoctorImage,
                        child: const Text("Pick Profile Image"),
                      ),
                    ],
                    
                    if (dropDownValue == "User") ...[
                       const SizedBox(height: 20),
                       doctorImage != null
                          ? Image.file(doctorImage!, height: 120)
                          : const Text("No image selected (Optional)"),
                       TextButton(
                        onPressed: pickDoctorImage,
                        child: const Text("Pick Profile Image"),
                      ),
                    ],

                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: () => {submitRegistration(context)},
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(25),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 30,
                          vertical: 12,
                        ),
                      ),
                      child: const Text(
                        "Register",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    Column(
                      children: [
                        const SizedBox(height: 15),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text("Have an Account Already? "),
                            TextButton(
                              onPressed: () {
                                Navigator.pushReplacement(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => const LoginScreen(),
                                  ),
                                );
                              },
                              child: const Text(
                                "Log-In",
                                style: TextStyle(color: Colors.blue),
                              ),
                            ),
                          ],
                        ),
                      ],
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
}