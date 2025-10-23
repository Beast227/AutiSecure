import 'dart:convert';
import 'dart:io';

import 'package:autisecure/login_signup/login_screen.dart';
import 'package:autisecure/mainScreens/user/home_page.dart';
import 'package:flutter/material.dart';
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

  Future<void> _checkIfLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    if (token != null && token.isNotEmpty) {
      Navigator.pushReplacement(
        // ignore: use_build_context_synchronously
        context,
        MaterialPageRoute(builder: (_) => HomeScreen()),
      );
    }
  }

  Future<void> submitRegistration(context) async {
    String? imageUrl;
    if (dropDownValue == "Doctor" && doctorImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Upload the Doctor image properly")),
      );
      return;
    }
    imageUrl = await uploadDoctorimage(doctorImage!);

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
        "experience": experience.text.trim(),
        "description": docInfo.text.trim(),
        "clinicAddress": clinicLoc.text.trim(),
      });
    }

    // debugPrint(data as String?);

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: json.encode(data),
    );
    if (response.statusCode == 200) {
      emailController.dispose();
      passwordController.clear();
      confirmPasswordController.clear();
      nameController.clear();
      phController.clear();
      addressController.clear();
      dobController.clear();
      
      debugPrint("the message is ${response.body}");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("successfuly logged in ${response.body}")),
      );
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => LoginScreen()),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Couldnt Register in ${response.body}")),
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

    final url = Uri.parse(
      "https://api.cloudinary.com/v1_1/$cloudName/image/upload",
    );

    final request =
        http.MultipartRequest("POST", url)
          ..fields["upload_preset"] = uploadPreset!
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
    Widget buildTextField(
      String label,
      TextEditingController controller,
      bool obscureText,
    ) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: TextFormField(
          controller: controller,
          obscureText: obscureText,
          decoration: InputDecoration(
            labelText: label,
            fillColor: Colors.white,
            filled: true,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.blue, width: 3),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Colors.purple, width: 2),
            ),
            contentPadding: EdgeInsets.symmetric(horizontal: 15, vertical: 15),
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
              SizedBox(height: 20),
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Image.asset("assets/logo.png", width: 120),
              ),

              Text(
                "AutiSecure",
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  fontFamily: "Merriweather",
                ),
              ),
              SizedBox(height: 20),
              Container(
                decoration: BoxDecoration(color: Colors.white),
                padding: EdgeInsets.symmetric(vertical: 20, horizontal: 12),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      dropDownValue == "User"
                          ? "User Registration"
                          : "Doctor Registration",
                      style: TextStyle(
                        fontFamily: "merriweather",
                        fontSize: 36,
                        color: Color(0xFF813400),
                      ),
                    ),
                    SizedBox(height: 20),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Column(
                        children: [
                          Container(
                            width: double.infinity,
                            padding: EdgeInsets.symmetric(
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
                                items:
                                    users.map((String i) {
                                      return DropdownMenuItem(
                                        value: i,
                                        child: Text(
                                          i,
                                          style: TextStyle(
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

                          SizedBox(height: 20),
                          buildTextField("Name", nameController, false),
                          SizedBox(height: 10),
                          buildTextField("Email", emailController, false),
                          SizedBox(height: 10),
                          buildTextField("Phone Number", phController, false),
                          SizedBox(height: 10),
                          buildTextField("Address", addressController, false),
                          SizedBox(height: 20),
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
                          SizedBox(height: 20),
                          buildTextField("Password", passwordController, true),
                          SizedBox(height: 10),
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
                        padding: EdgeInsets.symmetric(horizontal: 10),
                        child: Column(
                          children: [
                            SizedBox(height: 10),
                            buildTextField(
                              "Specialization",
                              specialization,
                              false,
                            ),
                            SizedBox(height: 10),
                            buildTextField("Experience", experience, false),
                            SizedBox(height: 10),
                            buildTextField("About Yourself", docInfo, false),
                            SizedBox(height: 10),
                            buildTextField("Clinic Address", clinicLoc, false),
                          ],
                        ),
                      ),
                    ],
                    SizedBox(height: 20),
                    doctorImage != null
                        ? Image.file(doctorImage!, height: 120)
                        : const Text("No image selected"),
                    TextButton(
                      onPressed: pickDoctorImage,
                      child: const Text("Pick Profile Image"),
                    ),
                    SizedBox(height: 20),
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
                        SizedBox(height: 15),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text("Have an Account Already? "),
                            TextButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => LoginScreen(),
                                  ),
                                );
                              },
                              child: Text(
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
