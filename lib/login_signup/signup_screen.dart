import 'dart:convert';

import 'package:autisecure/login_signup/login_screen.dart';
import 'package:autisecure/mainScreens/home_page.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  String dropDownValue = "User";
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
    final url = Uri.parse(
      'https://autisense-backend.onrender.com/api/user/register',
    );

    final Map<String, dynamic> data = {
      "name": nameController.text.trim(),
      "email": emailController.text.trim(),
      "phone": phController.text.trim(),
      "address": addressController.text.trim(),
      "dob": dobController.text.trim(),
      "password": passwordController.text.trim(),
    };

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

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("successfuly logged in ${response.body}")),
      );
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => LoginScreen()),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Couldnt log in ${response.body}")),
      );
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
                      "User Registration",
                      style: TextStyle(
                        fontFamily: "merriweather",
                        fontSize: 40,
                        color: Color(0xFF813400),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Column(
                        children: [
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
                                    "${pickedDate.toLocal()}".split(' ')[0];
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
                          SizedBox(height: 20),
                          // 👇 Replace your current Dropdown part with this:
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
                        ],
                      ),
                    ),
                    if (dropDownValue == "Doctor") ...[
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 10),
                        child: Column(
                          children: [
                            SizedBox(height: 20),
                            buildTextField(
                              "Specialization",
                              specialization,
                              true,
                            ),
                            SizedBox(height: 10),
                            buildTextField("Experience", experience, true),
                            SizedBox(height: 10),
                            buildTextField("About Yourself", docInfo, true),
                            SizedBox(height: 10),
                            buildTextField("Clinic Address", clinicLoc, true),
                            SizedBox(height: 10),
                          ],
                        ),
                      ),
                    ],
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
