import 'dart:convert';

import 'package:autisecure/login_signup/login_screen.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  Future<void> logOutBtn(context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
      (route) => false,
    );
  }

  List<dynamic> doctors = [];
  bool isLoading = true;

  Future<void> fetchDoctors(context) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    try {
      final url = Uri.parse(
        "https://autisense-backend.onrender.com/api/admin/doctor-requests",
      );
      debugPrint("Ran the fetch users");
      final response = await http.get(
        url,
        headers: {"authorization": "Bearer $token"},
      );
      debugPrint("the response is ${response.body}");
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        setState(() {
          doctors = decoded["requests"];
          isLoading = false;
        });
        debugPrint("The doctor requests are : $doctors");
      } else {
        throw Exception("Failed to load doctors");
      }
    } catch (e) {
      setState(() => isLoading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error fetching doctors: $e")));
    }
  }

  Future<void> updateDoctorStatus(
    String doctorId,
    bool approve,
    context,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
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

      debugPrint("hola $doctorId");

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Doctor ${approve ? "approved" : "rejected"}"),
          ),
        );
        fetchDoctors(context); // refresh list
      } else {
        throw Exception("Failed: ${response.body}");
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error: $e")));
      debugPrint("the error is $e");
    }
  }

  @override
  void initState() {
    super.initState();
    fetchDoctors(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.orange[100],
      body:
          isLoading
              ? const Center(child: CircularProgressIndicator())
              : doctors.isEmpty
              ? const Center(child: Text("No Doctors found"))
              : ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: doctors.length,
                itemBuilder: (context, index) {
                  final doctor = doctors[index];
                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    child: ListTile(
                      leading:
                          doctor['imageUrl'] != null &&
                                  doctor['imageUrl'].toString().isNotEmpty
                              ? CircleAvatar(
                                radius: 24,
                                backgroundImage: NetworkImage(
                                  doctor['imageUrl'],
                                ),
                              )
                              : const CircleAvatar(
                                backgroundColor: Colors.orange,
                                child: Icon(Icons.person, color: Colors.white),
                              ),
                      title: Text(doctor['name'] ?? "Unknown"),
                      subtitle: Text(
                        "Speciality: ${doctor['speciality'] ?? "N/A"}",
                      ),
                      trailing: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.check, color: Colors.green),
                            onPressed:
                                () => updateDoctorStatus(
                                  doctor["_id"].toString(),
                                  true,
                                  context,
                                ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, color: Colors.red),
                            onPressed:
                                () => updateDoctorStatus(
                                  doctor["_id"].toString(),
                                  false,
                                  context,
                                ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
    );
  }
}
