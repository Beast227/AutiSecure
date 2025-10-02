// ignore: file_names
import 'dart:convert';
import 'package:autisecure/landing_screens/admin_landing_screen.dart';
import 'package:autisecure/landing_screens/landing_screen.dart';
import 'package:autisecure/login_signup/signup_screen.dart';
import 'package:autisecure/mainScreens/home_page.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  String dropDownValue = "User";
  var users = ["User", "Doctor", "Admin"];
  @override
  void initState() {
    super.initState();
    _checkIfLoggedIn(context);
  }

  Future<void> _checkIfLoggedIn(context) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    final role = prefs.getString('role');

    if (token != null && token.isNotEmpty) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder:
              (_) =>
                  role == "Doctor" || role == "User"
                      ? HomeScreen()
                      : role == "Admin"
                      ? AdminLandingScreen()
                      : LoginScreen(),
        ),
      );
    }
  }

  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  Future<void> submitLogin(context) async {
    final url = Uri.parse(
      dropDownValue == "Doctor"
          ? "https://autisense-backend.onrender.com/api/doctor/login"
          : dropDownValue == "Admin"
          ? "https://autisense-backend.onrender.com/api/admin/login"
          : "https://autisense-backend.onrender.com/api/user/login",
    );

    final Map<String, dynamic> data = {
      "email": _emailController.text.trim(),
      "password": _passwordController.text.trim(),
    };

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: json.encode(data),
    );

    if (response.statusCode == 200) {
      final responseData = json.decode(response.body);
      final message = responseData['message'];

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('token', responseData['token']);
      await prefs.setString('role', dropDownValue);

      _emailController.clear();
      _passwordController.clear();

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
      Navigator.push(
        context,
        MaterialPageRoute(
          builder:
              (context) =>
                  dropDownValue == "Admin"
                      ? AdminLandingScreen()
                      : Landingscreen(),
        ),
      );
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Login Failed: ${response.body}")));
    }
  }

  Widget _buildTextField(
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF5E3),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Padding(padding: EdgeInsets.symmetric(vertical: 20)),
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Image.asset("assets/logo.png", width: 120),
              ),
              Text(
                "AutiSecure",
                style: TextStyle(
                  color: Color.fromARGB(255, 0, 0, 0),
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  fontFamily: "Merriweather",
                ),
              ),
              SizedBox(height: 20),
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFFFF),
                  borderRadius: BorderRadius.circular(20),
                ),
                padding: EdgeInsets.all(20),
                child: Column(
                  children: [
                    Text(
                      "LogIn",
                      style: TextStyle(
                        fontFamily: "merriweather",
                        fontSize: 40,
                        color: Color(0xFF813400),
                      ),
                    ),
                    SizedBox(height: 20),
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        // Background color
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.purple, width: 1),
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
                    _buildTextField("Email", _emailController, false),
                    SizedBox(height: 10),
                    _buildTextField("Password", _passwordController, true),
                    SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: () => submitLogin(context),
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
                        "LogIn",
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
                            Text("Don't have an Account?"),
                            TextButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => SignUpScreen(),
                                  ),
                                );
                              },
                              child: Text(
                                "Register here",
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
